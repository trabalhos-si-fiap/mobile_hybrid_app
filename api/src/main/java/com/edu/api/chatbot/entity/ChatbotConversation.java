package com.edu.api.chatbot.entity;

import com.edu.api.shared.exception.ConflictException;
import com.edu.api.ticket.entity.Segment;
import com.edu.api.ticket.entity.Ticket;
import com.edu.api.user.entity.AdminUser;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.DynamicUpdate;

import java.time.Instant;
import java.util.EnumSet;
import java.util.Set;

@Getter
@Entity
@Table(name = "chatbot_conversations")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@DynamicUpdate
public class ChatbotConversation {

    private static final Set<ChatbotState> OPEN =
            EnumSet.of(ChatbotState.INICIO, ChatbotState.SEGMENTO, ChatbotState.CONFIRMACAO);

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AdminUser user;

    @Enumerated(EnumType.STRING)
    @Column(length = 30)
    private Segment segment;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ChatbotState state;

    @Column(nullable = false)
    private int misses;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "current_faq_id")
    private ChatbotFaq currentFaq;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "ticket_id", unique = true)
    private Ticket ticket;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "finished_at")
    private Instant finishedAt;

    public static ChatbotConversation start(AdminUser user, Instant now) {
        ChatbotConversation conversation = new ChatbotConversation();
        conversation.user = user;
        conversation.state = ChatbotState.INICIO;
        conversation.createdAt = now;
        conversation.updatedAt = now;
        return conversation;
    }

    public boolean isOwnedBy(Long userId) {
        return user.getId().equals(userId);
    }

    public boolean isOpen() {
        return OPEN.contains(state);
    }

    public void requireOpen() {
        if (!isOpen()) {
            throw new ConflictException("Conversa " + id + " não aceita mensagens no estado " + state);
        }
    }

    public void chooseSegment(Segment chosen, Instant now) {
        segment = chosen;
        state = ChatbotState.SEGMENTO;
        updatedAt = now;
    }

    /** "Outro assunto": o usuário largou o segmento escolhido. */
    public void backToMenu(Instant now) {
        segment = null;
        state = ChatbotState.INICIO;
        updatedAt = now;
    }

    /** Resposta do FAQ; a conversa sem segmento herda o do item. */
    public void showAnswer(ChatbotFaq faq, Instant now) {
        currentFaq = faq;
        if (segment == null) {
            segment = faq.getSegment();
        }
        state = ChatbotState.CONFIRMACAO;
        updatedAt = now;
    }

    /** Texto sem casamento: volta ao menu, mantendo o segmento. */
    public void miss(Instant now) {
        misses++;
        state = ChatbotState.INICIO;
        updatedAt = now;
    }

    public void resolve(Instant now) {
        state = ChatbotState.RESOLVIDA;
        finishedAt = now;
        updatedAt = now;
    }

    public void handOff(Instant now) {
        state = ChatbotState.ENCAMINHAMENTO;
        updatedAt = now;
    }

    public void linkTicket(Ticket opened, Instant now) {
        if (state != ChatbotState.ENCAMINHAMENTO) {
            throw new ConflictException("Conversa " + id + " não está aguardando a abertura de um ticket");
        }
        ticket = opened;
        state = ChatbotState.ENCAMINHADA;
        finishedAt = now;
        updatedAt = now;
    }
}
