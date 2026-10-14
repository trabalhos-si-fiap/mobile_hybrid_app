package com.edu.api.ticket.dto;

import com.edu.api.shared.exception.ValidationException;
import com.edu.api.ticket.entity.Segment;
import com.edu.api.ticket.entity.TicketPriority;
import com.edu.api.ticket.entity.TicketStatus;

import java.time.Instant;
import java.util.Locale;

/**
 * Critérios de GET /tickets/search, já validados e com os padrões aplicados.
 * Filtro nulo quer dizer "não filtrar".
 */
public record TicketSearchCriteria(
        TicketStatus status,
        Segment segment,
        TicketPriority priority,
        Long assigneeId,
        Instant from,
        Instant to,
        String text,
        Boolean engineeringAlert,
        Sort sort,
        Direction direction,
        int limit
) {

    public static final int DEFAULT_LIMIT = 50;

    public enum Sort {
        CREATED_AT("createdAt", "CRIADO_EM"),
        UPDATED_AT("updatedAt", "ATUALIZADO_EM"),
        SLA_DUE_AT("slaDueAt", "PRAZO_SLA"),
        PRIORITY("priority", "PRIORIDADE");

        private final String parameter;
        private final String plsqlName;

        Sort(String parameter, String plsqlName) {
            this.parameter = parameter;
            this.plsqlName = plsqlName;
        }

        /** O valor que a PKG_TICKETS.PR_BUSCAR_TICKETS aceita em p_ordenar_por. */
        public String plsqlName() {
            return plsqlName;
        }

        static Sort parse(String value) {
            if (value == null || value.isBlank()) {
                return CREATED_AT;
            }
            for (Sort sort : values()) {
                if (sort.parameter.equalsIgnoreCase(value.trim())) {
                    return sort;
                }
            }
            throw new ValidationException("sort: use createdAt, updatedAt, slaDueAt ou priority");
        }
    }

    public enum Direction {
        ASC,
        DESC;

        static Direction parse(String value) {
            if (value == null || value.isBlank()) {
                return DESC;
            }
            try {
                return valueOf(value.trim().toUpperCase(Locale.ROOT));
            } catch (IllegalArgumentException e) {
                throw new ValidationException("direction: use asc ou desc");
            }
        }
    }

    /** Monta os critérios a partir dos parâmetros da requisição; valor inválido vira ValidationException (400). */
    public static TicketSearchCriteria of(TicketStatus status, Segment segment, TicketPriority priority,
                                          Long assigneeId, Instant from, Instant to, String text,
                                          Boolean engineeringAlert, String sort, String direction, Integer limit) {
        int size = limit == null ? DEFAULT_LIMIT : limit;
        if (size < 1 || size > 200) {
            throw new ValidationException("limit: use de 1 a 200");
        }
        String trimmed = text == null || text.isBlank() ? null : text.trim();
        if (trimmed != null && (trimmed.length() < 3 || trimmed.length() > 200)) {
            throw new ValidationException("text: use de 3 a 200 caracteres");
        }
        if (from != null && to != null && from.isAfter(to)) {
            throw new ValidationException("from: use um instante anterior ou igual a to");
        }
        return new TicketSearchCriteria(status, segment, priority, assigneeId, from, to, trimmed, engineeringAlert,
                Sort.parse(sort), Direction.parse(direction), size);
    }
}
