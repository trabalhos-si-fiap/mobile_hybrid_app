package com.edu.api.employee.repository;

import com.edu.api.employee.entity.Employee;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface EmployeeRepository extends JpaRepository<Employee, Long> {

    @Query("select distinct e from Employee e join fetch e.user left join fetch e.skills where e.user.id = :userId")
    Optional<Employee> findByUserId(@Param("userId") Long userId);

    @Query("select distinct e from Employee e join fetch e.user join e.skills s where s.code = :code")
    List<Employee> findBySkillCode(@Param("code") String code);
}
