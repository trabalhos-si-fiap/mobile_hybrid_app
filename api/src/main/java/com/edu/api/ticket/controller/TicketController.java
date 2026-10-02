package com.edu.api.ticket.controller;

import com.edu.api.chatbot.dto.ChatbotTranscriptResponse;
import com.edu.api.security.AuthenticatedUser;
import com.edu.api.ticket.dto.*;
import com.edu.api.ticket.entity.Segment;
import com.edu.api.ticket.service.TicketService;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.nio.charset.StandardCharsets;
import java.util.List;

@RestController
@RequestMapping("/tickets")
public class TicketController {

    private final TicketService tickets;

    public TicketController(TicketService tickets) {
        this.tickets = tickets;
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<TicketDetailResponse> open(
            @AuthenticationPrincipal AuthenticatedUser user,
            @RequestParam Segment segment,
            @RequestParam String description,
            @RequestParam(name = "files", required = false) List<MultipartFile> files,
            @RequestParam(name = "chatbotConversationId", required = false) Long chatbotConversationId
    ) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(tickets.open(user, segment, description, files, chatbotConversationId));
    }

    @GetMapping("/mine")
    public List<TicketSummaryResponse> mine(@AuthenticationPrincipal AuthenticatedUser user) {
        return tickets.mine(user);
    }

    @GetMapping("/{ticketId}")
    public TicketDetailResponse detail(@AuthenticationPrincipal AuthenticatedUser user,
                                       @PathVariable long ticketId) {
        return tickets.detail(user, ticketId);
    }

    @GetMapping("/{ticketId}/chatbot-conversation")
    public ChatbotTranscriptResponse chatbotConversation(@AuthenticationPrincipal AuthenticatedUser user,
                                                         @PathVariable long ticketId) {
        return tickets.chatbotConversation(user, ticketId);
    }

    @GetMapping("/{ticketId}/messages")
    public List<MessageResponse> messages(@AuthenticationPrincipal AuthenticatedUser user,
                                          @PathVariable long ticketId) {
        return tickets.messages(user, ticketId);
    }

    @PostMapping(value = "/{ticketId}/messages", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<MessageResponse> postMessage(
            @AuthenticationPrincipal AuthenticatedUser user,
            @PathVariable long ticketId,
            @RequestParam String body,
            @RequestParam(name = "files", required = false) List<MultipartFile> files
    ) {
        return ResponseEntity.status(HttpStatus.CREATED).body(tickets.postMessage(user, ticketId, body, files));
    }

    @GetMapping("/{ticketId}/attachments/{attachmentId}")
    public ResponseEntity<InputStreamResource> download(@AuthenticationPrincipal AuthenticatedUser user,
                                                        @PathVariable long ticketId,
                                                        @PathVariable long attachmentId) {
        AttachmentDownload file = tickets.download(user, ticketId, attachmentId);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(file.contentType()))
                .contentLength(file.size())
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        ContentDisposition.inline().filename(file.fileName(), StandardCharsets.UTF_8).build().toString())
                .body(new InputStreamResource(file.content()));
    }

    @PostMapping("/{ticketId}/confirm")
    public TicketDetailResponse confirm(@AuthenticationPrincipal AuthenticatedUser user,
                                        @PathVariable long ticketId) {
        return tickets.confirm(user, ticketId);
    }

    @PostMapping("/{ticketId}/reopen")
    public TicketDetailResponse reopen(@AuthenticationPrincipal AuthenticatedUser user,
                                       @PathVariable long ticketId) {
        return tickets.reopen(user, ticketId);
    }
}
