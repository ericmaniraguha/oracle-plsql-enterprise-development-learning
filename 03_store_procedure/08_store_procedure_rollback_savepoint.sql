-- Procedure: Update salary for an employee with exception handling
--
-- FIXED: Test 3 ("invalid salary NULL") did NOT fail. VALUE_ERROR is never
-- raised for NULL, and the CHECK constraint "salary > 0" lets NULL through
-- (NULL > 0 is UNKNOWN, not FALSE). The test silently set employee 101's
-- salary to NULL. The procedure now validates the salary itself.
--
-- FIXED: every handler printed the error and returned normally, so the
-- caller could not tell the update failed. Handlers now roll back to the
-- savepoint (undoing only this procedure's work) and re-raise.
CREATE OR REPLACE PROCEDURE update_salary (
    p_emp_id      IN  employees.employee_id%TYPE,  -- Employee ID
    p_new_salary  IN  employees.salary%TYPE        -- New salary
) IS
    ---------------------------------------------------------------------
    -- User-defined exceptions
    ---------------------------------------------------------------------
    e_invalid_emp    EXCEPTION;
    e_invalid_salary EXCEPTION;
BEGIN
    -- Savepoint before update
    SAVEPOINT before_salary_update;

    -- Validate before touching the table
    IF p_new_salary IS NULL OR p_new_salary <= 0 THEN
        RAISE e_invalid_salary;
    END IF;

    -- Attempt to update salary
    UPDATE employees
    SET salary = p_new_salary
    WHERE employee_id = p_emp_id;

    -- Raise user-defined exception if no rows were updated
    -- (read SQL%ROWCOUNT right after the DML, before any other SQL runs)
    IF SQL%ROWCOUNT = 0 THEN
        RAISE e_invalid_emp;
    END IF;

    DBMS_OUTPUT.PUT_LINE('Salary updated successfully for Employee ID ' || p_emp_id);

EXCEPTION
    -- Handle user-defined exceptions: turn them into clear, catchable errors
    WHEN e_invalid_emp THEN
        ROLLBACK TO before_salary_update;  -- Rollback to savepoint
        RAISE_APPLICATION_ERROR(-20002, 'Employee ID ' || p_emp_id || ' does not exist.');

    WHEN e_invalid_salary THEN
        ROLLBACK TO before_salary_update;
        RAISE_APPLICATION_ERROR(-20003, 'Salary must be a positive number.');

    -- Handle any other unexpected errors: undo our work, keep the original error
    WHEN OTHERS THEN
        ROLLBACK TO before_salary_update;
        RAISE;
END;
/



-- ========================================================
-- Test Block for update_salary Procedure
-- Demonstrates:
--   1. Valid update
--   2. Invalid employee ID
--   3. Invalid salary value
-- Each test is its own block so one failing test does not stop the others.
-- ========================================================

SET SERVEROUTPUT ON;

BEGIN
    DBMS_OUTPUT.PUT_LINE('--- Test 1: Valid Employee ---');
    update_salary(p_emp_id => 101, p_new_salary => 7500);
END;
/

BEGIN
    DBMS_OUTPUT.PUT_LINE('--- Test 2: Invalid Employee (expected ORA-20002) ---');
    update_salary(p_emp_id => 999, p_new_salary => 6000);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Expected error: ' || SQLERRM);
END;
/

BEGIN
    DBMS_OUTPUT.PUT_LINE('--- Test 3: Invalid Salary Value (expected ORA-20003) ---');
    update_salary(p_emp_id => 101, p_new_salary => NULL);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Expected error: ' || SQLERRM);
END;
/

-- Test 1's change is still uncommitted: COMMIT to keep it, ROLLBACK to undo it.
