package com.edu.api.chatbot.entity;

import com.edu.api.shared.exception.ConflictException;
import com.edu.api.ticket.entity.Segment;
import com.edu.api.ticket.entity.Ticket;
import com.edu.api.user.entity.AdminUser;
import org.junit.jupiter.api.Test;

import java.time.Instant;

import static com.edu.api.support.Entities.ticket;
import static com.edu.api.support.Entities.user;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ChatbotConversationTest {

    private static final Instant NOW = Instant.parse("2030-01-01T12:00:00Z");

    private final AdminUser owner = user(7, "USER");
    private final ChatbotFaq appFaq = new ChatbotFaq(Segment.DEFEITO_APP, "Como atualizar o app?", "Pela loja.", 4);

    @Test
    void startsAtTheMenu() {
        ChatbotConversation conversation = ChatbotConversation.start(owner, NOW);

        assertThat(conversation.getState()).isEqualTo(ChatbotState.INICIO);
        assertThat(conversation.getMisses()).isZero();
        assertThat(conversation.isOpen()).isTrue();
        assertThat(conversation.isOwnedBy(7L)).isTrue();
        assertThat(conversation.isOwnedBy(8L)).isFalse();
    }

    @Test
    void anAnswerGivesTheItemSegmentOnlyToAConversationWithoutOne() {
        ChatbotConversation withoutSegment = ChatbotConversation.start(owner, NOW);
        ChatbotConversation withSegment = ChatbotConversation.start(owner, NOW);
        withSegment.chooseSegment(Segment.PROBLEMA_PEDIDO, NOW);

        withoutSegment.showAnswer(appFaq, NOW);
        withSegment.showAnswer(appFaq, NOW);

        assertThat(withoutSegment.getSegment()).isEqualTo(Segment.DEFEITO_APP);
        assertThat(withSegment.getSegment()).isEqualTo(Segment.PROBLEMA_PEDIDO);
        assertThat(withSegment.getState()).isEqualTo(ChatbotState.CONFIRMACAO);
        assertThat(withSegment.getCurrentFaq()).isSameAs(appFaq);
    }

    @Test
    void otherSubjectDropsTheSegmentButAMissKeepsIt() {
        ChatbotConversation menu = ChatbotConversation.start(owner, NOW);
        menu.chooseSegment(Segment.PROBLEMA_PEDIDO, NOW);
        ChatbotConversation missed = ChatbotConversation.start(owner, NOW);
        missed.chooseSegment(Segment.PROBLEMA_PEDIDO, NOW);

        menu.backToMenu(NOW);
        missed.miss(NOW);

        assertThat(menu.getSegment()).isNull();
        assertThat(missed.getSegment()).isEqualTo(Segment.PROBLEMA_PEDIDO);
        assertThat(missed.getMisses()).isEqualTo(1);
        assertThat(missed.getState()).isEqualTo(ChatbotState.INICIO);
    }

    @Test
    void onlyTheMenuStatesAcceptMessages() {
        ChatbotConversation handedOff = ChatbotConversation.start(owner, NOW);
        handedOff.handOff(NOW);
        ChatbotConversation resolved = ChatbotConversation.start(owner, NOW);
        resolved.resolve(NOW);

        assertThatThrownBy(handedOff::requireOpen).isInstanceOf(ConflictException.class);
        assertThatThrownBy(resolved::requireOpen).isInstanceOf(ConflictException.class);
        assertThat(resolved.getFinishedAt()).isEqualTo(NOW);
    }

    @Test
    void linksATicketOnlyAfterTheHandoff() {
        Ticket opened = ticket(100, owner, Segment.PROBLEMA_PEDIDO);
        ChatbotConversation conversation = ChatbotConversation.start(owner, NOW);

        assertThatThrownBy(() -> conversation.linkTicket(opened, NOW)).isInstanceOf(ConflictException.class);

        conversation.handOff(NOW);
        conversation.linkTicket(opened, NOW.plusSeconds(60));

        assertThat(conversation.getState()).isEqualTo(ChatbotState.ENCAMINHADA);
        assertThat(conversation.getTicket()).isSameAs(opened);
        assertThat(conversation.getFinishedAt()).isEqualTo(NOW.plusSeconds(60));
        assertThatThrownBy(() -> conversation.linkTicket(opened, NOW)).isInstanceOf(ConflictException.class);
    }
}
