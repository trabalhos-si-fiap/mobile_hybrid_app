package com.edu.api.ticket.repository;

import com.edu.api.ticket.entity.TicketEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface TicketEventRepository extends JpaRepository<TicketEvent, Long> {

    @Query("select ev from TicketEvent ev left join fetch ev.employee e left join fetch e.user"
            + " where ev.ticket.id = :ticketId order by ev.createdAt, ev.id")
    List<TicketEvent> findByTicket(@Param("ticketId") Long ticketId);
}
