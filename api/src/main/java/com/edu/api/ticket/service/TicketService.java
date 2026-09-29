package com.edu.api.ticket.service;

import com.edu.api.employee.entity.Employee;
import com.edu.api.security.AuthenticatedUser;
import com.edu.api.ticket.dto.*;
import com.edu.api.ticket.entity.*;
import com.edu.api.ticket.event.TicketActivity;
import com.edu.api.ticket.plsql.TicketProcedures;
import com.edu.api.ticket.repository.TicketMessageRepository;
import com.edu.api.ticket.repository.TicketRepository;
import com.edu.api.ticket.repository.TicketTypeConfigRepository;
import com.edu.api.user.entity.AdminUser;
import com.edu.api.user.repository.AdminUserRepository;
import jakarta.persistence.EntityManager;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.Clock;
import java.time.Instant;
import java.util.List;

/** Lado do usuário do app e leituras compartilhadas com o atendente. */
@Service
public class TicketService {

    private final TicketRepository tickets;
    private final TicketTypeConfigRepository configs;
    private final TicketMessageRepository messages;
    private final AdminUserRepository users;
    private final TicketAttachmentService attachments;
    private final TicketProcedures procedures;
    private final TicketActivityRecorder activity;
    private final TicketViews views;
    private final TicketAccessResolver access;
    private final EntityManager entityManager;
    private final Clock clock;

    public TicketService(TicketRepository tickets, TicketTypeConfigRepository configs,
                         TicketMessageRepository messages, AdminUserRepository users,
                         TicketAttachmentService attachments, TicketProcedures procedures,
                         TicketActivityRecorder activity, TicketViews views, TicketAccessResolver access,
                         EntityManager entityManager, Clock clock) {
        this.tickets = tickets;
        this.configs = configs;
        this.messages = messages;
        this.users = users;
        this.attachments = attachments;
        this.procedures = procedures;
        this.activity = activity;
        this.views = views;
        this.access = access;
        this.entityManager = entityManager;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<SegmentResponse> segments() {
        return configs.findActive().stream().map(TicketViews::segment).toList();
    }

    @Transactional
    public TicketDetailResponse open(AuthenticatedUser user, Segment segment, String description,
                                     List<MultipartFile> files) {
        String text = TicketTexts.require(description, "description");
        List<MultipartFile> valid = attachments.validate(files);
        AdminUser requester = users.getReferenceById(user.id());

        Ticket ticket = tickets.save(Ticket.open(requester, segment, text, TicketChannel.APP, clock.instant()));
        attachments.store(ticket, null, requester, valid);
        activity.record(ticket, TicketEventType.ABERTO, null, null, null);

        entityManager.flush();
        procedures.route(ticket.getId());
        entityManager.refresh(ticket);
        return views.detail(ticket);
    }

    @Transactional(readOnly = true)
    public List<TicketSummaryResponse> mine(AuthenticatedUser user) {
        return views.summaries(tickets.findByRequester(user.id()));
    }

    @Transactional(readOnly = true)
    public TicketDetailResponse detail(AuthenticatedUser user, long ticketId) {
        return views.detail(access.visibleTicket(user, ticketId));
    }

    @Transactional(readOnly = true)
    public List<MessageResponse> messages(AuthenticatedUser user, long ticketId) {
        Ticket ticket = access.visibleTicket(user, ticketId);
        return views.messages(messages.findByTicket(ticket.getId()));
    }

    @Transactional
    public MessageResponse postMessage(AuthenticatedUser user, long ticketId, String body,
                                       List<MultipartFile> files) {
        String text = TicketTexts.require(body, "body");
        List<MultipartFile> valid = attachments.validate(files);
        Ticket ticket = access.visibleTicketForUpdate(user, ticketId);
        AdminUser sender = users.getReferenceById(user.id());
        Instant now = clock.instant();

        TicketMessage message;
        if (ticket.isRequestedBy(user.id())) {
            ticket.requireUserCanPost();
            message = messages.save(new TicketMessage(ticket, SenderType.USER, sender, text, now));
            activity.publish(ticket, TicketActivity.Kind.USER_MESSAGE);
        } else {
            Employee employee = access.requireEmployee(user);
            ticket.requireStaffCanPost(employee, user.isAdmin());
            message = messages.save(new TicketMessage(ticket, SenderType.EMPLOYEE, sender, text, now));
            activity.publish(ticket, TicketActivity.Kind.EMPLOYEE_MESSAGE);
        }
        ticket.touch(now);

        List<AttachmentResponse> stored = attachments.store(ticket, message, sender, valid).stream()
                .map(TicketViews::attachment)
                .toList();
        return views.message(message, stored);
    }

    @Transactional(readOnly = true)
    public AttachmentDownload download(AuthenticatedUser user, long ticketId, long attachmentId) {
        return attachments.download(access.visibleTicket(user, ticketId), attachmentId);
    }

    @Transactional
    public TicketDetailResponse confirm(AuthenticatedUser user, long ticketId) {
        Ticket ticket = access.ownTicketForUpdate(user, ticketId);
        TicketStatus from = ticket.getStatus();

        ticket.confirm(clock.instant());
        activity.record(ticket, TicketEventType.FECHADO, from, null, "Confirmado pelo usuário");
        activity.publish(ticket, TicketActivity.Kind.CLOSED);
        return views.detail(ticket);
    }

    @Transactional
    public TicketDetailResponse reopen(AuthenticatedUser user, long ticketId) {
        Ticket ticket = access.ownTicketForUpdate(user, ticketId);
        TicketStatus from = ticket.getStatus();
        int slaMinutes = configs.findById(ticket.getSegment().name()).orElseThrow().getSlaMinutes();
        Instant now = clock.instant();

        ticket.reopen(slaMinutes, now);
        messages.save(TicketMessage.system(ticket, "Ticket reaberto pelo usuário", now));
        activity.record(ticket, TicketEventType.REABERTO, from, null, null);
        activity.publish(ticket, TicketActivity.Kind.REOPENED);
        return views.detail(ticket);
    }
}
