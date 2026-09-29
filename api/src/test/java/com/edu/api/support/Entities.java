package com.edu.api.support;

import com.edu.api.employee.entity.Employee;
import com.edu.api.employee.entity.Skill;
import com.edu.api.ticket.entity.Segment;
import com.edu.api.ticket.entity.Ticket;
import com.edu.api.ticket.entity.TicketChannel;
import com.edu.api.ticket.entity.TicketStatus;
import com.edu.api.user.entity.AdminUser;
import org.springframework.beans.BeanUtils;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Instant;

/** Entidades com id preenchido, para testes unitários sem banco. */
public final class Entities {

    private Entities() {
    }

    public static AdminUser user(long id, String role) {
        AdminUser user = new AdminUser("Pessoa " + id, "p" + id + "@teste.edu", "x", role);
        ReflectionTestUtils.setField(user, "id", id);
        return user;
    }

    public static Skill skill(long id, String code) {
        Skill skill = BeanUtils.instantiateClass(Skill.class);
        ReflectionTestUtils.setField(skill, "id", id);
        ReflectionTestUtils.setField(skill, "code", code);
        ReflectionTestUtils.setField(skill, "name", code);
        return skill;
    }

    public static Employee employee(long id, AdminUser user, Skill... skills) {
        Employee employee = new Employee(user, Instant.EPOCH);
        ReflectionTestUtils.setField(employee, "id", id);
        for (Skill skill : skills) {
            employee.addSkill(skill);
        }
        return employee;
    }

    public static Ticket ticket(long id, AdminUser requester, Segment segment) {
        Ticket ticket = Ticket.open(requester, segment, "Descrição", TicketChannel.APP, Instant.EPOCH);
        ReflectionTestUtils.setField(ticket, "id", id);
        return ticket;
    }

    /** Coloca o ticket num estado qualquer, com ou sem dono. */
    public static Ticket in(Ticket ticket, TicketStatus status, Employee owner) {
        ReflectionTestUtils.setField(ticket, "status", status);
        ReflectionTestUtils.setField(ticket, "assignedEmployee", owner);
        return ticket;
    }
}
