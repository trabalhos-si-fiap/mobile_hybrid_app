package com.edu.api.ticket.repository;

import com.edu.api.ticket.entity.TicketMessage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface TicketMessageRepository extends JpaRepository<TicketMessage, Long> {

    @Query("select m from TicketMessage m left join fetch m.senderUser where m.ticket.id = :ticketId"
            + " order by m.createdAt, m.id")
    List<TicketMessage> findByTicket(@Param("ticketId") Long ticketId);
}
