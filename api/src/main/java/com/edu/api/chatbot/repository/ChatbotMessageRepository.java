package com.edu.api.chatbot.repository;

import com.edu.api.chatbot.entity.ChatbotMessage;
import com.edu.api.chatbot.entity.ChatbotSender;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface ChatbotMessageRepository extends JpaRepository<ChatbotMessage, Long> {

    @Query("select m from ChatbotMessage m where m.conversation.id = :conversationId order by m.id")
    List<ChatbotMessage> findByConversation(@Param("conversationId") Long conversationId);

    @Query("select count(m) from ChatbotMessage m where m.conversation.id = :conversationId and m.sender = :sender")
    long countBySender(@Param("conversationId") Long conversationId, @Param("sender") ChatbotSender sender);
}
