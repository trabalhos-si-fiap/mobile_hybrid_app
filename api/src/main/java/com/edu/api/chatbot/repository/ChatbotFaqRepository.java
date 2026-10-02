package com.edu.api.chatbot.repository;

import com.edu.api.chatbot.entity.ChatbotFaq;
import com.edu.api.ticket.entity.Segment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface ChatbotFaqRepository extends JpaRepository<ChatbotFaq, Long> {

    @Query("select f from ChatbotFaq f where f.segment = :segment and f.active = true order by f.sortOrder, f.id")
    List<ChatbotFaq> findActiveBySegment(@Param("segment") Segment segment);
}
