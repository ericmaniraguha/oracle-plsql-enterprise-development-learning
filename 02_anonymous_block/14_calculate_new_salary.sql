-- ========================================================
-- Exercise: Calculate (preview) new salaries for all managers
-- ========================================================
-- Uses the function calculate_new_salary from
-- 04_plsql_functions/03_fun_calculate_new_salary.sql (create it first).
--
-- This block only CALCULATES and prints the new salaries. It does not change
-- any data. 15_update_salary_for_all_managers.sql applies the raise.
--
-- FIXED: the old filter "job_id = 'MANAGER'" matched no rows, because HR job
-- IDs look like 'SA_MAN', 'FI_MGR', 'ST_MAN'. A manager is now defined as
-- any employee who has at least one direct report. EXISTS stops at the first
-- report it finds and uses the emp_manager_ix index.
-- ========================================================

SET SERVEROUTPUT ON;

BEGIN
    FOR rec IN (
        SELECT m.employee_id,
               m.first_name || ' ' || m.last_name AS manager_name,
               m.salary
        FROM employees m
        WHERE EXISTS (
            SELECT 1
            FROM employees r
            WHERE r.manager_id = m.employee_id
        )
        ORDER BY m.employee_id
    )
    LOOP
        DBMS_OUTPUT.PUT_LINE('Employee ID ' || rec.employee_id ||
                             ' (' || rec.manager_name || ')' ||
                             ': current ' || rec.salary ||
                             ', after 2% raise ' || calculate_new_salary(rec.salary, 0.02));
    END LOOP;
END;
/
