package com.edu.api.chatbot.plsql;

import com.edu.api.ticket.entity.Segment;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.SqlParameterValue;
import org.springframework.stereotype.Component;

import java.sql.Types;
import java.util.Optional;

/** Único ponto do Java que chama a FN_CHATBOT_RESPOSTA. Usa a conexão da transação corrente. */
@Component
public class ChatbotFunctions {

    private final JdbcTemplate jdbc;

    public ChatbotFunctions(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** O item do FAQ que melhor casa com o texto; vazio quando nenhuma palavra-chave aparece nele. */
    public Optional<Long> answerFor(String text, Segment segment) {
        Long faqId = jdbc.queryForObject("SELECT FN_CHATBOT_RESPOSTA(?, ?) FROM dual", Long.class,
                new SqlParameterValue(Types.VARCHAR, text),
                new SqlParameterValue(Types.VARCHAR, segment == null ? null : segment.name()));
        return Optional.ofNullable(faqId);
    }
}
