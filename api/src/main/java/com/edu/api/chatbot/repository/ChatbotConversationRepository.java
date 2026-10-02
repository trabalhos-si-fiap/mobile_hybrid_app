package com.edu.api.chatbot.repository;

import com.edu.api.chatbot.entity.ChatbotConversation;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface ChatbotConversationRepository extends JpaRepository<ChatbotConversation, Long> {

    /** Trava a linha: dois envios simultâneos na mesma conversa rodam um depois do outro. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select c from ChatbotConversation c where c.id = :id")
    Optional<ChatbotConversation> findForUpdate(@Param("id") Long id);

    @Query("select c from ChatbotConversation c where c.ticket.id = :ticketId")
    Optional<ChatbotConversation> findByTicketId(@Param("ticketId") Long ticketId);
}
