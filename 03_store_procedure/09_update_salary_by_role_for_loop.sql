SET SERVEROUTPUT ON;

-- ========================================================
-- Procedure: update_salary_by_role
-- Purpose: Update salaries for employees of a specific role
--          and display old vs new salaries
-- Parameters:
--   p_job_role  -> Job role to filter employees (e.g., 'IT_PROG', 'SA_REP')
--   p_increment -> Salary increment rate as a decimal (0.02 = 2%)
--
-- Uses calculate_new_salary from 04_plsql_functions/03_fun_calculate_new_salary.sql.
--
-- OPTIMIZED: BULK COLLECT + FORALL instead of one UPDATE per employee.
--   Old: 1 query + N single-row UPDATEs = N+1 SQL statements and 2N
--        switches between the PL/SQL and SQL engines.
--   New: 1 BULK COLLECT query + 1 FORALL (sent to SQL as ONE batch).
--   The rows are read with FOR UPDATE, so they are locked from the moment we
--   read the old salary until we write the new one.
--
-- FIXED: the procedure no longer COMMITs (the caller decides), and errors are
-- no longer swallowed. The old "WHEN OTHERS THEN PUT_LINE; ROLLBACK" also
-- rolled back the caller's earlier, unrelated work.
-- ========================================================

CREATE OR REPLACE PROCEDURE update_salary_by_role (
    p_job_role  IN employees.job_id%TYPE,
    p_increment IN NUMBER
)
IS
    TYPE t_emp_ids  IS TABLE OF employees.employee_id%TYPE;
    TYPE t_salaries IS TABLE OF employees.salary%TYPE;

    l_emp_ids      t_emp_ids;
    l_old_salaries t_salaries;
    l_new_salaries t_salaries := t_salaries();

    -- Summary totals
    v_total_old NUMBER := 0;
    v_total_new NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('--- Updating salaries for role: ' || p_job_role || ' ---');

    -- 1. Fetch every matching employee in ONE round trip (and lock the rows)
    SELECT employee_id, salary
    BULK COLLECT INTO l_emp_ids, l_old_salaries
    FROM employees
    WHERE job_id = p_job_role
    ORDER BY employee_id
    FOR UPDATE OF salary;

    -- 2. Calculate new salaries in PL/SQL memory (no SQL involved)
    l_new_salaries.EXTEND(l_emp_ids.COUNT);
    FOR i IN 1 .. l_emp_ids.COUNT LOOP
        l_new_salaries(i) := calculate_new_salary(l_old_salaries(i), p_increment);

        DBMS_OUTPUT.PUT_LINE('Employee ID: ' || l_emp_ids(i) ||
                             ' | Old Salary: ' || l_old_salaries(i) ||
                             ' | New Salary: ' || l_new_salaries(i));

        v_total_old := v_total_old + l_old_salaries(i);
        v_total_new := v_total_new + l_new_salaries(i);
    END LOOP;

    -- 3. Write all new salaries with ONE bulk-bound UPDATE
    FORALL i IN 1 .. l_emp_ids.COUNT
        UPDATE employees
        SET salary = l_new_salaries(i)
        WHERE employee_id = l_emp_ids(i);

    -- Display summary
    DBMS_OUTPUT.PUT_LINE('--- Summary ---');
    DBMS_OUTPUT.PUT_LINE('Total employees updated: ' || l_emp_ids.COUNT);
    DBMS_OUTPUT.PUT_LINE('Total of old salaries: ' || v_total_old);
    DBMS_OUTPUT.PUT_LINE('Total of new salaries: ' || v_total_new);
END update_salary_by_role;
/

-- Test procedure: the caller owns the transaction
BEGIN
    update_salary_by_role('IT_PROG', 0.02);
    update_salary_by_role('FI_MGR', 0.02);
    update_salary_by_role('SA_REP', 0.02);
    COMMIT;      -- all three roles succeed together...
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;  -- ...or none of them is applied
        RAISE;
END;
/
