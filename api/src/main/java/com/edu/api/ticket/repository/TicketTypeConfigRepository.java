package com.edu.api.ticket.repository;

import com.edu.api.ticket.entity.TicketTypeConfig;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;

public interface TicketTypeConfigRepository extends JpaRepository<TicketTypeConfig, String> {

    @Query("select c from TicketTypeConfig c join fetch c.skill where c.active = true order by c.segmentCode")
    List<TicketTypeConfig> findActive();

    @Query("select c.segmentCode from TicketTypeConfig c where c.skill.id in :skillIds")
    List<String> findSegmentCodesBySkillIds(@Param("skillIds") Collection<Long> skillIds);
}
