-- ========================================================
-- Example: Parameterized Procedure with IF, CASE, and Exception Handling
-- Table: EMPLOYEES
--
-- OPTIMIZATIONS (same ideas as 05_store_procedure_case_stmnt.sql):
-- 1. UPPER(p_action) was evaluated up to three times; now it is computed once.
-- 2. Invalid actions are rejected before any table access.
-- 3. RAISE / LOWER use UPDATE ... RETURNING INTO: one statement instead of
--    SELECT + UPDATE.
-- 4. No COMMIT inside the procedure; the caller controls the transaction.
-- 5. Removed the impossible TOO_MANY_ROWS handler (primary-key lookup) and
--    the "WHEN OTHERS THEN PUT_LINE" handler that hid real errors.
-- ========================================================

CREATE OR REPLACE PROCEDURE manage_employee_salary (
    p_emp_id    IN employees.employee_id%TYPE,   -- Employee ID input
    p_action    IN VARCHAR2                       -- Action type: 'SHOW', 'RAISE', 'LOWER'
)
IS
    v_action     CONSTANT VARCHAR2(4000) := UPPER(TRIM(p_action));
    v_factor     NUMBER;
    v_first_name employees.first_name%TYPE;
    v_last_name  employees.last_name%TYPE;
    v_salary     employees.salary%TYPE;
BEGIN
    -- Determine action using IF
    IF v_action = 'SHOW' THEN
        SELECT first_name, last_name, salary
        INTO v_first_name, v_last_name, v_salary
        FROM employees
        WHERE employee_id = p_emp_id;

        DBMS_OUTPUT.PUT_LINE('Employee: ' || v_first_name || ' ' || v_last_name ||
                             ' - Salary: ' || v_salary);

    ELSIF v_action IN ('RAISE', 'LOWER') THEN
        IF v_action = 'RAISE' THEN
            v_factor := 1.10;
        ELSE
            v_factor := 0.90;
        END IF;

        -- One UPDATE serves both actions
        UPDATE employees
        SET salary = salary * v_factor
        WHERE employee_id = p_emp_id
        RETURNING first_name, last_name, salary
        INTO v_first_name, v_last_name, v_salary;

        -- UPDATE never raises NO_DATA_FOUND by itself; check the row count
        IF SQL%ROWCOUNT = 0 THEN
            RAISE NO_DATA_FOUND;
        END IF;

        IF v_action = 'RAISE' THEN
            DBMS_OUTPUT.PUT_LINE('Salary increased by 10% for ' || v_first_name || ' ' || v_last_name ||
                                 ' - New salary: ' || v_salary);
        ELSE
            DBMS_OUTPUT.PUT_LINE('Salary decreased by 10% for ' || v_first_name || ' ' || v_last_name ||
                                 ' - New salary: ' || v_salary);
        END IF;

    ELSE
        DBMS_OUTPUT.PUT_LINE('Invalid action! Use SHOW, RAISE, or LOWER.');
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Error: Employee ID ' || p_emp_id || ' not found.');
END manage_employee_salary;
/
-- ========================================================

-- Example calls:
SET SERVEROUTPUT ON;

-- Display salary
BEGIN
    manage_employee_salary(101, 'SHOW');
END;
/

-- Increase salary
BEGIN
    manage_employee_salary(101, 'RAISE');
END;
/

-- Decrease salary
BEGIN
    manage_employee_salary(101, 'LOWER');
END;
/

-- The procedure no longer commits. Run COMMIT to keep the changes,
-- or ROLLBACK to undo them.
