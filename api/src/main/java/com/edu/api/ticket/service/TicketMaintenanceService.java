package com.edu.api.ticket.service;

import com.edu.api.shared.exception.ConflictException;
import com.edu.api.shared.exception.NotFoundException;
import com.edu.api.ticket.entity.Ticket;
import com.edu.api.ticket.entity.TicketEventType;
import com.edu.api.ticket.entity.TicketStatus;
import com.edu.api.ticket.event.TicketActivity;
import com.edu.api.ticket.plsql.TicketProcedures;
import com.edu.api.ticket.repository.TicketRepository;
import jakarta.persistence.EntityManager;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;

/** Rotinas do job de SLA; cada método roda na própria transação. */
@Service
public class TicketMaintenanceService {

    static final Duration CONFIRMATION_WINDOW = Duration.ofHours(72);

    private final TicketRepository tickets;
    private final TicketProcedures procedures;
    private final TicketActivityRecorder activity;
    private final EntityManager entityManager;
    private final Clock clock;

    public TicketMaintenanceService(TicketRepository tickets, TicketProcedures procedures,
                                    TicketActivityRecorder activity, EntityManager entityManager, Clock clock) {
        this.tickets = tickets;
        this.procedures = procedures;
        this.activity = activity;
        this.entityManager = entityManager;
        this.clock = clock;
    }

    @Transactional
    public int escalateOverdue() {
        entityManager.flush();
        return procedures.escalateOverdue(clock.instant());
    }

    @Transactional
    public int routeUnassigned() {
        entityManager.flush();
        int assigned = 0;
        for (Long ticketId : tickets.findRoutableUnassignedIds()) {
            try {
                if (procedures.route(ticketId).isPresent()) {
                    assigned++;
                }
            } catch (ConflictException | NotFoundException ignored) {
                // O ticket mudou desde a consulta; a próxima rodada reavalia.
            }
        }
        return assigned;
    }

    @Transactional
    public int closeStaleResolved() {
        Instant now = clock.instant();
        List<Ticket> stale = tickets.findByStatusResolvedBefore(TicketStatus.RESOLVIDO,
                now.minus(CONFIRMATION_WINDOW));
        for (Ticket ticket : stale) {
            TicketStatus from = ticket.getStatus();
            ticket.autoClose(now);
            activity.record(ticket, TicketEventType.FECHADO, from, null,
                    "Fechado automaticamente após 72 h sem confirmação");
            activity.publish(ticket, TicketActivity.Kind.CLOSED);
        }
        return stale.size();
    }
}
