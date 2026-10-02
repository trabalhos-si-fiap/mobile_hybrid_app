package com.edu.api.chatbot;

import com.edu.api.chatbot.dto.ChatbotReplyRequest;
import com.edu.api.chatbot.service.ChatbotService;
import com.edu.api.shared.exception.ConflictException;
import com.edu.api.support.ChatbotFixtures;
import com.edu.api.support.FullStackIntegration;
import com.edu.api.ticket.entity.Segment;
import com.edu.api.ticket.service.TicketService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Duas transações reais sobre a mesma conversa: uma segura a linha e muda o
 * estado; a outra roda o turno ou a abertura do ticket ao mesmo tempo, e tem
 * de esperar e enxergar o que a primeira gravou.
 *
 * Sem transação de teste: cada lado faz commit na própria conexão, e os dados
 * criados são apagados ao final de cada teste.
 */
@Transactional(propagation = Propagation.NOT_SUPPORTED)
class ConcurrentChatbotUpdatesIT extends FullStackIntegration {

    /** Tempo para a outra transação ler a conversa antes do commit da primeira. */
    private static final long HOLD_MILLIS = 2000;

    @Autowired
    private ChatbotService chatbot;

    @Autowired
    private TicketService tickets;

    @Autowired
    private PlatformTransactionManager transactionManager;

    private final List<Long> createdUsers = new ArrayList<>();
    private final ExecutorService otherThread = Executors.newSingleThreadExecutor();
    private ChatbotFixtures bot;

    @BeforeEach
    void createBotFixtures() {
        bot = new ChatbotFixtures(jdbc);
    }

    private long user() {
        long id = fx.user("USER");
        createdUsers.add(id);
        return id;
    }

    /**
     * Trava a conversa, aplica {@code change} e só faz commit depois de
     * {@code HOLD_MILLIS}; nesse meio-tempo, {@code action} roda em outra
     * thread e outra transação. Devolve o erro da action, ou nulo.
     */
    private Throwable whileAnotherTransactionChanges(long conversationId, String change, Object[] args,
                                                     Runnable action) throws Exception {
        Future<?> concurrent = new TransactionTemplate(transactionManager).execute(status -> {
            jdbc.queryForObject("SELECT id FROM chatbot_conversations WHERE id = ? FOR UPDATE", Long.class,
                    conversationId);
            jdbc.update(change, args);
            Future<?> started = otherThread.submit(action);
            pause();
            return started;
        });
        try {
            concurrent.get(30, TimeUnit.SECONDS);
            return null;
        } catch (ExecutionException failure) {
            return failure.getCause();
        }
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
        jdbc.update("DELETE FROM chatbot_messages WHERE conversation_id IN"
                + " (SELECT id FROM chatbot_conversations WHERE user_id IN (" + users + "))");
        jdbc.update("DELETE FROM chatbot_conversations WHERE user_id IN (" + users + ")");
        jdbc.update("DELETE FROM notifications WHERE ticket_id IN (" + ticketsOf + ")");
        jdbc.update("DELETE FROM ticket_events WHERE ticket_id IN (" + ticketsOf + ")");
        jdbc.update("DELETE FROM tickets WHERE user_id IN (" + users + ")");
        jdbc.update("DELETE FROM admin_users WHERE id IN (" + users + ")");
    }

    @Test
    void aTurnWaitsForAConcurrentHandoff() throws Exception {
        long requester = user();
        long conversation = bot.conversation(requester, "INICIO");

        Throwable error = whileAnotherTransactionChanges(conversation,
                "UPDATE chatbot_conversations SET state = 'ENCAMINHAMENTO' WHERE id = ?",
                new Object[] {conversation},
                () -> chatbot.reply(login(requester, "USER"), conversation,
                        new ChatbotReplyRequest(null, "segment:DEFEITO_APP")));

        assertThat(error).isInstanceOf(ConflictException.class);
        assertThat(jdbc.queryForObject("SELECT state FROM chatbot_conversations WHERE id = ?", String.class,
                conversation)).isEqualTo("ENCAMINHAMENTO");
        assertThat(fx.count("SELECT COUNT(*) FROM chatbot_messages WHERE conversation_id = ?", conversation)).isZero();
    }

    @Test
    void openingATicketWaitsForAConcurrentLink() throws Exception {
        long requester = user();
        long conversation = bot.conversation(requester, "ENCAMINHAMENTO");
        long linked = fx.ticket(requester, "PROBLEMA_PEDIDO");

        Throwable error = whileAnotherTransactionChanges(conversation,
                "UPDATE chatbot_conversations SET state = 'ENCAMINHADA', ticket_id = ?, finished_at = SYSTIMESTAMP"
                        + " WHERE id = ?",
                new Object[] {linked, conversation},
                () -> tickets.open(login(requester, "USER"), Segment.PROBLEMA_PEDIDO, "Pedido incompleto", null,
                        conversation));

        assertThat(error).isInstanceOf(ConflictException.class);
        assertThat(jdbc.queryForObject("SELECT ticket_id FROM chatbot_conversations WHERE id = ?", Long.class,
                conversation)).isEqualTo(linked);
        assertThat(fx.count("SELECT COUNT(*) FROM tickets WHERE user_id = ?", requester)).isEqualTo(1);
    }
}
