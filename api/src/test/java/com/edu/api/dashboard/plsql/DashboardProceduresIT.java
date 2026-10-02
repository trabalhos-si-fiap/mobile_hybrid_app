package com.edu.api.dashboard.plsql;

import com.edu.api.dashboard.plsql.DashboardSummaryRows.AnomalyLine;
import com.edu.api.dashboard.plsql.DashboardSummaryRows.Kpi;
import com.edu.api.dashboard.plsql.DashboardSummaryRows.SegmentLine;
import com.edu.api.support.DashboardFixtures;
import com.edu.api.support.OracleIntegrationTest;
import com.edu.api.ticket.entity.Segment;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jdbc.test.autoconfigure.JdbcTest;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.time.Instant;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** A PR_RESUMO_DASHBOARD pelo gateway: os três cursores viram records, nulos inclusos. */
@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
@Import(DashboardProcedures.class)
class DashboardProceduresIT extends OracleIntegrationTest {

    private static final Instant REF = DashboardFixtures.REF.toInstant();

    @Autowired
    private JdbcTemplate jdbc;

    @Autowired
    private DashboardProcedures procedures;

    @Test
    void readsTheThreeCursorsIntoRows() {
        new DashboardFixtures(jdbc).ticket("PROBLEMA_PEDIDO", DashboardFixtures.REF.minusHours(1)).insert();

        DashboardSummaryRows rows = procedures.summary(7, REF);

        assertThat(rows.kpis()).extracting(Kpi::metric).containsExactly(
                "ABERTOS", "RESOLVIDOS", "BACKLOG", "SLA_CUMPRIDO_PCT", "ESCALADOS",
                "TEMPO_MEDIO_ASSUMIR_MIN", "TEMPO_MEDIO_RESOLUCAO_H", "ABERTOS_APP", "ABERTOS_CHATBOT");
        Kpi opened = rows.kpis().get(0);
        assertThat(opened.current()).isEqualByComparingTo("1");
        assertThat(opened.previous()).isEqualByComparingTo("0");
        assertThat(opened.variation()).isNull();
        assertThat(rows.kpis().get(2).current()).isEqualByComparingTo("1");

        assertThat(rows.segments()).extracting(SegmentLine::segment)
                .containsExactly(Segment.DEFEITO_APP, Segment.PROBLEMA_PEDIDO, Segment.FEEDBACK_SUGESTAO);
        SegmentLine order = rows.segments().get(1);
        assertThat(order.label()).isEqualTo("Problemas com pedido");
        assertThat(order.opened()).isEqualByComparingTo("1");
        assertThat(order.slaPct()).isNull();
        assertThat(order.backlog()).isEqualTo(1);

        assertThat(rows.anomalies()).extracting(AnomalyLine::segment)
                .containsExactly(Segment.DEFEITO_APP, Segment.PROBLEMA_PEDIDO, Segment.FEEDBACK_SUGESTAO);
        AnomalyLine anomaly = rows.anomalies().get(1);
        assertThat(anomaly.current()).isEqualTo(1);
        assertThat(anomaly.mean()).isNull();
        assertThat(anomaly.deviation()).isNull();
        assertThat(anomaly.zScore()).isNull();
        assertThat(anomaly.situation()).isEqualTo("SEM_HISTORICO");
        assertThat(anomaly.windows()).isZero();
    }

    @Test
    void letsTheOracleErrorThrough() {
        assertThatThrownBy(() -> procedures.summary(15, REF))
                .isInstanceOf(DataAccessException.class)
                .hasMessageContaining("ORA-20004");
    }
}
