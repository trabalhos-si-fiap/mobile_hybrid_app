package com.edu.api.ticket;

import com.edu.api.employee.entity.Employee;
import com.edu.api.employee.entity.Presence;
import com.edu.api.employee.entity.Skill;
import com.edu.api.notification.entity.Notification;
import com.edu.api.notification.entity.NotificationType;
import com.edu.api.support.OracleIntegrationTest;
import com.edu.api.ticket.entity.*;
import com.edu.api.user.entity.AdminUser;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jpa.test.autoconfigure.TestEntityManager;
import org.springframework.test.context.ActiveProfiles;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class TicketMappingIT extends OracleIntegrationTest {

    private static final Instant NOW = Instant.parse("2030-01-01T12:00:00Z");

    @Autowired
    private TestEntityManager em;

    private Skill skill(String code) {
        return em.getEntityManager()
                .createQuery("select s from Skill s where s.code = :code", Skill.class)
                .setParameter("code", code)
                .getSingleResult();
    }

    private AdminUser user(String role) {
        return em.persist(new AdminUser("Pessoa " + role, UUID.randomUUID() + "@teste.edu", "x", role));
    }

    @Test
    void persistsATicketWithItsConversationAndTrail() {
        AdminUser requester = user("USER");
        AdminUser agentUser = user("EMPLOYEE");
        Employee agent = new Employee(agentUser, NOW);
        agent.addSkill(skill("DESENVOLVEDOR"));
        em.persist(agent);

        Ticket ticket = em.persist(Ticket.open(requester, Segment.DEFEITO_APP, "App fecha ao abrir o carrinho", TicketChannel.APP, NOW));
        TicketMessage message = em.persist(new TicketMessage(ticket, SenderType.USER, requester, "Segue o print", NOW));
        em.persist(new TicketAttachment(ticket, message, "tickets/" + ticket.getId() + "/" + UUID.randomUUID(),
                "print.png", "image/png", 1234, requester, NOW));
        em.persist(new TicketEvent(ticket, TicketEventType.ABERTO, null, TicketStatus.ABERTO, null, null, NOW));
        em.persist(new Notification(agentUser, ticket.getId(), NotificationType.TICKET_ATRIBUIDO, "Novo ticket", "Atribuído a você", NOW));
        em.flush();
        em.clear();

        Ticket found = em.find(Ticket.class, ticket.getId());
        assertThat(found.getStatus()).isEqualTo(TicketStatus.ABERTO);
        assertThat(found.getPriority()).isEqualTo(TicketPriority.NORMAL);
        assertThat(found.getSegment()).isEqualTo(Segment.DEFEITO_APP);
        assertThat(found.getChannel()).isEqualTo(TicketChannel.APP);
        assertThat(found.isEngineeringAlert()).isFalse();
        assertThat(found.getRequester().getId()).isEqualTo(requester.getId());
        Long messages = em.getEntityManager()
                .createQuery("select count(m) from TicketMessage m where m.ticket.id = :id", Long.class)
                .setParameter("id", ticket.getId())
                .getSingleResult();
        assertThat(messages).isEqualTo(1);
    }

    @Test
    void loadsEmployeeSkillsAndPresence() {
        Employee agent = new Employee(user("EMPLOYEE"), NOW);
        agent.addSkill(skill("DESENVOLVEDOR"));
        agent.addSkill(skill("PRODUTO_MELHORIAS"));
        em.persist(agent);
        em.flush();
        em.clear();

        Employee found = em.find(Employee.class, agent.getId());

        assertThat(found.getPresence()).isEqualTo(Presence.OFFLINE);
        assertThat(found.getSkills()).extracting(Skill::getCode)
                .containsExactlyInAnyOrder("DESENVOLVEDOR", "PRODUTO_MELHORIAS");
    }

    @Test
    void readsTheTriageMatrix() {
        TicketTypeConfig config = em.find(TicketTypeConfig.class, "DEFEITO_APP");

        assertThat(config.getSegment()).isEqualTo(Segment.DEFEITO_APP);
        assertThat(config.getQueue()).isEqualTo(TicketQueue.TECNOLOGIA);
        assertThat(config.getDefaultPriority()).isEqualTo(TicketPriority.ALTA);
        assertThat(config.getSkill().getCode()).isEqualTo("DESENVOLVEDOR");
        assertThat(config.isActive()).isTrue();
    }
}
