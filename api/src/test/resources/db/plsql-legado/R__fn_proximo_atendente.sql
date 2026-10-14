-- Escolhe o próximo atendente de uma skill: ONLINE, com menos tickets ativos
-- e, no empate, o que está há mais tempo sem receber ticket. Nunca escolhe
-- p_excluir_id nem o cadastro de atendente de quem abriu o ticket
-- (p_solicitante_id é um admin_users.id, comparado com employees.user_id).
CREATE OR REPLACE FUNCTION FN_PROXIMO_ATENDENTE (
    p_skill_id       IN skills.id%TYPE,
    p_excluir_id     IN employees.id%TYPE DEFAULT NULL,
    p_solicitante_id IN admin_users.id%TYPE DEFAULT NULL
) RETURN employees.id%TYPE
IS
    CURSOR c_candidatos IS
        SELECT e.id
          FROM employees e
          JOIN employee_skills es ON es.employee_id = e.id
         WHERE es.skill_id = p_skill_id
           AND e.presence = 'ONLINE'
           AND (p_excluir_id IS NULL OR e.id <> p_excluir_id)
           AND (p_solicitante_id IS NULL OR e.user_id <> p_solicitante_id)
         ORDER BY (SELECT COUNT(*)
                     FROM tickets t
                    WHERE t.assigned_employee_id = e.id
                      AND t.status IN ('EM_FILA', 'EM_ATENDIMENTO', 'ESCALADO')),
                  e.last_assigned_at NULLS FIRST,
                  e.id;

    v_employee_id employees.id%TYPE;
BEGIN
    OPEN c_candidatos;
    FETCH c_candidatos INTO v_employee_id;
    CLOSE c_candidatos;

    RETURN v_employee_id;
END FN_PROXIMO_ATENDENTE;
/
