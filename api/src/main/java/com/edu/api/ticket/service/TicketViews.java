package com.edu.api.ticket.service;

import com.edu.api.ticket.dto.*;
import com.edu.api.ticket.entity.*;
import com.edu.api.ticket.plsql.TicketProcedures;
import com.edu.api.ticket.repository.TicketAttachmentRepository;
import com.edu.api.ticket.repository.TicketTypeConfigRepository;
import jakarta.persistence.EntityManager;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Monta as respostas da API. O status de SLA vem da FN_STATUS_SLA_TICKET, que
 * lê o banco: por isso o flush antes de consultá-lo.
 */
@Component
public class TicketViews {

    private final TicketTypeConfigRepository configs;
    private final TicketAttachmentRepository attachments;
    private final TicketProcedures procedures;
    private final EntityManager entityManager;

    public TicketViews(TicketTypeConfigRepository configs, TicketAttachmentRepository attachments,
                       TicketProcedures procedures, EntityManager entityManager) {
        this.configs = configs;
        this.attachments = attachments;
        this.procedures = procedures;
        this.entityManager = entityManager;
    }

    public static SegmentResponse segment(TicketTypeConfig config) {
        return new SegmentResponse(config.getSegment(), config.getLabel(), config.getQueue(),
                config.getSkill().getName(), config.getSlaMinutes());
    }

    public static AttachmentResponse attachment(TicketAttachment attachment) {
        return new AttachmentResponse(attachment.getId(), attachment.getFileName(), attachment.getContentType(),
                attachment.getSizeBytes(),
                "/tickets/" + attachment.getTicket().getId() + "/attachments/" + attachment.getId());
    }

    public TicketDetailResponse detail(Ticket ticket) {
        entityManager.flush();
        TicketTypeConfig config = configs.findById(ticket.getSegment().name()).orElseThrow();
        String sla = procedures.slaStatuses(List.of(ticket.getId())).get(ticket.getId());
        List<AttachmentResponse> files = attachments.findOpeningAttachments(ticket.getId()).stream()
                .map(TicketViews::attachment)
                .toList();
        return new TicketDetailResponse(ticket.getId(), ticket.getSegment(), config.getLabel(), config.getQueue(),
                ticket.getStatus(), ticket.getPriority(), ticket.getChannel(), ticket.getDescription(), sla,
                ticket.getSlaDueAt(), requester(ticket), assignee(ticket), ticket.isEngineeringAlert(),
                ticket.getEngineeringAlertReason(), files, ticket.getCreatedAt(), ticket.getUpdatedAt(),
                ticket.getAssumedAt(), ticket.getResolvedAt(), ticket.getClosedAt());
    }

    public List<TicketSummaryResponse> summaries(List<Ticket> tickets) {
        if (tickets.isEmpty()) {
            return List.of();
        }
        entityManager.flush();
        Map<Segment, String> labels = configs.findAll().stream()
                .collect(Collectors.toMap(TicketTypeConfig::getSegment, TicketTypeConfig::getLabel));
        Map<Long, String> sla = procedures.slaStatuses(tickets.stream().map(Ticket::getId).toList());
        return tickets.stream()
                .map(t -> new TicketSummaryResponse(t.getId(), t.getSegment(), labels.get(t.getSegment()),
                        t.getStatus(), t.getPriority(), sla.get(t.getId()), t.getSlaDueAt(),
                        t.getRequester().getName(), assigneeName(t), t.isEngineeringAlert(),
                        t.getCreatedAt(), t.getUpdatedAt()))
                .toList();
    }

    public List<MessageResponse> messages(List<TicketMessage> messages) {
        if (messages.isEmpty()) {
            return List.of();
        }
        List<Long> ids = messages.stream().map(TicketMessage::getId).toList();
        Map<Long, List<AttachmentResponse>> files = attachments.findByMessageIds(ids).stream()
                .collect(Collectors.groupingBy(a -> a.getMessage().getId(),
                        Collectors.mapping(TicketViews::attachment, Collectors.toList())));
        return messages.stream()
                .map(m -> message(m, files.getOrDefault(m.getId(), List.of())))
                .toList();
    }

    public MessageResponse message(TicketMessage message, List<AttachmentResponse> files) {
        String sender = message.getSenderUser() == null ? "Sistema" : message.getSenderUser().getName();
        return new MessageResponse(message.getId(), message.getSenderType(), sender, message.getBody(),
                files, message.getCreatedAt());
    }

    public List<TicketEventResponse> events(List<TicketEvent> events) {
        return events.stream()
                .map(e -> new TicketEventResponse(e.getId(), e.getType(), e.getFromStatus(), e.getToStatus(),
                        e.getEmployee() == null ? null : e.getEmployee().getUser().getName(),
                        e.getDetail(), e.getCreatedAt()))
                .toList();
    }

    private static UserSummary requester(Ticket ticket) {
        return new UserSummary(ticket.getRequester().getId(), ticket.getRequester().getName(),
                ticket.getRequester().getEmail());
    }

    private static EmployeeSummary assignee(Ticket ticket) {
        return ticket.getAssignedEmployee() == null ? null
                : new EmployeeSummary(ticket.getAssignedEmployee().getId(), assigneeName(ticket));
    }

    private static String assigneeName(Ticket ticket) {
        return ticket.getAssignedEmployee() == null ? null : ticket.getAssignedEmployee().getUser().getName();
    }
}
