package com.edu.api.chatbot.service;

import com.edu.api.chatbot.dto.ChatbotHandoffResponse;
import com.edu.api.chatbot.dto.ChatbotMessageResponse;
import com.edu.api.chatbot.dto.ChatbotOptionResponse;
import com.edu.api.chatbot.dto.ChatbotReplyRequest;
import com.edu.api.chatbot.dto.ChatbotTranscriptResponse;
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
import com.edu.api.ticket.entity.Ticket;
import com.edu.api.ticket.entity.TicketTypeConfig;
import com.edu.api.ticket.repository.TicketTypeConfigRepository;
import com.edu.api.user.entity.AdminUser;
import com.edu.api.user.repository.AdminUserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * Máquina de estados do Mentor Edu (chatbot nível 0). Cada turno grava a
 * mensagem do usuário e as respostas do bot e devolve as opções do novo estado.
 */
@Service
public class ChatbotService {

    static final int MAX_TEXT_LENGTH = 500;
    static final int MAX_USER_MESSAGES = 30;
    static final int MAX_MENU_QUESTIONS = 4;
    static final int MAX_MISSES = 2;
    static final int MAX_DESCRIPTION_LENGTH = 2000;

    static final String SEGMENT = "segment:";
    static final String FAQ = "faq:";
    static final String MENU = "menu";
    static final String HUMAN = "human";
    static final String RESOLVED = "resolved";
    static final String NOT_RESOLVED = "not_resolved";

    private final ChatbotConversationRepository conversations;
    private final ChatbotMessageRepository messages;
    private final ChatbotFaqRepository faqs;
    private final ChatbotFunctions functions;
    private final TicketTypeConfigRepository configs;
    private final AdminUserRepository users;
    private final Clock clock;

    public ChatbotService(ChatbotConversationRepository conversations, ChatbotMessageRepository messages,
                          ChatbotFaqRepository faqs, ChatbotFunctions functions, TicketTypeConfigRepository configs,
                          AdminUserRepository users, Clock clock) {
        this.conversations = conversations;
        this.messages = messages;
        this.faqs = faqs;
        this.functions = functions;
        this.configs = configs;
        this.users = users;
        this.clock = clock;
    }

    @Transactional
    public ChatbotTurnResponse start(AuthenticatedUser user) {
        Instant now = clock.instant();
        AdminUser owner = users.getReferenceById(user.id());
        ChatbotConversation conversation = conversations.save(ChatbotConversation.start(owner, now));
        List<ChatbotMessage> turn = new ArrayList<>();
        bot(conversation, turn, ChatbotTexts.greeting(owner.getName()), null, now);
        return response(conversation, turn);
    }

    @Transactional
    public ChatbotTurnResponse reply(AuthenticatedUser user, long conversationId, ChatbotReplyRequest request) {
        String text = typedText(request);
        ChatbotConversation conversation = ownForUpdate(user, conversationId);
        conversation.requireOpen();
        Instant now = clock.instant();
        List<ChatbotMessage> turn = new ArrayList<>();

        if (text != null) {
            turn.add(messages.save(ChatbotMessage.userText(conversation, text, now)));
            answer(conversation, text, turn, now);
        } else {
            Choice choice = choicesFor(conversation).stream()
                    .filter(candidate -> candidate.id().equals(request.optionId()))
                    .findFirst()
                    .orElseThrow(() -> new ValidationException("optionId: '" + request.optionId()
                            + "' não vale no estado " + conversation.getState()));
            turn.add(messages.save(ChatbotMessage.userOption(conversation, choice.label(), choice.id(), now)));
            choose(conversation, choice, turn, now);
        }

        if (conversation.isOpen()
                && messages.countBySender(conversation.getId(), ChatbotSender.USER) >= MAX_USER_MESSAGES) {
            handOff(conversation, ChatbotTexts.HANDOFF, turn, now);
        }
        return response(conversation, turn);
    }

    /**
     * Trava a conversa que vai virar ticket, na transação da abertura: ela tem
     * de ser do solicitante (senão 404) e estar em ENCAMINHAMENTO (senão 409).
     */
    @Transactional
    public ChatbotConversation claimForTicket(AuthenticatedUser user, long conversationId) {
        ChatbotConversation conversation = ownForUpdate(user, conversationId);
        if (conversation.getState() != ChatbotState.ENCAMINHAMENTO) {
            throw new ConflictException("Conversa " + conversationId + " não está aguardando a abertura de um ticket");
        }
        return conversation;
    }

    /** Liga o ticket recém-aberto à conversa travada por {@link #claimForTicket} e a encerra. */
    @Transactional
    public void linkTicket(ChatbotConversation conversation, Ticket ticket) {
        conversation.linkTicket(ticket, clock.instant());
    }

    /** A conversa que originou o ticket; quem chama já conferiu a visibilidade do ticket. */
    @Transactional(readOnly = true)
    public ChatbotTranscriptResponse transcript(Ticket ticket) {
        ChatbotConversation conversation = conversations.findByTicketId(ticket.getId())
                .orElseThrow(() -> new NotFoundException("Ticket " + ticket.getId() + " não veio do chatbot"));
        List<ChatbotMessageResponse> lines = messages.findByConversation(conversation.getId()).stream()
                .map(ChatbotService::message)
                .toList();
        return new ChatbotTranscriptResponse(conversation.getId(), conversation.getCreatedAt(), lines);
    }

    /** Trava a conversa; a de outro usuário responde 404, como a inexistente. */
    private ChatbotConversation ownForUpdate(AuthenticatedUser user, long conversationId) {
        return conversations.findForUpdate(conversationId)
                .filter(found -> found.isOwnedBy(user.id()))
                .orElseThrow(() -> new NotFoundException("Conversa " + conversationId + " não encontrada"));
    }

    /** O texto digitado, sem espaços nas pontas; nulo quando o usuário tocou numa opção. */
    private static String typedText(ChatbotReplyRequest request) {
        if ((request.text() == null) == (request.optionId() == null)) {
            throw new ValidationException("Envie text ou optionId, um dos dois");
        }
        if (request.text() == null) {
            return null;
        }
        String text = request.text().strip();
        if (text.isEmpty()) {
            throw new ValidationException("text: não pode ficar em branco");
        }
        if (text.length() > MAX_TEXT_LENGTH) {
            throw new ValidationException("text: máximo de " + MAX_TEXT_LENGTH + " caracteres");
        }
        return text;
    }

    private void answer(ChatbotConversation conversation, String text, List<ChatbotMessage> turn, Instant now) {
        Optional<ChatbotFaq> match = functions.answerFor(text, conversation.getSegment()).flatMap(faqs::findById);
        if (match.isPresent()) {
            showAnswer(conversation, match.get(), turn, now);
            return;
        }
        conversation.miss(now);
        if (conversation.getMisses() >= MAX_MISSES) {
            handOff(conversation, ChatbotTexts.HANDOFF_AFTER_MISSES, turn, now);
        } else {
            bot(conversation, turn, ChatbotTexts.NOT_UNDERSTOOD, null, now);
        }
    }

    private void choose(ChatbotConversation conversation, Choice choice, List<ChatbotMessage> turn, Instant now) {
        if (choice.segment() != null) {
            conversation.chooseSegment(choice.segment(), now);
            bot(conversation, turn, ChatbotTexts.segmentChosen(choice.label()), null, now);
        } else if (choice.faq() != null) {
            showAnswer(conversation, choice.faq(), turn, now);
        } else if (choice.id().equals(MENU)) {
            conversation.backToMenu(now);
            bot(conversation, turn, ChatbotTexts.OTHER_SUBJECT, null, now);
        } else if (choice.id().equals(RESOLVED)) {
            conversation.resolve(now);
            bot(conversation, turn, ChatbotTexts.RESOLVED, null, now);
        } else {
            handOff(conversation, ChatbotTexts.HANDOFF, turn, now);
        }
    }

    private void showAnswer(ChatbotConversation conversation, ChatbotFaq faq, List<ChatbotMessage> turn, Instant now) {
        conversation.showAnswer(faq, now);
        bot(conversation, turn, faq.getAnswer(), faq, now);
        bot(conversation, turn, ChatbotTexts.DID_IT_HELP, null, now);
    }

    private void handOff(ChatbotConversation conversation, String text, List<ChatbotMessage> turn, Instant now) {
        conversation.handOff(now);
        bot(conversation, turn, text, null, now);
    }

    private void bot(ChatbotConversation conversation, List<ChatbotMessage> turn, String body, ChatbotFaq faq,
                     Instant now) {
        turn.add(messages.save(ChatbotMessage.bot(conversation, body, faq, now)));
    }

    /** As opções que o estado atual oferece; só elas valem como resposta. */
    private List<Choice> choicesFor(ChatbotConversation conversation) {
        List<Choice> choices = new ArrayList<>();
        switch (conversation.getState()) {
            case INICIO -> {
                configs.findActive().stream()
                        .sorted(Comparator.comparing(TicketTypeConfig::getSegment))
                        .forEach(config -> choices.add(new Choice(SEGMENT + config.getSegmentCode(),
                                config.getLabel(), config.getSegment(), null)));
                choices.add(Choice.of(HUMAN, ChatbotTexts.HUMAN_LABEL));
            }
            case SEGMENTO -> {
                faqs.findActiveBySegment(conversation.getSegment()).stream()
                        .limit(MAX_MENU_QUESTIONS)
                        .forEach(faq -> choices.add(new Choice(FAQ + faq.getId(), faq.getQuestion(), null, faq)));
                choices.add(Choice.of(MENU, ChatbotTexts.OTHER_SUBJECT_LABEL));
                choices.add(Choice.of(HUMAN, ChatbotTexts.HUMAN_LABEL));
            }
            case CONFIRMACAO -> {
                choices.add(Choice.of(RESOLVED, ChatbotTexts.RESOLVED_LABEL));
                choices.add(Choice.of(NOT_RESOLVED, ChatbotTexts.NOT_RESOLVED_LABEL));
            }
            default -> {
                // ENCAMINHAMENTO, RESOLVIDA e ENCAMINHADA não oferecem opções.
            }
        }
        return choices;
    }

    private ChatbotTurnResponse response(ChatbotConversation conversation, List<ChatbotMessage> turn) {
        List<ChatbotOptionResponse> options = choicesFor(conversation).stream()
                .map(choice -> new ChatbotOptionResponse(choice.id(), choice.label()))
                .toList();
        ChatbotHandoffResponse handoff = conversation.getState() == ChatbotState.ENCAMINHAMENTO
                ? new ChatbotHandoffResponse(conversation.getSegment(), draft(conversation))
                : null;
        return new ChatbotTurnResponse(conversation.getId(), conversation.getState(),
                turn.stream().map(ChatbotService::message).toList(), options, handoff);
    }

    /** Descrição sugerida para o ticket: os textos livres do usuário, na ordem. */
    private String draft(ChatbotConversation conversation) {
        String texts = messages.findByConversation(conversation.getId()).stream()
                .filter(ChatbotMessage::isFreeText)
                .map(ChatbotMessage::getBody)
                .collect(Collectors.joining("\n"));
        if (texts.isEmpty() && conversation.getCurrentFaq() != null) {
            texts = ChatbotTexts.QUESTION_PREFIX + conversation.getCurrentFaq().getQuestion();
        }
        return texts.length() > MAX_DESCRIPTION_LENGTH ? texts.substring(0, MAX_DESCRIPTION_LENGTH) : texts;
    }

    static ChatbotMessageResponse message(ChatbotMessage message) {
        return new ChatbotMessageResponse(message.getId(), message.getSender(), message.getBody(),
                message.getCreatedAt());
    }

    /** Uma opção do estado atual; segment ou faq dizem o que ela escolhe. */
    private record Choice(String id, String label, Segment segment, ChatbotFaq faq) {

        static Choice of(String id, String label) {
            return new Choice(id, label, null, null);
        }
    }
}
