package com.edu.api.chatbot;

import com.edu.api.chatbot.entity.ChatbotConversation;
import com.edu.api.chatbot.entity.ChatbotFaq;
import com.edu.api.chatbot.entity.ChatbotMessage;
import com.edu.api.chatbot.entity.ChatbotSender;
import com.edu.api.chatbot.entity.ChatbotState;
import com.edu.api.chatbot.repository.ChatbotConversationRepository;
import com.edu.api.chatbot.repository.ChatbotFaqRepository;
import com.edu.api.chatbot.repository.ChatbotMessageRepository;
import com.edu.api.support.OracleIntegrationTest;
import com.edu.api.ticket.entity.Segment;
import com.edu.api.ticket.entity.Ticket;
import com.edu.api.ticket.entity.TicketChannel;
import com.edu.api.user.entity.AdminUser;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jpa.test.autoconfigure.TestEntityManager;
import org.springframework.test.context.ActiveProfiles;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class ChatbotMappingIT extends OracleIntegrationTest {

    private static final Instant NOW = Instant.parse("2030-01-01T12:00:00Z");

    @Autowired
    private TestEntityManager em;

    @Autowired
    private ChatbotConversationRepository conversations;

    @Autowired
    private ChatbotMessageRepository messages;

    @Autowired
    private ChatbotFaqRepository faqs;

    private AdminUser user() {
        return em.persist(new AdminUser("Ana Souza", UUID.randomUUID() + "@teste.edu", "x", "USER"));
    }

    @Test
    void persistsAConversationWithItsMessagesAndTicket() {
        AdminUser owner = user();
        ChatbotFaq faq = em.persist(new ChatbotFaq(Segment.PROBLEMA_PEDIDO, "Qual o prazo de entrega?",
                "De 3 a 7 dias úteis.", 1));
        ChatbotConversation conversation = ChatbotConversation.start(owner, NOW);
        conversation.chooseSegment(Segment.PROBLEMA_PEDIDO, NOW);
        conversation.showAnswer(faq, NOW);
        conversation.handOff(NOW);
        em.persist(conversation);
        em.persist(ChatbotMessage.bot(conversation, "Olá, Ana!", null, NOW));
        em.persist(ChatbotMessage.userOption(conversation, "Problemas com pedido", "segment:PROBLEMA_PEDIDO", NOW));
        em.persist(ChatbotMessage.userText(conversation, "Quando chega meu pedido?", NOW));
        em.persist(ChatbotMessage.bot(conversation, faq.getAnswer(), faq, NOW));
        Ticket ticket = em.persist(Ticket.open(owner, Segment.PROBLEMA_PEDIDO, "Quando chega meu pedido?",
                TicketChannel.CHATBOT_IA, NOW));
        conversation.linkTicket(ticket, NOW.plusSeconds(60));
        em.flush();
        em.clear();

        ChatbotConversation found = conversations.findByTicketId(ticket.getId()).orElseThrow();
        assertThat(found.getId()).isEqualTo(conversation.getId());
        assertThat(found.getState()).isEqualTo(ChatbotState.ENCAMINHADA);
        assertThat(found.getSegment()).isEqualTo(Segment.PROBLEMA_PEDIDO);
        assertThat(found.getCurrentFaq().getId()).isEqualTo(faq.getId());
        assertThat(found.getMisses()).isZero();
        assertThat(found.getFinishedAt()).isEqualTo(NOW.plusSeconds(60));

        List<ChatbotMessage> transcript = messages.findByConversation(conversation.getId());
        assertThat(transcript).extracting(ChatbotMessage::getSender)
                .containsExactly(ChatbotSender.BOT, ChatbotSender.USER, ChatbotSender.USER, ChatbotSender.BOT);
        assertThat(transcript).extracting(ChatbotMessage::isFreeText).containsExactly(false, false, true, false);
        assertThat(transcript.get(3).getFaq().getId()).isEqualTo(faq.getId());
        assertThat(messages.countBySender(conversation.getId(), ChatbotSender.USER)).isEqualTo(2);
    }

    @Test
    void listsTheActiveQuestionsOfASegmentInOrder() {
        ChatbotFaq second = em.persist(new ChatbotFaq(Segment.PROBLEMA_PEDIDO, "Segunda", "R2", 2));
        ChatbotFaq first = em.persist(new ChatbotFaq(Segment.PROBLEMA_PEDIDO, "Primeira", "R1", 1));
        ChatbotFaq inactive = em.persist(new ChatbotFaq(Segment.PROBLEMA_PEDIDO, "Inativa", "R0", 0));
        em.persist(new ChatbotFaq(Segment.DEFEITO_APP, "De outro segmento", "R", 1));
        em.flush();
        em.getEntityManager().createNativeQuery("UPDATE chatbot_faq SET active = FALSE WHERE id = ?")
                .setParameter(1, inactive.getId())
                .executeUpdate();
        em.clear();

        assertThat(faqs.findActiveBySegment(Segment.PROBLEMA_PEDIDO)).extracting(ChatbotFaq::getId)
                .containsExactly(first.getId(), second.getId());
    }

    @Test
    void rejectsAKeywordThatIsNotNormalized() {
        ChatbotFaq faq = em.persist(new ChatbotFaq(Segment.DEFEITO_APP, "Notificações", "R", 1));
        em.flush();

        assertThatThrownBy(() -> em.getEntityManager()
                .createNativeQuery("INSERT INTO chatbot_faq_keywords (faq_id, keyword) VALUES (?, 'notificação')")
                .setParameter(1, faq.getId())
                .executeUpdate())
                .hasStackTraceContaining("CK_CHATBOT_KEYWORDS_NORMALIZED");
    }

    @Test
    void rejectsAKeywordWeightOtherThanOneOrTwo() {
        ChatbotFaq faq = em.persist(new ChatbotFaq(Segment.DEFEITO_APP, "Notificações", "R", 1));
        em.flush();

        assertThatThrownBy(() -> em.getEntityManager()
                .createNativeQuery("INSERT INTO chatbot_faq_keywords (faq_id, keyword, weight) VALUES (?, 'notific', 3)")
                .setParameter(1, faq.getId())
                .executeUpdate())
                .hasStackTraceContaining("CK_CHATBOT_KEYWORDS_WEIGHT");
    }
}
