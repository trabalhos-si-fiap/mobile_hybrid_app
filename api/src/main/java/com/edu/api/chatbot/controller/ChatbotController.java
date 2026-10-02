package com.edu.api.chatbot.controller;

import com.edu.api.chatbot.dto.ChatbotReplyRequest;
import com.edu.api.chatbot.dto.ChatbotTurnResponse;
import com.edu.api.chatbot.service.ChatbotService;
import com.edu.api.security.AuthenticatedUser;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/chatbot/conversations")
public class ChatbotController {

    private final ChatbotService chatbot;

    public ChatbotController(ChatbotService chatbot) {
        this.chatbot = chatbot;
    }

    @PostMapping
    public ResponseEntity<ChatbotTurnResponse> start(@AuthenticationPrincipal AuthenticatedUser user) {
        return ResponseEntity.status(HttpStatus.CREATED).body(chatbot.start(user));
    }

    @PostMapping("/{conversationId}/messages")
    public ChatbotTurnResponse reply(@AuthenticationPrincipal AuthenticatedUser user,
                                     @PathVariable long conversationId,
                                     @RequestBody ChatbotReplyRequest request) {
        return chatbot.reply(user, conversationId, request);
    }
}
