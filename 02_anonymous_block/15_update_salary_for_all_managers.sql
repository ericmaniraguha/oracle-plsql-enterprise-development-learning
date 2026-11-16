-- ========================================================
-- Exercise: Give every manager a 2% raise
-- ========================================================
-- Uses the function calculate_new_salary from
-- 04_plsql_functions/03_fun_calculate_new_salary.sql (create it first).
--
-- OPTIMIZED: one set-based UPDATE replaces the old row-by-row loop.
--   Old: 1 SELECT + 1 UPDATE per manager (N+1 statements, N context switches).
--   New: 1 UPDATE for all managers. RETURNING ... BULK COLLECT hands back the
--        updated IDs and salaries in the same round trip, so we can still
--        print what changed.
--
-- FIXED: "job_id = 'MANAGER'" matched no rows in the HR schema. A manager is
-- now any employee who has at least one direct report.
--
-- FIXED: on error the old block printed the message and swallowed it, so the
-- script reported success. Now it rolls back and re-raises.
-- ========================================================

SET SERVEROUTPUT ON;

DECLARE
    TYPE t_emp_ids  IS TABLE OF employees.employee_id%TYPE;
    TYPE t_salaries IS TABLE OF employees.salary%TYPE;

    l_emp_ids      t_emp_ids;
    l_new_salaries t_salaries;
BEGIN
    UPDATE employees e
       SET e.salary = calculate_new_salary(e.salary, 0.02)
     WHERE EXISTS (
               SELECT 1
               FROM employees r
               WHERE r.manager_id = e.employee_id
           )
    RETURNING e.employee_id, e.salary
    BULK COLLECT INTO l_emp_ids, l_new_salaries;

    FOR i IN 1 .. l_emp_ids.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE('Updated Employee ID ' || l_emp_ids(i) ||
                             ' to ' || l_new_salaries(i));
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Managers updated: ' || l_emp_ids.COUNT);

    -- Commit changes
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;  -- undo the whole raise, nothing half-done
        RAISE;     -- and make sure the caller sees the error
END;
/
