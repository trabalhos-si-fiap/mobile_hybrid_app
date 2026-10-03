package com.edu.api.ticket.repository;

import com.edu.api.ticket.entity.Segment;
import com.edu.api.ticket.entity.Ticket;
import com.edu.api.ticket.entity.TicketStatus;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface TicketRepository extends JpaRepository<Ticket, Long> {

    String WITH_PEOPLE = "select t from Ticket t join fetch t.requester"
            + " left join fetch t.assignedEmployee e left join fetch e.user ";

    @Query(WITH_PEOPLE + "where t.id = :id")
    Optional<Ticket> findDetailedById(@Param("id") Long id);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select t from Ticket t where t.id = :id")
    Optional<Ticket> findForUpdate(@Param("id") Long id);

    @Query(WITH_PEOPLE + "where t.requester.id = :userId order by t.createdAt desc, t.id desc")
    List<Ticket> findByRequester(@Param("userId") Long userId);

    @Query(WITH_PEOPLE + "where e.id = :employeeId and t.status in :statuses")
    List<Ticket> findAssignedTo(@Param("employeeId") Long employeeId,
                                @Param("statuses") Collection<TicketStatus> statuses);

    @Query(WITH_PEOPLE + "where t.segment in :segments and t.status in :statuses")
    List<Ticket> findBySegmentsAndStatuses(@Param("segments") Collection<Segment> segments,
                                           @Param("statuses") Collection<TicketStatus> statuses);

    @Query(WITH_PEOPLE + "where t.status in :statuses")
    List<Ticket> findByStatuses(@Param("statuses") Collection<TicketStatus> statuses);

    @Query("select t.id from Ticket t where t.assignedEmployee is null and t.status in :statuses"
            + " and t.segment in :segments order by t.createdAt, t.id")
    List<Long> findUnassignedIds(@Param("statuses") Collection<TicketStatus> statuses,
                                 @Param("segments") Collection<Segment> segments);

    /**
     * Tickets EM_FILA/ESCALADO sem dono cujo segmento tem alguém ONLINE com a
     * skill, fora quem abriu o ticket (que não pode recebê-lo). Sem esse
     * alguém, rotear só gravaria mais um evento ROTEADO.
     */
    @Query(value = "SELECT t.id FROM tickets t"
            + " WHERE t.assigned_employee_id IS NULL AND t.status IN ('EM_FILA', 'ESCALADO')"
            + " AND EXISTS (SELECT 1 FROM ticket_tipo_config c"
            + "              JOIN employee_skills es ON es.skill_id = c.skill_id"
            + "              JOIN employees e ON e.id = es.employee_id"
            + "             WHERE c.segment = t.segment AND c.active = TRUE AND e.presence = 'ONLINE'"
            + "               AND e.user_id <> t.user_id)"
            + " ORDER BY t.created_at, t.id", nativeQuery = true)
    List<Long> findRoutableUnassignedIds();

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select t from Ticket t where t.status = :status and t.assignedEmployee.id = :employeeId")
    List<Ticket> findByStatusAndAssignee(@Param("status") TicketStatus status,
                                         @Param("employeeId") Long employeeId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select t from Ticket t where t.status = :status and t.resolvedAt < :before")
    List<Ticket> findByStatusResolvedBefore(@Param("status") TicketStatus status,
                                            @Param("before") Instant before);
}
