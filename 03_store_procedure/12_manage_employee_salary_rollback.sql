
    /*
Question:
Write a PL/SQL stored procedure named manage_employee_salary_rollback that:
- Accepts employee ID and an action (SHOW, RAISE, LOWER)
- Displays employee salary if action is SHOW
- Increases salary by 10% if action is RAISE
- Decreases salary by 10% if action is LOWER
- Uses SAVEPOINT and ROLLBACK to handle errors
- Prevents invalid actions from committing changes

OPTIMIZATIONS / FIXES:
- The action is validated FIRST. An invalid action no longer costs a query,
  and there is nothing to roll back.
- RAISE / LOWER use one "UPDATE ... RETURNING INTO" instead of SELECT + UPDATE.
- SHOW no longer issues a pointless COMMIT.
- Removed the impossible TOO_MANY_ROWS handler (primary-key lookup).
- Unexpected errors are rolled back to the savepoint and RE-RAISED instead of
  being printed and swallowed.
*/

CREATE OR REPLACE PROCEDURE manage_employee_salary_rollback (
    p_emp_id    IN employees.employee_id%TYPE,
    p_action    IN VARCHAR2
)
IS
    v_action     CONSTANT VARCHAR2(4000) := UPPER(TRIM(p_action));
    v_factor     NUMBER;
    v_first_name employees.first_name%TYPE;
    v_last_name  employees.last_name%TYPE;
    v_salary     employees.salary%TYPE;
BEGIN
    -- Set the savepoint FIRST, so the WHEN OTHERS handler can always
    -- roll back to it (a savepoint that was never set raises ORA-01086).
    SAVEPOINT before_update;

    -- Reject invalid actions before doing any work
    IF v_action IS NULL OR v_action NOT IN ('SHOW', 'RAISE', 'LOWER') THEN
        DBMS_OUTPUT.PUT_LINE('Invalid action! Use SHOW, RAISE, or LOWER.');
        RETURN;
    END IF;

    -- SHOW only reads data: no savepoint or commit needed
    IF v_action = 'SHOW' THEN
        SELECT first_name, last_name, salary
        INTO v_first_name, v_last_name, v_salary
        FROM employees
        WHERE employee_id = p_emp_id;

        DBMS_OUTPUT.PUT_LINE('Employee: ' || v_first_name || ' ' || v_last_name ||
                             ' - Salary: ' || v_salary);
        RETURN;
    END IF;

    v_factor := CASE v_action WHEN 'RAISE' THEN 1.10 ELSE 0.90 END;

    UPDATE employees
    SET salary = salary * v_factor
    WHERE employee_id = p_emp_id
    RETURNING first_name, last_name, salary
    INTO v_first_name, v_last_name, v_salary;

    -- UPDATE does not raise NO_DATA_FOUND by itself
    IF SQL%ROWCOUNT = 0 THEN
        RAISE NO_DATA_FOUND;
    END IF;

    DBMS_OUTPUT.PUT_LINE(
        CASE v_action WHEN 'RAISE' THEN 'Salary increased' ELSE 'Salary decreased' END ||
        ' by 10% for ' || v_first_name || ' ' || v_last_name ||
        ' - New salary: ' || v_salary);

    -- Commit only if successful (this lesson demonstrates in-procedure
    -- transaction control; in real applications the caller usually commits)
    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- No row was found, so nothing was changed and nothing needs undoing.
        DBMS_OUTPUT.PUT_LINE('Error: Employee ID ' || p_emp_id || ' not found.');

    WHEN OTHERS THEN
        ROLLBACK TO before_update;   -- undo only this procedure's change
        RAISE;                       -- and report the real error
END manage_employee_salary_rollback;
/

-- Example calls
SET SERVEROUTPUT ON;

BEGIN
    manage_employee_salary_rollback(101, 'SHOW');
    manage_employee_salary_rollback(101, 'RAISE');
    manage_employee_salary_rollback(101, 'promote');  -- invalid: nothing changes
    manage_employee_salary_rollback(999, 'LOWER');    -- employee not found
END;
/
