package com.edu.api.ticket.service;

import com.edu.api.shared.exception.ConflictException;
import com.edu.api.shared.exception.NotFoundException;
import com.edu.api.shared.exception.ValidationException;
import com.edu.api.storage.AttachmentStorage;
import com.edu.api.support.FullStackIntegration;
import com.edu.api.ticket.dto.MessageResponse;
import com.edu.api.ticket.dto.TicketDetailResponse;
import com.edu.api.ticket.dto.TicketSummaryResponse;
import com.edu.api.ticket.entity.Segment;
import com.edu.api.ticket.entity.SenderType;
import com.edu.api.ticket.entity.TicketPriority;
import com.edu.api.ticket.entity.TicketStatus;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.web.multipart.MultipartFile;

import java.io.InputStream;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TicketServiceIT extends FullStackIntegration {

    private static final byte[] PNG = {(byte) 0x89, 'P', 'N', 'G', 1, 2, 3};

    @Autowired
    private TicketService tickets;

    @Autowired
    private AttachmentStorage storage;

    private static MultipartFile png(String name) {
        return new MockMultipartFile("files", name, "image/png", PNG);
    }

    @Test
    void openingRoutesTheTicketToAnOnlineAgent() throws Exception {
        long requester = fx.user("USER");
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");

        TicketDetailResponse opened = tickets.open(login(requester, "USER"), Segment.DEFEITO_APP,
                "  O app fecha no carrinho  ", List.of(png("print.png")));

        assertThat(opened.status()).isEqualTo(TicketStatus.EM_FILA);
        assertThat(opened.priority()).isEqualTo(TicketPriority.ALTA);
        assertThat(opened.assignee().id()).isEqualTo(agent);
        assertThat(opened.description()).isEqualTo("O app fecha no carrinho");
        assertThat(opened.slaStatus()).isEqualTo("NO_PRAZO");
        assertThat(opened.attachments()).singleElement().satisfies(a -> {
            assertThat(a.fileName()).isEqualTo("print.png");
            assertThat(a.downloadPath()).isEqualTo("/tickets/" + opened.id() + "/attachments/" + a.id());
        });
        String key = jdbc.queryForObject("SELECT object_key FROM ticket_attachments WHERE ticket_id = ?",
                String.class, opened.id());
        try (InputStream stored = storage.get(key)) {
            assertThat(stored.readAllBytes()).isEqualTo(PNG);
        }
        assertThat(fx.count("SELECT COUNT(*) FROM ticket_events WHERE ticket_id = ? AND type IN ('ABERTO', 'ROTEADO')",
                opened.id())).isEqualTo(2);
    }

    @Test
    void invalidAttachmentCreatesNothing() {
        long requester = fx.user("USER");
        MultipartFile exe = new MockMultipartFile("files", "x.exe", "application/octet-stream", new byte[] {1});

        assertThatThrownBy(() -> tickets.open(login(requester, "USER"), Segment.DEFEITO_APP, "Anexo inválido", List.of(exe)))
                .isInstanceOf(ValidationException.class);
        assertThat(fx.count("SELECT COUNT(*) FROM tickets WHERE user_id = ?", requester)).isZero();
    }

    @Test
    void requesterListsOnlyOwnTickets() {
        long me = fx.user("USER");
        long someoneElse = fx.user("USER");
        long mine = fx.ticket(me, "FEEDBACK_SUGESTAO");
        fx.ticket(someoneElse, "FEEDBACK_SUGESTAO");

        assertThat(tickets.mine(login(me, "USER"))).extracting(TicketSummaryResponse::id).containsExactly(mine);
    }

    @Test
    void anotherUserCannotSeeTheTicket() {
        long owner = fx.user("USER");
        long stranger = fx.user("USER");
        long ticket = fx.ticket(owner, "DEFEITO_APP");

        assertThatThrownBy(() -> tickets.detail(login(stranger, "USER"), ticket)).isInstanceOf(NotFoundException.class);
    }

    @Test
    void requesterAndAgentExchangeMessages() {
        long requester = fx.user("USER");
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticketFor(requester, "DEFEITO_APP").status("EM_ATENDIMENTO").assignedTo(agent).insert();

        tickets.postMessage(login(fx.userOf(agent), "EMPLOYEE"), ticket, "Qual a versão do app?", null);
        MessageResponse reply = tickets.postMessage(login(requester, "USER"), ticket, "Versão 2.3.1", List.of(png("tela.png")));

        assertThat(reply.senderType()).isEqualTo(SenderType.USER);
        assertThat(reply.attachments()).hasSize(1);
        assertThat(tickets.messages(login(requester, "USER"), ticket))
                .extracting(MessageResponse::senderType)
                .containsExactly(SenderType.EMPLOYEE, SenderType.USER);
    }

    @Test
    void requesterCannotPostOnAClosedTicket() {
        long requester = fx.user("USER");
        long ticket = fx.ticketFor(requester, "DEFEITO_APP").status("FECHADO").insert();

        assertThatThrownBy(() -> tickets.postMessage(login(requester, "USER"), ticket, "Oi?", null))
                .isInstanceOf(ConflictException.class);
    }

    @Test
    void confirmingClosesAResolvedTicket() {
        long requester = fx.user("USER");
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticketFor(requester, "DEFEITO_APP").status("RESOLVIDO").assignedTo(agent)
                .resolvedAt(OffsetDateTime.now(ZoneOffset.UTC)).insert();

        assertThat(tickets.confirm(login(requester, "USER"), ticket).status()).isEqualTo(TicketStatus.FECHADO);
        assertThat(fx.count("SELECT COUNT(*) FROM ticket_events WHERE ticket_id = ? AND type = 'FECHADO'", ticket))
                .isEqualTo(1);
    }

    @Test
    void reopeningPutsTheTicketBackInService() {
        long requester = fx.user("USER");
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticketFor(requester, "DEFEITO_APP").status("RESOLVIDO").assignedTo(agent)
                .resolvedAt(OffsetDateTime.now(ZoneOffset.UTC)).insert();

        TicketDetailResponse reopened = tickets.reopen(login(requester, "USER"), ticket);

        assertThat(reopened.status()).isEqualTo(TicketStatus.EM_ATENDIMENTO);
        assertThat(reopened.assignee().id()).isEqualTo(agent);
        assertThat(fx.count("SELECT COUNT(*) FROM ticket_messages WHERE ticket_id = ? AND sender_type = 'SYSTEM'", ticket))
                .isEqualTo(1);
        assertThat(fx.count("SELECT COUNT(*) FROM ticket_events WHERE ticket_id = ? AND type = 'REABERTO'", ticket))
                .isEqualTo(1);
    }
}
