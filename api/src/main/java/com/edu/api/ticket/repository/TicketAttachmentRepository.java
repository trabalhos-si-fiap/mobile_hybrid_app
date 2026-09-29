package com.edu.api.ticket.repository;

import com.edu.api.ticket.entity.TicketAttachment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface TicketAttachmentRepository extends JpaRepository<TicketAttachment, Long> {

    @Query("select a from TicketAttachment a where a.ticket.id = :ticketId and a.message is null order by a.id")
    List<TicketAttachment> findOpeningAttachments(@Param("ticketId") Long ticketId);

    @Query("select a from TicketAttachment a where a.message.id in :messageIds order by a.id")
    List<TicketAttachment> findByMessageIds(@Param("messageIds") Collection<Long> messageIds);

    @Query("select a from TicketAttachment a where a.id = :id and a.ticket.id = :ticketId")
    Optional<TicketAttachment> findInTicket(@Param("id") Long id, @Param("ticketId") Long ticketId);
}
