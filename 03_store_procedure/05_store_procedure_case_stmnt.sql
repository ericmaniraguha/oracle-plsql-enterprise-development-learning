-- ========================================================
-- Example: Parameterized Procedure using CASE
-- Table: EMPLOYEES
--
-- OPTIMIZATIONS:
-- 1. The action is normalized ONCE (UPPER/TRIM into a local variable).
-- 2. An invalid action is rejected before any table access. The old code
--    queried the employee first and only then discovered the action was invalid.
-- 3. RAISE / LOWER use UPDATE ... RETURNING INTO. One statement both changes
--    the salary and returns the name and new salary. The old code needed a
--    SELECT followed by an UPDATE (two statements, two index lookups).
-- 4. No COMMIT inside the procedure (SHOW used to COMMIT for nothing).
--    The caller decides when the transaction ends.
-- 5. Removed TOO_MANY_ROWS (impossible for a primary-key lookup) and the
--    "WHEN OTHERS THEN PUT_LINE" handler that hid real errors.
-- ========================================================

CREATE OR REPLACE PROCEDURE manage_salary_case (
    p_emp_id  IN employees.employee_id%TYPE,
    p_action  IN VARCHAR2          -- Action: 'SHOW', 'RAISE', 'LOWER'
)
IS
    v_action     CONSTANT VARCHAR2(4000) := UPPER(TRIM(p_action));
    v_first_name employees.first_name%TYPE;
    v_last_name  employees.last_name%TYPE;
    v_salary     employees.salary%TYPE;
BEGIN
    -- Use CASE for action
    CASE v_action
        WHEN 'SHOW' THEN
            SELECT first_name, last_name, salary
            INTO v_first_name, v_last_name, v_salary
            FROM employees
            WHERE employee_id = p_emp_id;

            DBMS_OUTPUT.PUT_LINE('Employee: ' || v_first_name || ' ' || v_last_name ||
                                 ' - Salary: ' || v_salary);

        WHEN 'RAISE' THEN
            UPDATE employees
            SET salary = salary * 1.10
            WHERE employee_id = p_emp_id
            RETURNING first_name, last_name, salary
            INTO v_first_name, v_last_name, v_salary;

            -- UPDATE never raises NO_DATA_FOUND by itself; check the row count
            IF SQL%ROWCOUNT = 0 THEN
                RAISE NO_DATA_FOUND;
            END IF;

            DBMS_OUTPUT.PUT_LINE('Salary increased by 10% for ' || v_first_name || ' ' || v_last_name ||
                                 ' - New salary: ' || v_salary);

        WHEN 'LOWER' THEN
            UPDATE employees
            SET salary = salary * 0.90
            WHERE employee_id = p_emp_id
            RETURNING first_name, last_name, salary
            INTO v_first_name, v_last_name, v_salary;

            IF SQL%ROWCOUNT = 0 THEN
                RAISE NO_DATA_FOUND;
            END IF;

            DBMS_OUTPUT.PUT_LINE('Salary decreased by 10% for ' || v_first_name || ' ' || v_last_name ||
                                 ' - New salary: ' || v_salary);

        ELSE
            DBMS_OUTPUT.PUT_LINE('Invalid action! Use SHOW, RAISE, or LOWER.');
    END CASE;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Error: Employee ID ' || p_emp_id || ' not found.');
END manage_salary_case;
/
-- ========================================================

-- Example calls:
SET SERVEROUTPUT ON;

-- Show salary
BEGIN
    manage_salary_case(101, 'SHOW');
END;
/

-- Increase salary
BEGIN
    manage_salary_case(101, 'RAISE');
END;
/

-- Decrease salary
BEGIN
    manage_salary_case(101, 'LOWER');
END;
/

-- The procedure no longer commits. Run COMMIT to keep the changes,
-- or ROLLBACK to undo them.
