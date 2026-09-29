package com.edu.api.ticket;

import com.edu.api.employee.entity.Presence;
import com.edu.api.employee.service.EmployeeService;
import com.edu.api.support.FullStackIntegration;
import com.edu.api.support.TicketFixtures.TicketState;
import com.edu.api.ticket.service.TicketMaintenanceService;
import com.edu.api.ticket.service.TicketService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.Collectors;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Duas transações reais sobre o mesmo ticket: uma segura a linha e muda o
 * estado; a outra roda a ação do serviço ao mesmo tempo. A ação não pode
 * desfazer o que a primeira gravou.
 *
 * Sem transação de teste: cada lado faz commit na própria conexão, e os dados
 * criados são apagados ao final de cada teste.
 */
@Transactional(propagation = Propagation.NOT_SUPPORTED)
class ConcurrentTicketUpdatesIT extends FullStackIntegration {

    /** Tempo para a outra transação ler o ticket antes do commit da primeira. */
    private static final long HOLD_MILLIS = 2000;

    @Autowired
    private TicketService tickets;

    @Autowired
    private EmployeeService employees;

    @Autowired
    private TicketMaintenanceService maintenance;

    @Autowired
    private PlatformTransactionManager transactionManager;

    private final List<Long> createdUsers = new ArrayList<>();
    private final ExecutorService otherThread = Executors.newSingleThreadExecutor();

    private long user(String role) {
        long id = fx.user(role);
        createdUsers.add(id);
        return id;
    }

    private long employee(String presence, String skill) {
        long id = fx.employee(presence, skill);
        createdUsers.add(fx.userOf(id));
        return id;
    }

    /**
     * Trava o ticket, aplica {@code change} e só faz commit depois de
     * {@code HOLD_MILLIS}; nesse meio-tempo, {@code action} roda em outra
     * thread e outra transação. Retorna quando as duas terminaram.
     */
    private void whileAnotherTransactionChanges(long ticketId, String change, Object[] args, Runnable action)
            throws Exception {
        Future<?> concurrent = new TransactionTemplate(transactionManager).execute(status -> {
            jdbc.queryForObject("SELECT id FROM tickets WHERE id = ? FOR UPDATE", Long.class, ticketId);
            jdbc.update(change, args);
            Future<?> started = otherThread.submit(action);
            pause();
            return started;
        });
        concurrent.get(30, TimeUnit.SECONDS);
    }

    private static void pause() {
        try {
            Thread.sleep(HOLD_MILLIS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException(e);
        }
    }

    @AfterEach
    void deleteCommittedData() {
        otherThread.shutdownNow();
        if (createdUsers.isEmpty()) {
            return;
        }
        String users = createdUsers.stream().map(String::valueOf).collect(Collectors.joining(","));
        String ticketsOf = "SELECT id FROM tickets WHERE user_id IN (" + users + ")";
        String employeesOf = "SELECT id FROM employees WHERE user_id IN (" + users + ")";
        jdbc.update("DELETE FROM notifications WHERE recipient_user_id IN (" + users + ")"
                + " OR ticket_id IN (" + ticketsOf + ")");
        jdbc.update("DELETE FROM ticket_attachments WHERE ticket_id IN (" + ticketsOf + ")");
        jdbc.update("DELETE FROM ticket_messages WHERE ticket_id IN (" + ticketsOf + ")");
        jdbc.update("DELETE FROM ticket_events WHERE ticket_id IN (" + ticketsOf + ")"
                + " OR employee_id IN (" + employeesOf + ")");
        jdbc.update("DELETE FROM tickets WHERE user_id IN (" + users + ")");
        jdbc.update("DELETE FROM employee_skills WHERE employee_id IN (" + employeesOf + ")");
        jdbc.update("DELETE FROM employees WHERE user_id IN (" + users + ")");
        jdbc.update("DELETE FROM admin_users WHERE id IN (" + users + ")");
    }

    @Test
    void aUserMessageDoesNotUndoAConcurrentResolution() throws Exception {
        long requester = user("USER");
        long agent = employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticketFor(requester, "DEFEITO_APP").status("EM_ATENDIMENTO").assignedTo(agent).insert();

        whileAnotherTransactionChanges(ticket,
                "UPDATE tickets SET status = 'RESOLVIDO', resolved_at = SYSTIMESTAMP WHERE id = ?",
                new Object[] {ticket},
                () -> tickets.postMessage(login(requester, "USER"), ticket, "Obrigado!", null));

        assertThat(fx.state(ticket).status()).isEqualTo("RESOLVIDO");
        assertThat(fx.count("SELECT COUNT(*) FROM ticket_messages WHERE ticket_id = ?", ticket)).isEqualTo(1);
    }

    @Test
    void autoCloseDoesNotUndoAConcurrentReopen() throws Exception {
        long requester = user("USER");
        long agent = employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticketFor(requester, "DEFEITO_APP").status("RESOLVIDO").assignedTo(agent)
                .resolvedAt(OffsetDateTime.now(ZoneOffset.UTC).minusHours(73)).insert();
        AtomicInteger closed = new AtomicInteger(-1);

        whileAnotherTransactionChanges(ticket,
                "UPDATE tickets SET status = 'EM_ATENDIMENTO', resolved_at = NULL WHERE id = ?",
                new Object[] {ticket},
                () -> closed.set(maintenance.closeStaleResolved()));

        assertThat(fx.state(ticket).status()).isEqualTo("EM_ATENDIMENTO");
        assertThat(closed).hasValue(0);
    }

    @Test
    void goingOfflineDoesNotUndoAConcurrentEscalation() throws Exception {
        long requester = user("USER");
        long leaving = employee("ONLINE", "DESENVOLVEDOR");
        long other = employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA").assignedTo(leaving).insert();

        whileAnotherTransactionChanges(ticket,
                "UPDATE tickets SET status = 'ESCALADO', priority = 'CRITICA', assigned_employee_id = ? WHERE id = ?",
                new Object[] {other, ticket},
                () -> employees.changePresence(login(fx.userOf(leaving), "EMPLOYEE"), Presence.OFFLINE));

        assertThat(fx.state(ticket)).isEqualTo(new TicketState("ESCALADO", "CRITICA", other));
    }
}
