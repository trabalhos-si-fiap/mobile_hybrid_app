package com.edu.api.ticket.entity;

import com.edu.api.employee.entity.Skill;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

/** Matriz de triagem (TICKET_TIPO_CONFIG): segmento → skill → fila → SLA. */
@Getter
@Entity
@Table(name = "ticket_tipo_config")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class TicketTypeConfig {

    @Id
    @Column(name = "segment", length = 30)
    private String segmentCode;

    @Column(nullable = false, length = 100)
    private String label;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "skill_id", nullable = false)
    private Skill skill;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private TicketQueue queue;

    @Enumerated(EnumType.STRING)
    @Column(name = "default_priority", nullable = false, length = 10)
    private TicketPriority defaultPriority;

    @Column(name = "sla_minutes", nullable = false)
    private int slaMinutes;

    @Column(name = "escalation_minutes", nullable = false)
    private int escalationMinutes;

    @Column(nullable = false)
    private boolean active;

    public Segment getSegment() {
        return Segment.valueOf(segmentCode);
    }
}
