package com.edu.api.chatbot.service;

import com.edu.api.chatbot.dto.ChatbotHandoffResponse;
import com.edu.api.chatbot.dto.ChatbotMessageResponse;
import com.edu.api.chatbot.dto.ChatbotOptionResponse;
import com.edu.api.chatbot.dto.ChatbotReplyRequest;
import com.edu.api.chatbot.dto.ChatbotTurnResponse;
import com.edu.api.chatbot.entity.ChatbotConversation;
import com.edu.api.chatbot.entity.ChatbotFaq;
import com.edu.api.chatbot.entity.ChatbotMessage;
import com.edu.api.chatbot.entity.ChatbotSender;
import com.edu.api.chatbot.entity.ChatbotState;
import com.edu.api.chatbot.plsql.ChatbotFunctions;
import com.edu.api.chatbot.repository.ChatbotConversationRepository;
import com.edu.api.chatbot.repository.ChatbotFaqRepository;
import com.edu.api.chatbot.repository.ChatbotMessageRepository;
import com.edu.api.security.AuthenticatedUser;
import com.edu.api.shared.exception.ConflictException;
import com.edu.api.shared.exception.NotFoundException;
import com.edu.api.shared.exception.ValidationException;
import com.edu.api.ticket.entity.Segment;
import com.edu.api.ticket.entity.TicketTypeConfig;
import com.edu.api.ticket.repository.TicketTypeConfigRepository;
import com.edu.api.user.entity.AdminUser;
import com.edu.api.user.repository.AdminUserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.BeanUtils;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** A máquina de estados sem banco: os repositórios são dublês que guardam em listas. */
class ChatbotServiceTest {

    private static final Instant NOW = Instant.parse("2030-01-01T12:00:00Z");
    private static final long CONVERSATION_ID = 42L;
    private static final AuthenticatedUser ANA = new AuthenticatedUser(7L, "ana@edu.com", "USER");
    private static final String HANDOFF =
            "Vou te passar para um atendente. Revise o pedido, anexe evidências se tiver e envie.";
    private static final List<String> MENU_OPTIONS = List.of(
            "segment:DEFEITO_APP", "segment:PROBLEMA_PEDIDO", "segment:FEEDBACK_SUGESTAO", "human");

    private final ChatbotConversationRepository conversations = mock(ChatbotConversationRepository.class);
    private final ChatbotMessageRepository messages = mock(ChatbotMessageRepository.class);
    private final ChatbotFaqRepository faqs = mock(ChatbotFaqRepository.class);
    private final ChatbotFunctions functions = mock(ChatbotFunctions.class);
    private final TicketTypeConfigRepository configs = mock(TicketTypeConfigRepository.class);
    private final AdminUserRepository users = mock(AdminUserRepository.class);

    private final List<ChatbotMessage> saved = new ArrayList<>();
    private final List<ChatbotFaq> faqItems = new ArrayList<>();
    private ChatbotConversation conversation;
    private ChatbotService service;

    @BeforeEach
    void setUp() {
        AdminUser ana = new AdminUser("Ana Souza", "ana@edu.com", "x", "USER");
        ReflectionTestUtils.setField(ana, "id", 7L);
        when(users.getReferenceById(7L)).thenReturn(ana);
        // Na ordem do repositório real (código do segmento); o bot reordena pelo enum.
        when(configs.findActive()).thenReturn(List.of(
                config(Segment.DEFEITO_APP, "Defeito no App / Problemas com App"),
                config(Segment.FEEDBACK_SUGESTAO, "Feedback / Sugestões"),
                config(Segment.PROBLEMA_PEDIDO, "Problemas com pedido")));
        when(conversations.save(any())).thenAnswer(call -> {
            conversation = call.getArgument(0);
            ReflectionTestUtils.setField(conversation, "id", CONVERSATION_ID);
            return conversation;
        });
        when(conversations.findForUpdate(CONVERSATION_ID)).thenAnswer(call -> Optional.ofNullable(conversation));
        when(messages.save(any())).thenAnswer(call -> {
            ChatbotMessage message = call.getArgument(0);
            ReflectionTestUtils.setField(message, "id", saved.size() + 1L);
            saved.add(message);
            return message;
        });
        when(messages.findByConversation(CONVERSATION_ID)).thenAnswer(call -> List.copyOf(saved));
        when(messages.countBySender(CONVERSATION_ID, ChatbotSender.USER))
                .thenAnswer(call -> saved.stream().filter(m -> m.getSender() == ChatbotSender.USER).count());
        when(faqs.findActiveBySegment(any())).thenAnswer(call -> faqItems.stream()
                .filter(faq -> faq.getSegment() == call.getArgument(0))
                .sorted(Comparator.comparingInt(ChatbotFaq::getSortOrder))
                .toList());
        when(faqs.findById(anyLong())).thenAnswer(call -> faqItems.stream()
                .filter(faq -> faq.getId().equals(call.getArgument(0)))
                .findFirst());
        when(functions.answerFor(anyString(), any())).thenReturn(Optional.empty());
        service = new ChatbotService(conversations, messages, faqs, functions, configs, users,
                Clock.fixed(NOW, ZoneOffset.UTC));
    }

    private static TicketTypeConfig config(Segment segment, String label) {
        TicketTypeConfig config = BeanUtils.instantiateClass(TicketTypeConfig.class);
        ReflectionTestUtils.setField(config, "segmentCode", segment.name());
        ReflectionTestUtils.setField(config, "label", label);
        return config;
    }

    private ChatbotFaq faq(long id, Segment segment, int sortOrder, String question, String answer) {
        ChatbotFaq faq = new ChatbotFaq(segment, question, answer, sortOrder);
        ReflectionTestUtils.setField(faq, "id", id);
        faqItems.add(faq);
        return faq;
    }

    private ChatbotTurnResponse option(String optionId) {
        return service.reply(ANA, CONVERSATION_ID, new ChatbotReplyRequest(null, optionId));
    }

    private ChatbotTurnResponse text(String text) {
        return service.reply(ANA, CONVERSATION_ID, new ChatbotReplyRequest(text, null));
    }

    private static List<String> bodies(ChatbotTurnResponse turn) {
        return turn.messages().stream().map(ChatbotMessageResponse::body).toList();
    }

    private static List<String> optionIds(ChatbotTurnResponse turn) {
        return turn.options().stream().map(ChatbotOptionResponse::id).toList();
    }

    @Test
    void startGreetsByTheFirstNameAndOffersTheActiveSegments() {
        ChatbotTurnResponse turn = service.start(ANA);

        assertThat(turn.conversationId()).isEqualTo(CONVERSATION_ID);
        assertThat(turn.state()).isEqualTo(ChatbotState.INICIO);
        assertThat(turn.messages()).singleElement().satisfies(message -> {
            assertThat(message.sender()).isEqualTo(ChatbotSender.BOT);
            assertThat(message.body()).isEqualTo(
                    "Olá, Ana! Sou o Mentor Edu, o assistente do Edu. Sobre o que você precisa de ajuda?");
            assertThat(message.createdAt()).isEqualTo(NOW);
        });
        assertThat(turn.options()).containsExactly(
                new ChatbotOptionResponse("segment:DEFEITO_APP", "Defeito no App / Problemas com App"),
                new ChatbotOptionResponse("segment:PROBLEMA_PEDIDO", "Problemas com pedido"),
                new ChatbotOptionResponse("segment:FEEDBACK_SUGESTAO", "Feedback / Sugestões"),
                new ChatbotOptionResponse("human", "Falar com atendente"));
        assertThat(turn.handoff()).isNull();
    }

    @Test
    void choosingASegmentOffersUpToFourQuestions() {
        for (int i = 1; i <= 5; i++) {
            faq(i, Segment.PROBLEMA_PEDIDO, i, "Pergunta " + i, "Resposta " + i);
        }
        faq(9, Segment.DEFEITO_APP, 1, "De outro segmento", "Outra");
        service.start(ANA);

        ChatbotTurnResponse turn = option("segment:PROBLEMA_PEDIDO");

        assertThat(turn.state()).isEqualTo(ChatbotState.SEGMENTO);
        assertThat(turn.messages()).extracting(ChatbotMessageResponse::sender)
                .containsExactly(ChatbotSender.USER, ChatbotSender.BOT);
        assertThat(bodies(turn)).containsExactly("Problemas com pedido",
                "Estas são as dúvidas mais comuns sobre Problemas com pedido. Escolha uma ou escreva a sua.");
        assertThat(turn.options()).containsExactly(
                new ChatbotOptionResponse("faq:1", "Pergunta 1"),
                new ChatbotOptionResponse("faq:2", "Pergunta 2"),
                new ChatbotOptionResponse("faq:3", "Pergunta 3"),
                new ChatbotOptionResponse("faq:4", "Pergunta 4"),
                new ChatbotOptionResponse("menu", "Outro assunto"),
                new ChatbotOptionResponse("human", "Falar com atendente"));
        assertThat(conversation.getSegment()).isEqualTo(Segment.PROBLEMA_PEDIDO);
    }

    @Test
    void choosingAQuestionShowsTheAnswerAndAsksIfItHelped() {
        ChatbotFaq deadline = faq(1, Segment.PROBLEMA_PEDIDO, 1, "Qual o prazo de entrega?", "De 3 a 7 dias úteis.");
        service.start(ANA);
        option("segment:PROBLEMA_PEDIDO");

        ChatbotTurnResponse turn = option("faq:1");

        assertThat(turn.state()).isEqualTo(ChatbotState.CONFIRMACAO);
        assertThat(bodies(turn)).containsExactly("Qual o prazo de entrega?", "De 3 a 7 dias úteis.",
                "Isso resolveu sua dúvida?");
        assertThat(turn.options()).containsExactly(
                new ChatbotOptionResponse("resolved", "Resolveu"),
                new ChatbotOptionResponse("not_resolved", "Não resolveu"));
        assertThat(saved.get(saved.size() - 2).getFaq()).isSameAs(deadline);
        assertThat(conversation.getCurrentFaq()).isSameAs(deadline);
    }

    @Test
    void resolvedEndsTheConversation() {
        faq(1, Segment.PROBLEMA_PEDIDO, 1, "Qual o prazo de entrega?", "De 3 a 7 dias úteis.");
        service.start(ANA);
        option("segment:PROBLEMA_PEDIDO");
        option("faq:1");

        ChatbotTurnResponse turn = option("resolved");

        assertThat(turn.state()).isEqualTo(ChatbotState.RESOLVIDA);
        assertThat(bodies(turn)).containsExactly("Resolveu", "Que bom! Se precisar, é só chamar.");
        assertThat(turn.options()).isEmpty();
        assertThat(turn.handoff()).isNull();
        assertThat(conversation.getFinishedAt()).isEqualTo(NOW);
    }

    @Test
    void notResolvedHandsOffWithTheQuestionWhenNothingWasTyped() {
        faq(1, Segment.PROBLEMA_PEDIDO, 1, "Qual o prazo de entrega?", "De 3 a 7 dias úteis.");
        service.start(ANA);
        option("segment:PROBLEMA_PEDIDO");
        option("faq:1");

        ChatbotTurnResponse turn = option("not_resolved");

        assertThat(turn.state()).isEqualTo(ChatbotState.ENCAMINHAMENTO);
        assertThat(bodies(turn)).containsExactly("Não resolveu", HANDOFF);
        assertThat(turn.options()).isEmpty();
        assertThat(turn.handoff()).isEqualTo(
                new ChatbotHandoffResponse(Segment.PROBLEMA_PEDIDO, "Dúvida: Qual o prazo de entrega?"));
    }

    @Test
    void humanFromTheMenuHandsOffWithoutSegmentOrDescription() {
        service.start(ANA);

        ChatbotTurnResponse turn = option("human");

        assertThat(turn.state()).isEqualTo(ChatbotState.ENCAMINHAMENTO);
        assertThat(bodies(turn)).containsExactly("Falar com atendente", HANDOFF);
        assertThat(turn.handoff()).isEqualTo(new ChatbotHandoffResponse(null, ""));
        assertThat(conversation.getFinishedAt()).isNull();
    }

    @Test
    void otherSubjectGoesBackToTheMenuWithoutTheSegment() {
        service.start(ANA);
        option("segment:PROBLEMA_PEDIDO");

        ChatbotTurnResponse turn = option("menu");

        assertThat(turn.state()).isEqualTo(ChatbotState.INICIO);
        assertThat(bodies(turn)).containsExactly("Outro assunto", "Certo. Sobre o que você precisa de ajuda?");
        assertThat(optionIds(turn)).isEqualTo(MENU_OPTIONS);
        assertThat(conversation.getSegment()).isNull();
    }

    @Test
    void typedTextThatMatchesShowsTheAnswerAndTakesTheItemSegment() {
        faq(5, Segment.DEFEITO_APP, 2, "Não recebo notificações", "Ative as notificações do Edu no celular.");
        when(functions.answerFor("Não chega notificação", null)).thenReturn(Optional.of(5L));
        service.start(ANA);

        ChatbotTurnResponse turn = text("  Não chega notificação  ");

        assertThat(turn.state()).isEqualTo(ChatbotState.CONFIRMACAO);
        assertThat(bodies(turn)).containsExactly("Não chega notificação", "Ative as notificações do Edu no celular.",
                "Isso resolveu sua dúvida?");
        assertThat(optionIds(turn)).containsExactly("resolved", "not_resolved");
        assertThat(conversation.getSegment()).isEqualTo(Segment.DEFEITO_APP);
    }

    @Test
    void typedTextKeepsTheChosenSegmentAndSendsItToTheFunction() {
        faq(5, Segment.DEFEITO_APP, 2, "Não recebo notificações", "Ative as notificações do Edu no celular.");
        when(functions.answerFor("o app não avisa", Segment.PROBLEMA_PEDIDO)).thenReturn(Optional.of(5L));
        service.start(ANA);
        option("segment:PROBLEMA_PEDIDO");

        ChatbotTurnResponse turn = text("o app não avisa");

        assertThat(turn.state()).isEqualTo(ChatbotState.CONFIRMACAO);
        assertThat(conversation.getSegment()).isEqualTo(Segment.PROBLEMA_PEDIDO);
        verify(functions).answerFor("o app não avisa", Segment.PROBLEMA_PEDIDO);
    }

    @Test
    void theFirstMissGoesBackToTheMenu() {
        service.start(ANA);

        ChatbotTurnResponse turn = text("blablabla");

        assertThat(turn.state()).isEqualTo(ChatbotState.INICIO);
        assertThat(bodies(turn)).containsExactly("blablabla",
                "Não entendi. Pode explicar de outro jeito ou escolher uma opção?");
        assertThat(optionIds(turn)).isEqualTo(MENU_OPTIONS);
        assertThat(conversation.getMisses()).isEqualTo(1);
    }

    @Test
    void theSecondMissHandsOffWithTheTypedTextsInOrder() {
        service.start(ANA);
        option("segment:PROBLEMA_PEDIDO");
        text("meu pacote sumiu");

        ChatbotTurnResponse turn = text("ninguém me responde");

        assertThat(turn.state()).isEqualTo(ChatbotState.ENCAMINHAMENTO);
        assertThat(bodies(turn)).containsExactly("ninguém me responde", "Não consegui entender. " + HANDOFF);
        assertThat(turn.options()).isEmpty();
        assertThat(turn.handoff()).isEqualTo(new ChatbotHandoffResponse(Segment.PROBLEMA_PEDIDO,
                "meu pacote sumiu\nninguém me responde"));
    }

    @Test
    void theHandoffDescriptionIsCutAt2000Characters() {
        faq(1, Segment.PROBLEMA_PEDIDO, 1, "Qual o prazo de entrega?", "De 3 a 7 dias úteis.");
        when(functions.answerFor(anyString(), any())).thenReturn(Optional.of(1L));
        service.start(ANA);
        for (String letter : List.of("a", "b", "c", "d", "e")) {
            text(letter.repeat(500));
        }

        ChatbotTurnResponse turn = option("not_resolved");

        assertThat(turn.handoff().description()).isEqualTo(
                "a".repeat(500) + "\n" + "b".repeat(500) + "\n" + "c".repeat(500) + "\n" + "d".repeat(497));
    }

    @Test
    void the30thUserMessageHandsOffWhenTheTurnLeftTheConversationOpen() {
        service.start(ANA);
        for (int i = 1; i <= 29; i++) {
            option(i % 2 == 1 ? "segment:PROBLEMA_PEDIDO" : "menu");
        }
        assertThat(conversation.getState()).isEqualTo(ChatbotState.SEGMENTO);

        ChatbotTurnResponse turn = option("menu");

        assertThat(turn.state()).isEqualTo(ChatbotState.ENCAMINHAMENTO);
        assertThat(bodies(turn)).containsExactly("Outro assunto", "Certo. Sobre o que você precisa de ajuda?", HANDOFF);
        assertThat(turn.options()).isEmpty();
        assertThat(turn.handoff()).isEqualTo(new ChatbotHandoffResponse(null, ""));
    }

    @Test
    void the30thUserMessageThatResolvesDoesNotHandOff() {
        faq(1, Segment.PROBLEMA_PEDIDO, 1, "Qual o prazo de entrega?", "De 3 a 7 dias úteis.");
        service.start(ANA);
        for (int i = 1; i <= 27; i++) {
            option(i % 2 == 1 ? "segment:PROBLEMA_PEDIDO" : "menu");
        }
        option("faq:1");
        when(functions.answerFor("e se atrasar?", Segment.PROBLEMA_PEDIDO)).thenReturn(Optional.of(1L));
        text("e se atrasar?");

        ChatbotTurnResponse turn = option("resolved");

        assertThat(turn.state()).isEqualTo(ChatbotState.RESOLVIDA);
        assertThat(bodies(turn)).containsExactly("Resolveu", "Que bom! Se precisar, é só chamar.");
        assertThat(turn.handoff()).isNull();
    }

    @Test
    void rejectsAnOptionThatTheStateDoesNotOffer() {
        faq(1, Segment.PROBLEMA_PEDIDO, 1, "Qual o prazo de entrega?", "De 3 a 7 dias úteis.");
        faq(2, Segment.DEFEITO_APP, 1, "Não consigo entrar", "Redefina a senha.");
        service.start(ANA);

        assertThatThrownBy(() -> option("resolved")).isInstanceOf(ValidationException.class)
                .hasMessage("optionId: 'resolved' não vale no estado INICIO");
        assertThatThrownBy(() -> option("segment:XYZ")).isInstanceOf(ValidationException.class);
        assertThatThrownBy(() -> option("faq:1")).isInstanceOf(ValidationException.class);
        option("segment:PROBLEMA_PEDIDO");
        assertThatThrownBy(() -> option("faq:2")).isInstanceOf(ValidationException.class);
        assertThat(saved).hasSize(3);
    }

    @Test
    void rejectsTextAndOptionTogetherOrNeither() {
        service.start(ANA);

        assertThatThrownBy(() -> service.reply(ANA, CONVERSATION_ID, new ChatbotReplyRequest("oi", "human")))
                .isInstanceOf(ValidationException.class);
        assertThatThrownBy(() -> service.reply(ANA, CONVERSATION_ID, new ChatbotReplyRequest(null, null)))
                .isInstanceOf(ValidationException.class);
    }

    @Test
    void rejectsBlankOrTooLongText() {
        service.start(ANA);

        assertThatThrownBy(() -> text("   ")).isInstanceOf(ValidationException.class)
                .hasMessage("text: não pode ficar em branco");
        assertThatThrownBy(() -> text("x".repeat(501))).isInstanceOf(ValidationException.class)
                .hasMessage("text: máximo de 500 caracteres");
        assertThat(text("x".repeat(500)).state()).isEqualTo(ChatbotState.INICIO);
    }

    @Test
    void rejectsMessagesAfterTheHandoff() {
        service.start(ANA);
        option("human");

        assertThatThrownBy(() -> text("ainda está aí?")).isInstanceOf(ConflictException.class);
        assertThatThrownBy(() -> option("human")).isInstanceOf(ConflictException.class);
    }

    @Test
    void hidesConversationsOfOtherUsers() {
        service.start(ANA);
        AuthenticatedUser stranger = new AuthenticatedUser(8L, "outra@edu.com", "USER");

        assertThatThrownBy(() -> service.reply(stranger, CONVERSATION_ID, new ChatbotReplyRequest(null, "human")))
                .isInstanceOf(NotFoundException.class);
        assertThatThrownBy(() -> service.reply(ANA, 99L, new ChatbotReplyRequest(null, "human")))
                .isInstanceOf(NotFoundException.class);
    }
}
