package com.edu.api.chatbot.plsql;

import com.edu.api.support.ChatbotFixtures;
import com.edu.api.support.OracleIntegrationTest;
import com.edu.api.ticket.entity.Segment;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jdbc.test.autoconfigure.JdbcTest;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import static org.assertj.core.api.Assertions.assertThat;

/** FN_CHATBOT_RESPOSTA pelo gateway Java, com o FAQ criado por cada teste. */
@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
@Import(ChatbotFunctions.class)
class ChatbotFunctionsIT extends OracleIntegrationTest {

    @Autowired
    private JdbcTemplate jdbc;

    @Autowired
    private ChatbotFunctions functions;

    private ChatbotFixtures bot;

    @BeforeEach
    void setUp() {
        bot = new ChatbotFixtures(jdbc);
    }

    @Test
    void matchesIgnoringCaseAndAccents() {
        long camera = bot.faq("DEFEITO_APP", 3, "A câmera ou o anexo não funciona", "Libere a câmera.", "camera");
        long returns = bot.faq("PROBLEMA_PEDIDO", 2, "Como faço trocas e devoluções?", "Em até 7 dias.", "devoluc");

        assertThat(functions.answerFor("A CÂMERA não abre!", null)).contains(camera);
        assertThat(functions.answerFor("Quero a DEVOLUÇÃO", null)).contains(returns);
    }

    @Test
    void matchesAStemInsideLongerWords() {
        long tracking = bot.faq("PROBLEMA_PEDIDO", 3, "Como rastrear o meu pedido?", "Use o código de rastreio.",
                "rastre");

        assertThat(functions.answerFor("Quero o rastreamento da compra", null)).contains(tracking);
        assertThat(functions.answerFor("como faço pra rastrear", null)).contains(tracking);
    }

    @Test
    void prefersTheItemWithMoreKeywords() {
        bot.faq("PROBLEMA_PEDIDO", 1, "Qual o prazo de entrega?", "R", "prazo", "entreg");
        long exchange = bot.faq("PROBLEMA_PEDIDO", 2, "Como faço trocas e devoluções?", "R", "troc", "devol", "prazo");

        assertThat(functions.answerFor("Qual o prazo para troca ou devolução?", null)).contains(exchange);
    }

    @Test
    void breaksATieByTheConversationSegment() {
        long missingItem = bot.faq("PROBLEMA_PEDIDO", 1, "Pedido com item faltando", "R", "faltand");
        long attachment = bot.faq("DEFEITO_APP", 2, "Câmera ou anexo não funciona", "R", "anex");

        assertThat(functions.answerFor("Está faltando o anexo", null)).contains(missingItem);
        assertThat(functions.answerFor("Está faltando o anexo", Segment.DEFEITO_APP)).contains(attachment);
    }

    @Test
    void thenBySortOrderThenById() {
        bot.faq("FEEDBACK_SUGESTAO", 2, "Como avaliar o app?", "R", "avali");
        long first = bot.faq("FEEDBACK_SUGESTAO", 1, "Como enviar uma sugestão?", "R", "avali");
        bot.faq("FEEDBACK_SUGESTAO", 1, "Onde acompanho o que sugeri?", "R", "avali");

        assertThat(functions.answerFor("quero avaliar", Segment.FEEDBACK_SUGESTAO)).contains(first);
    }

    @Test
    void returnsNothingWithoutAMatch() {
        bot.faq("PROBLEMA_PEDIDO", 1, "Qual o prazo de entrega?", "R", "prazo", "entreg");

        assertThat(functions.answerFor("Bom dia, tudo bem?", null)).isEmpty();
    }

    @Test
    void returnsNothingForEmptyText() {
        bot.faq("PROBLEMA_PEDIDO", 1, "Qual o prazo de entrega?", "R", "prazo", "entreg");

        assertThat(functions.answerFor(null, null)).isEmpty();
        assertThat(functions.answerFor("", null)).isEmpty();
        assertThat(functions.answerFor("   ", null)).isEmpty();
        assertThat(functions.answerFor("?!", null)).isEmpty();
    }

    @Test
    void ignoresInactiveItems() {
        long inactive = bot.faq("PROBLEMA_PEDIDO", 1, "Qual o prazo de entrega?", "R", "prazo", "entreg");
        long active = bot.faq("PROBLEMA_PEDIDO", 2, "Meu pedido está atrasado", "R", "prazo");
        bot.deactivate(inactive);

        assertThat(functions.answerFor("prazo de entrega", null)).contains(active);
    }
}
