package com.edu.api.employee.service;

import com.edu.api.employee.dto.EmployeeMeResponse;
import com.edu.api.employee.entity.Presence;
import com.edu.api.shared.exception.ForbiddenException;
import com.edu.api.support.FullStackIntegration;
import com.edu.api.support.TicketFixtures.TicketState;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class EmployeeServiceIT extends FullStackIntegration {

    @Autowired
    private EmployeeService employees;

    @Test
    void goingOnlineRoutesWaitingTickets() {
        long requester = fx.user("USER");
        long agent = fx.employee("OFFLINE", "DESENVOLVEDOR");
        long queued = fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA").insert();
        long escalated = fx.ticketFor(requester, "DEFEITO_APP").status("ESCALADO").priority("CRITICA").insert();

        employees.changePresence(login(fx.userOf(agent), "EMPLOYEE"), Presence.ONLINE);

        assertThat(fx.state(queued)).isEqualTo(new TicketState("EM_FILA", "NORMAL", agent));
        assertThat(fx.state(escalated)).isEqualTo(new TicketState("ESCALADO", "CRITICA", agent));
    }

    @Test
    void goingOfflineHandsUnassumedTicketsToSomeoneElse() {
        long requester = fx.user("USER");
        long leaving = fx.employee("ONLINE", "DESENVOLVEDOR");
        long staying = fx.employee("ONLINE", "DESENVOLVEDOR");
        long waiting = fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA").assignedTo(leaving).insert();
        long inService = fx.ticketFor(requester, "DEFEITO_APP").status("EM_ATENDIMENTO").assignedTo(leaving).insert();

        employees.changePresence(login(fx.userOf(leaving), "EMPLOYEE"), Presence.OFFLINE);

        assertThat(fx.state(waiting).assignedEmployeeId()).isEqualTo(staying);
        assertThat(fx.state(inService).assignedEmployeeId()).isEqualTo(leaving);
    }

    @Test
    void showsPresenceAndSkills() {
        long agent = fx.employee("AUSENTE", "DESENVOLVEDOR", "PRODUTO_MELHORIAS");

        EmployeeMeResponse me = employees.me(login(fx.userOf(agent), "EMPLOYEE"));

        assertThat(me.id()).isEqualTo(agent);
        assertThat(me.presence()).isEqualTo(Presence.AUSENTE);
        assertThat(me.skills()).containsExactly("DESENVOLVEDOR", "PRODUTO_MELHORIAS");
    }

    @Test
    void staffWithoutAnAgentProfileIsForbidden() {
        long userWithoutProfile = fx.user("EMPLOYEE");

        assertThatThrownBy(() -> employees.me(login(userWithoutProfile, "EMPLOYEE")))
                .isInstanceOf(ForbiddenException.class);
    }
}
