package com.edu.api.support;

import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Dados do chatbot criados via JDBC na transação do teste; como o
 * {@link TicketFixtures}, nunca depende do seed de demonstração.
 */
public final class ChatbotFixtures {

    private final JdbcTemplate jdbc;
    private final TicketFixtures rows;

    public ChatbotFixtures(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
        this.rows = new TicketFixtures(jdbc);
    }

    /** Item ativo do FAQ; as palavras-chave já vão normalizadas (minúsculas, sem acento). */
    public long faq(String segment, int sortOrder, String question, String answer, String... keywords) {
        long faqId = rows.insert("INSERT INTO chatbot_faq (segment, question, answer, sort_order) VALUES (?, ?, ?, ?)",
                segment, question, answer, sortOrder);
        for (String keyword : keywords) {
            jdbc.update("INSERT INTO chatbot_faq_keywords (faq_id, keyword) VALUES (?, ?)", faqId, keyword);
        }
        return faqId;
    }

    public void deactivate(long faqId) {
        jdbc.update("UPDATE chatbot_faq SET active = FALSE WHERE id = ?", faqId);
    }

    /** Conversa sem mensagens, direto num estado. */
    public long conversation(long userId, String state) {
        return rows.insert("INSERT INTO chatbot_conversations (user_id, state) VALUES (?, ?)", userId, state);
    }
}
