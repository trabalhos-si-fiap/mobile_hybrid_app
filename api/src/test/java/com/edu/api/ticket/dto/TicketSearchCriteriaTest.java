package com.edu.api.ticket.dto;

import com.edu.api.shared.exception.ValidationException;
import com.edu.api.ticket.dto.TicketSearchCriteria.Direction;
import com.edu.api.ticket.dto.TicketSearchCriteria.Sort;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.stream.Stream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TicketSearchCriteriaTest {

    private static final Instant AT = Instant.parse("2030-01-01T12:00:00Z");

    private static TicketSearchCriteria with(String text, String sort, String direction, Integer limit,
                                             Instant from, Instant to) {
        return TicketSearchCriteria.of(null, null, null, null, from, to, text, null, sort, direction, limit);
    }

    @Test
    void appliesTheDefaultsWhenNothingIsGiven() {
        assertThat(with(null, null, null, null, null, null)).isEqualTo(new TicketSearchCriteria(
                null, null, null, null, null, null, null, null, Sort.CREATED_AT, Direction.DESC, 50));
    }

    @Test
    void parsesSortAndDirectionIgnoringCase() {
        TicketSearchCriteria criteria = with(null, "SLADUEAT", "Asc", null, null, null);

        assertThat(criteria.sort()).isEqualTo(Sort.SLA_DUE_AT);
        assertThat(criteria.direction()).isEqualTo(Direction.ASC);
    }

    @Test
    void mapsEverySortParameterToItsDatabaseName() {
        assertThat(Stream.of("createdAt", "updatedAt", "slaDueAt", "priority")
                .map(sort -> with(null, sort, null, null, null, null).sort().plsqlName()))
                .containsExactly("CRIADO_EM", "ATUALIZADO_EM", "PRAZO_SLA", "PRIORIDADE");
    }

    @Test
    void rejectsAnUnknownSort() {
        assertThatThrownBy(() -> with(null, "name", null, null, null, null))
                .isInstanceOf(ValidationException.class)
                .hasMessage("sort: use createdAt, updatedAt, slaDueAt ou priority");
    }

    @Test
    void rejectsAnUnknownDirection() {
        assertThatThrownBy(() -> with(null, null, "up", null, null, null))
                .isInstanceOf(ValidationException.class)
                .hasMessage("direction: use asc ou desc");
    }

    @Test
    void acceptsLimitsFromOneToTwoHundred() {
        assertThat(with(null, null, null, 1, null, null).limit()).isEqualTo(1);
        assertThat(with(null, null, null, 200, null, null).limit()).isEqualTo(200);
    }

    @Test
    void rejectsALimitOutsideOneToTwoHundred() {
        for (int limit : new int[] {0, 201}) {
            assertThatThrownBy(() -> with(null, null, null, limit, null, null))
                    .isInstanceOf(ValidationException.class)
                    .hasMessage("limit: use de 1 a 200");
        }
    }

    @Test
    void trimsTheTextAndAcceptsThreeToTwoHundredCharacters() {
        assertThat(with("  abc  ", null, null, null, null, null).text()).isEqualTo("abc");
        assertThat(with("x".repeat(200), null, null, null, null, null).text()).hasSize(200);
    }

    @Test
    void rejectsTextShorterThanThreeOrLongerThanTwoHundred() {
        for (String text : new String[] {" ab ", "x".repeat(201)}) {
            assertThatThrownBy(() -> with(text, null, null, null, null, null))
                    .isInstanceOf(ValidationException.class)
                    .hasMessage("text: use de 3 a 200 caracteres");
        }
    }

    @Test
    void treatsBlankTextAsAbsent() {
        assertThat(with("   ", null, null, null, null, null).text()).isNull();
        assertThat(with("", null, null, null, null, null).text()).isNull();
    }

    @Test
    void rejectsAPeriodThatEndsBeforeItStartsButAcceptsAnEmptyOne() {
        assertThatThrownBy(() -> with(null, null, null, null, AT.plusSeconds(1), AT))
                .isInstanceOf(ValidationException.class)
                .hasMessage("from: use um instante anterior ou igual a to");
        assertThat(with(null, null, null, null, AT, AT).from()).isEqualTo(AT);
    }
}
