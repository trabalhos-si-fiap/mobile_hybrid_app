package com.edu.api.employee.entity;

import com.edu.api.user.entity.AdminUser;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.HashSet;
import java.util.Set;

@Getter
@Entity
@Table(name = "employees")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Employee {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private AdminUser user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private Presence presence = Presence.OFFLINE;

    @Column(name = "presence_changed_at", nullable = false)
    private Instant presenceChangedAt;

    @Column(name = "last_assigned_at")
    private Instant lastAssignedAt;

    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
            name = "employee_skills",
            joinColumns = @JoinColumn(name = "employee_id"),
            inverseJoinColumns = @JoinColumn(name = "skill_id")
    )
    private Set<Skill> skills = new HashSet<>();

    public Employee(AdminUser user, Instant now) {
        this.user = user;
        this.presenceChangedAt = now;
    }

    public void addSkill(Skill skill) {
        skills.add(skill);
    }

    public void changePresence(Presence presence, Instant now) {
        this.presence = presence;
        this.presenceChangedAt = now;
    }

    /** Compara pelo id; funciona também com proxies do Hibernate. */
    public boolean sameAs(Employee other) {
        return other != null && id != null && id.equals(other.getId());
    }
}
