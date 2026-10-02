package com.edu.api.chatbot.entity;

import com.edu.api.ticket.entity.Segment;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

/** Item do FAQ do bot. As palavras-chave ficam em chatbot_faq_keywords e só o PL/SQL as lê. */
@Getter
@Entity
@Table(name = "chatbot_faq")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ChatbotFaq {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private Segment segment;

    @Column(nullable = false, length = 200)
    private String question;

    @Column(nullable = false, length = 1000)
    private String answer;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    @Column(nullable = false)
    private boolean active;

    public ChatbotFaq(Segment segment, String question, String answer, int sortOrder) {
        this.segment = segment;
        this.question = question;
        this.answer = answer;
        this.sortOrder = sortOrder;
        this.active = true;
    }
}
