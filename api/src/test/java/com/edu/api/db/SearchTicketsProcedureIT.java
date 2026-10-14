package com.edu.api.db;

import com.edu.api.support.OracleIntegrationTest;
import com.edu.api.support.Plsql;
import com.edu.api.support.Plsql.TicketSearch;
import com.edu.api.support.TicketFixtures;
import com.edu.api.support.TicketFixtures.TicketRow;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jdbc.test.autoconfigure.JdbcTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.function.Supplier;
import java.util.stream.Collectors;

import static com.edu.api.support.TicketFixtures.T0;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * PKG_TICKETS.PR_BUSCAR_TICKETS. O Oracle de teste é compartilhado: cada caso
 * busca como o solicitante do próprio teste (só os tickets dele aparecem) ou
 * filtra pela janela W, em que nenhum outro teste cria tickets.
 */
@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class SearchTicketsProcedureIT extends OracleIntegrationTest {

    private static final OffsetDateTime W = OffsetDateTime.parse("2041-03-01T10:00:00Z");

    @Autowired
    private JdbcTemplate jdbc;

    private TicketFixtures fx;
    private Plsql plsql;
    private long requester;

    @BeforeEach
    void setUp() {
        fx = new TicketFixtures(jdbc);
        plsql = new Plsql(jdbc);
        requester = fx.user("USER");
    }

    private TicketSearch mine() {
        return TicketSearch.as(requester);
    }

    private TicketSearch inWindow(long userId) {
        return TicketSearch.as(userId).createdBetween(W, W.plusMinutes(1));
    }

    private List<Long> ids(TicketSearch search) {
        return plsql.search(search).stream().map(row -> ((Number) row.get("id")).longValue()).toList();
    }

    private long ticket(String segment, OffsetDateTime createdAt) {
        return fx.ticketFor(requester, segment).createdAt(createdAt).insert();
    }

    @Test
    void withoutFiltersReturnsTheVisibleTicketsNewestFirst() {
        long first = ticket("DEFEITO_APP", W);
        long second = ticket("PROBLEMA_PEDIDO", W.plusMinutes(1));
        long third = ticket("FEEDBACK_SUGESTAO", W.plusMinutes(2));

        assertThat(ids(mine())).containsExactly(third, second, first);
    }

    @Test
    void filtersByStatus() {
        long queued = fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA").insert();
        fx.ticketFor(requester, "DEFEITO_APP").status("ABERTO").insert();

        assertThat(ids(mine().status("EM_FILA"))).containsExactly(queued);
    }

    @Test
    void filtersBySegment() {
        long order = ticket("PROBLEMA_PEDIDO", W);
        ticket("DEFEITO_APP", W);

        assertThat(ids(mine().segment("PROBLEMA_PEDIDO"))).containsExactly(order);
    }

    @Test
    void filtersByPriority() {
        long critical = fx.ticketFor(requester, "DEFEITO_APP").priority("CRITICA").insert();
        fx.ticketFor(requester, "DEFEITO_APP").priority("NORMAL").insert();

        assertThat(ids(mine().priority("CRITICA"))).containsExactly(critical);
    }

    @Test
    void filtersByAssignee() {
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long owned = fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA").assignedTo(agent).insert();
        fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA").insert();

        assertThat(ids(mine().assignee(agent))).containsExactly(owned);
    }

    @Test
    void filtersByEngineeringAlertInBothDirections() {
        long alerted = fx.ticketFor(requester, "DEFEITO_APP").engineeringAlert(true).insert();
        long quiet = fx.ticketFor(requester, "DEFEITO_APP").createdAt(T0.plusMinutes(1)).insert();

        assertThat(ids(mine().engineeringAlert(true))).containsExactly(alerted);
        assertThat(ids(mine().engineeringAlert(false))).containsExactly(quiet);
        assertThat(ids(mine())).containsExactly(quiet, alerted);
    }

    @Test
    void filtersByCreationPeriodIncludingTheStartAndExcludingTheEnd() {
        ticket("DEFEITO_APP", W.minusSeconds(1));
        long atStart = ticket("DEFEITO_APP", W);
        long inside = ticket("DEFEITO_APP", W.plusMinutes(30));
        ticket("DEFEITO_APP", W.plusHours(1));

        assertThat(ids(mine().createdBetween(W, W.plusHours(1)))).containsExactly(inside, atStart);
    }

    @Test
    void anEmptyPeriodReturnsNothing() {
        ticket("DEFEITO_APP", W);

        assertThat(ids(mine().createdBetween(W, W))).isEmpty();
    }

    @Test
    void filtersByTextIgnoringCase() {
        long crash = fx.ticketFor(requester, "DEFEITO_APP").description("O App FECHA no checkout").insert();
        fx.ticketFor(requester, "DEFEITO_APP").description("Pedido atrasado").insert();

        assertThat(ids(mine().text("app fecha"))).containsExactly(crash);
    }

    @Test
    void matchesAccentedTextIgnoringCase() {
        long camera = fx.ticketFor(requester, "DEFEITO_APP").description("A CÂMERA não abre").insert();

        assertThat(ids(mine().text("câmera"))).containsExactly(camera);
    }

    @Test
    void treatsLikeWildcardsAndBackslashAsPlainCharacters() {
        long percent = fx.ticketFor(requester, "DEFEITO_APP").description("Desconto de 50% sumiu").insert();
        long underscore = fx.ticketFor(requester, "DEFEITO_APP").createdAt(T0.plusMinutes(1))
                .description("Erro no campo cep_entrega").insert();
        long backslash = fx.ticketFor(requester, "DEFEITO_APP").createdAt(T0.plusMinutes(2))
                .description("Log em C:\\app\\log").insert();
        fx.ticketFor(requester, "DEFEITO_APP").createdAt(T0.plusMinutes(3))
                .description("Desconto de 500 reais no campo cepXentrega").insert();

        assertThat(ids(mine().text("50%"))).containsExactly(percent);
        assertThat(ids(mine().text("cep_entrega"))).containsExactly(underscore);
        assertThat(ids(mine().text("c:\\app"))).containsExactly(backslash);
        // Sem escapar a barra, "\a" no LIKE é ORA-01424.
        assertThat(ids(mine().text("\\ap"))).containsExactly(backslash);
    }

    @Test
    void ignoresWhitespaceOnlyText() {
        long any = ticket("DEFEITO_APP", W);

        assertThat(ids(mine().text("   "))).containsExactly(any);
    }

    @Test
    void combinesEveryFilter() {
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        Supplier<TicketRow> matching = () -> fx.ticketFor(requester, "DEFEITO_APP").status("EM_ATENDIMENTO")
                .priority("ALTA").assignedTo(agent).createdAt(W).description("Tela branca no login")
                .engineeringAlert(true);
        long match = matching.get().insert();
        matching.get().status("EM_FILA").insert();
        matching.get().priority("NORMAL").insert();
        matching.get().assignedTo(null).insert();
        matching.get().createdAt(W.plusHours(2)).insert();
        matching.get().description("Pedido atrasado").insert();
        matching.get().engineeringAlert(false).insert();
        fx.ticketFor(requester, "PROBLEMA_PEDIDO").status("EM_ATENDIMENTO").priority("ALTA").assignedTo(agent)
                .createdAt(W).description("Tela branca no login").engineeringAlert(true).insert();

        assertThat(ids(mine().status("EM_ATENDIMENTO").segment("DEFEITO_APP").priority("ALTA").assignee(agent)
                .createdBetween(W, W.plusHours(1)).text("tela branca").engineeringAlert(true)))
                .containsExactly(match);
    }

    @Test
    void anAgentSeesWhatTheyOpenedWhatTheyOwnAndTheirSkillSegments() {
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long agentUser = fx.userOf(agent);
        long other = fx.user("USER");
        long bySkill = fx.ticketFor(other, "DEFEITO_APP").createdAt(W).insert();
        long owned = fx.ticketFor(other, "PROBLEMA_PEDIDO").assignedTo(agent).createdAt(W).insert();
        long opened = fx.ticketFor(agentUser, "FEEDBACK_SUGESTAO").createdAt(W).insert();
        long hidden = fx.ticketFor(other, "PROBLEMA_PEDIDO").createdAt(W).insert();

        assertThat(ids(inWindow(agentUser)))
                .containsExactlyInAnyOrder(bySkill, owned, opened)
                .doesNotContain(hidden);
    }

    @Test
    void aSkillStillShowsTicketsOfAnInactiveSegment() {
        jdbc.update("UPDATE ticket_tipo_config SET active = FALSE WHERE segment = 'DEFEITO_APP'");
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = ticket("DEFEITO_APP", W);

        assertThat(ids(inWindow(fx.userOf(agent)))).containsExactly(ticket);
    }

    @Test
    void aUserWithoutAnAgentRecordSeesOnlyWhatTheyOpened() {
        long employeeWithoutRecord = fx.user("EMPLOYEE");
        long opened = fx.ticketFor(employeeWithoutRecord, "DEFEITO_APP").createdAt(W).insert();
        ticket("DEFEITO_APP", W);

        assertThat(ids(inWindow(employeeWithoutRecord))).containsExactly(opened);
    }

    @Test
    void visibilityCombinesWithTheAssigneeFilter() {
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long colleague = fx.employee("ONLINE", "DESENVOLVEDOR");
        fx.ticketFor(requester, "DEFEITO_APP").assignedTo(agent).createdAt(W).insert();
        long colleagues = fx.ticketFor(requester, "DEFEITO_APP").assignedTo(colleague).createdAt(W).insert();
        fx.ticketFor(requester, "PROBLEMA_PEDIDO").assignedTo(colleague).createdAt(W).insert();

        assertThat(ids(inWindow(fx.userOf(agent)).assignee(colleague))).containsExactly(colleagues);
    }

    @Test
    void seeingEverythingIncludesOtherPeoplesTickets() {
        long mine = ticket("DEFEITO_APP", W);
        long theirs = fx.ticketFor(fx.user("USER"), "PROBLEMA_PEDIDO").createdAt(W).insert();

        assertThat(ids(TicketSearch.asAdmin(requester).createdBetween(W, W.plusMinutes(1))))
                .containsExactlyInAnyOrder(mine, theirs);
    }

    @Test
    void sortsByEachColumnInBothDirections() {
        long a = fx.ticketFor(requester, "DEFEITO_APP").priority("CRITICA").createdAt(T0)
                .updatedAt(T0.plusMinutes(5)).slaDueAt(T0.plusMinutes(20)).insert();
        long b = fx.ticketFor(requester, "DEFEITO_APP").priority("NORMAL").createdAt(T0.plusMinutes(1))
                .updatedAt(T0.plusMinutes(4)).slaDueAt(T0.plusMinutes(10)).insert();
        long c = fx.ticketFor(requester, "DEFEITO_APP").priority("ALTA").createdAt(T0.plusMinutes(2))
                .updatedAt(T0.plusMinutes(3)).insert();

        assertThat(ids(mine().sort("CRIADO_EM", "ASC"))).containsExactly(a, b, c);
        assertThat(ids(mine().sort("CRIADO_EM", "DESC"))).containsExactly(c, b, a);
        assertThat(ids(mine().sort("ATUALIZADO_EM", "ASC"))).containsExactly(c, b, a);
        assertThat(ids(mine().sort("ATUALIZADO_EM", "DESC"))).containsExactly(a, b, c);
        assertThat(ids(mine().sort("PRAZO_SLA", "ASC"))).containsExactly(b, a, c);
        assertThat(ids(mine().sort("PRAZO_SLA", "DESC"))).containsExactly(a, b, c);
        assertThat(ids(mine().sort("PRIORIDADE", "ASC"))).containsExactly(b, c, a);
        assertThat(ids(mine().sort("PRIORIDADE", "DESC"))).containsExactly(a, c, b);
    }

    @Test
    void acceptsLowercaseSortAndDirection() {
        long older = ticket("DEFEITO_APP", W);
        long newer = ticket("DEFEITO_APP", W.plusMinutes(1));

        assertThat(ids(mine().sort("criado_em", "asc"))).containsExactly(older, newer);
    }

    @Test
    void breaksTiesByIdInTheSameDirection() {
        long first = ticket("DEFEITO_APP", W);
        long second = ticket("DEFEITO_APP", W);
        long third = ticket("DEFEITO_APP", W);

        assertThat(ids(mine().sort("CRIADO_EM", "ASC"))).containsExactly(first, second, third);
        assertThat(ids(mine().sort("CRIADO_EM", "DESC"))).containsExactly(third, second, first);
        assertThat(ids(mine().sort("PRIORIDADE", "DESC"))).containsExactly(third, second, first);
    }

    @Test
    void returnsAtMostTheLimit() {
        ticket("DEFEITO_APP", W);
        long second = ticket("DEFEITO_APP", W.plusMinutes(1));
        long third = ticket("DEFEITO_APP", W.plusMinutes(2));

        assertThat(ids(mine().limit(2))).containsExactly(third, second);
    }

    @Test
    void computesTheSlaStatusAtTheReference() {
        long atRisk = fx.ticketFor(requester, "DEFEITO_APP").status("EM_ATENDIMENTO").createdAt(T0)
                .slaStartedAt(T0).slaDueAt(T0.plusMinutes(100)).insert();
        long breached = fx.ticketFor(requester, "DEFEITO_APP").status("EM_ATENDIMENTO").createdAt(T0.plusMinutes(1))
                .slaStartedAt(T0).slaDueAt(T0.plusMinutes(10)).insert();
        long met = fx.ticketFor(requester, "DEFEITO_APP").status("RESOLVIDO").createdAt(T0.plusMinutes(2))
                .slaStartedAt(T0).slaDueAt(T0.plusMinutes(100)).resolvedAt(T0.plusMinutes(5)).insert();

        Map<Long, Object> sla = plsql.search(mine().reference(T0.plusMinutes(90))).stream()
                .collect(Collectors.toMap(row -> ((Number) row.get("id")).longValue(), row -> row.get("sla_status")));

        assertThat(sla).containsEntry(atRisk, "EM_RISCO").containsEntry(breached, "ESTOURADO")
                .containsEntry(met, "CUMPRIDO");
    }

    @Test
    void rejectsInvalidParametersNamingThemWithoutEchoingTheValue() {
        assertRejected(new TicketSearch(null, true), "p_usuario_id");
        assertRejected(new TicketSearch(requester, null), "p_ver_todos");
        assertRejected(mine().sort("NOME_SECRETO", "ASC"), "p_ordenar_por");
        assertRejected(mine().sort("CRIADO_EM", "LADO_SECRETO"), "p_direcao");
        assertRejected(mine().limit(0), "p_limite");
        assertRejected(mine().limit(201), "p_limite");
        assertRejected(mine().text("ab"), "p_texto");
        assertRejected(mine().text("x".repeat(201)), "p_texto");
        assertRejected(mine().createdBetween(W.plusMinutes(1), W), "p_criado_desde");
    }

    private void assertRejected(TicketSearch search, String parameter) {
        assertThatThrownBy(() -> plsql.search(search))
                .hasMessageContaining("ORA-20005")
                .hasMessageContaining(parameter)
                .satisfies(error -> assertThat(error.getMessage()).doesNotContain("SECRETO"));
    }

    @Test
    void returnsTheSummaryColumns() {
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA").priority("ALTA").assignedTo(agent)
                .createdAt(W).updatedAt(W.plusMinutes(3)).engineeringAlert(true).insert();

        Map<String, Object> row = plsql.search(mine()).getFirst();

        assertThat(((Number) row.get("id")).longValue()).isEqualTo(ticket);
        assertThat(row)
                .containsEntry("segment", "DEFEITO_APP")
                .containsEntry("segment_label", "Defeito no App / Problemas com App")
                .containsEntry("status", "EM_FILA")
                .containsEntry("priority", "ALTA")
                .containsEntry("sla_status", "NO_PRAZO")
                .containsEntry("requester_name", fx.nameOf(requester))
                .containsEntry("assignee_name", fx.nameOf(fx.userOf(agent)))
                .containsEntry("engineering_alert", true)
                .containsKeys("sla_due_at", "created_at", "updated_at");
    }
}
