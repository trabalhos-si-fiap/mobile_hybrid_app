package com.edu.api.chatbot.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Getter
@Entity
@Table(name = "chatbot_messages")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ChatbotMessage {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "conversation_id", nullable = false)
    private ChatbotConversation conversation;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private ChatbotSender sender;

    @Column(nullable = false, length = 1000)
    private String body;

    /** Opção que o usuário tocou; nulo quando ele digitou. */
    @Column(name = "option_id", length = 40)
    private String optionId;

    /** Item do FAQ de onde veio a resposta do bot. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "faq_id")
    private ChatbotFaq faq;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    private ChatbotMessage(ChatbotConversation conversation, ChatbotSender sender, String body, String optionId,
                           ChatbotFaq faq, Instant now) {
        this.conversation = conversation;
        this.sender = sender;
        this.body = body;
        this.optionId = optionId;
        this.faq = faq;
        this.createdAt = now;
    }

    public static ChatbotMessage bot(ChatbotConversation conversation, String body, ChatbotFaq faq, Instant now) {
        return new ChatbotMessage(conversation, ChatbotSender.BOT, body, null, faq, now);
    }

    public static ChatbotMessage userText(ChatbotConversation conversation, String text, Instant now) {
        return new ChatbotMessage(conversation, ChatbotSender.USER, text, null, null, now);
    }

    /** A escolha de uma opção fica gravada com o rótulo, para a transcrição ler como diálogo. */
    public static ChatbotMessage userOption(ChatbotConversation conversation, String label, String optionId,
                                            Instant now) {
        return new ChatbotMessage(conversation, ChatbotSender.USER, label, optionId, null, now);
    }

    public boolean isFreeText() {
        return sender == ChatbotSender.USER && optionId == null;
    }
}
