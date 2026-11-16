-- ========================================================
-- Function: update_salary_func
-- Updates the salary of an employee and returns a status message
-- Includes:
--   - User-defined exception
--   - Savepoint and rollback
--   - Exception handling for VALUE_ERROR and others
--
-- DESIGN NOTE: a function that changes data cannot be called from a SELECT
-- (ORA-14551), only from PL/SQL. In real code, use a PROCEDURE for actions
-- and keep functions for calculations (see
-- 03_store_procedure/08_store_procedure_rollback_savepoint.sql for the
-- procedure version). This file keeps the function to show the pattern.
--
-- FIXED: Test 3 (NULL salary) did NOT fail. VALUE_ERROR is never raised for
-- NULL, and the CHECK constraint "salary > 0" lets NULL through, so the test
-- silently set employee 101's salary to NULL. The salary is now validated.
--
-- FIXED: unexpected errors were turned into a returned string. The caller
-- had no reliable way to detect the failure. Expected business errors still
-- return a status message; unexpected ones are rolled back and re-raised.
-- ========================================================

CREATE OR REPLACE FUNCTION update_salary_func (
    p_emp_id      IN employees.employee_id%TYPE,  -- Employee ID
    p_new_salary  IN employees.salary%TYPE       -- New salary
) RETURN VARCHAR2
IS
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
    IF SQL%ROWCOUNT = 0 THEN
        RAISE e_invalid_emp;
    END IF;

    RETURN 'Salary updated successfully for Employee ID ' || p_emp_id;

EXCEPTION
    -- Handle user-defined exceptions (expected business errors)
    WHEN e_invalid_emp THEN
        ROLLBACK TO before_salary_update;
        RETURN 'Error: Employee ID ' || p_emp_id || ' does not exist.';

    WHEN e_invalid_salary THEN
        ROLLBACK TO before_salary_update;
        RETURN 'Error: Salary must be a positive number.';

    -- Handle numeric or value errors (e.g. salary too large for NUMBER(8,2))
    WHEN VALUE_ERROR THEN
        ROLLBACK TO before_salary_update;
        RETURN 'Error: Invalid salary value provided.';

    -- Anything else is unexpected: undo our work and let the caller see it
    WHEN OTHERS THEN
        ROLLBACK TO before_salary_update;
        RAISE;

END update_salary_func;
/

--Test the function

SET SERVEROUTPUT ON;

DECLARE
    v_status VARCHAR2(200);
BEGIN
    -- Test 1: Valid Employee
    v_status := update_salary_func(101, 7500);
    DBMS_OUTPUT.PUT_LINE(v_status);

    -- Test 2: Invalid Employee
    v_status := update_salary_func(999, 6000);
    DBMS_OUTPUT.PUT_LINE(v_status);

    -- Test 3: Invalid Salary Value
    v_status := update_salary_func(101, NULL);
    DBMS_OUTPUT.PUT_LINE(v_status);
END;
/

-- Test 1's change is still uncommitted: COMMIT to keep it, ROLLBACK to undo it.
