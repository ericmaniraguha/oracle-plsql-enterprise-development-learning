
-- ========================================================
-- Function: calculate_new_salary
-- Purpose: Calculate new salary with a given increment rate
--
-- Used by: 02_anonymous_block/14_calculate_new_salary.sql,
--          02_anonymous_block/15_update_salary_for_all_managers.sql,
--          03_store_procedure/09_update_salary_by_role_for_loop.sql
--
-- FIXED (important): on bad input the old version printed a message and
-- RETURNED NULL. Callers use it inside UPDATE statements, e.g.
--     UPDATE employees SET salary = calculate_new_salary(salary, 0.02) ...
-- so a bad value would have silently written NULL salaries. A function must
-- not hide errors from its caller: it now raises ORA-20010 instead, and the
-- whole UPDATE fails cleanly.
--
-- Also:
-- - The NULL increment rate is now rejected (it also produced NULL).
-- - DETERMINISTIC: same inputs always give the same result, so Oracle may
--   cache results when the function is called from SQL.
-- - "RAISE VALUE_ERROR" + catching it in the same function was just a
--   roundabout GOTO; RAISE_APPLICATION_ERROR states the problem directly.
-- ========================================================

CREATE OR REPLACE FUNCTION calculate_new_salary (
    p_salary         IN NUMBER,
    p_increment_rate IN NUMBER
) RETURN NUMBER
DETERMINISTIC
IS
BEGIN
    -- Check valid input
    IF p_salary IS NULL OR p_salary < 0 THEN
        RAISE_APPLICATION_ERROR(-20010,
            'Invalid salary (' || NVL(TO_CHAR(p_salary), 'NULL') || ').');
    END IF;

    IF p_increment_rate IS NULL THEN
        RAISE_APPLICATION_ERROR(-20011, 'Increment rate cannot be NULL.');
    END IF;

    -- Return salary with increment, rounded to cents like the salary column
    RETURN ROUND(p_salary * (1 + p_increment_rate), 2);
END calculate_new_salary;
/


SET SERVEROUTPUT ON;

-- ========================================================
-- Test Block for Function: calculate_new_salary
-- Purpose: Test the function with valid and invalid inputs
--
-- A small local procedure runs each test and reports the outcome, so an
-- expected error in one test does not stop the remaining tests.
-- ========================================================

DECLARE
    PROCEDURE run_test(p_label VARCHAR2, p_salary NUMBER, p_rate NUMBER) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE(p_label || ' - New salary: ' || calculate_new_salary(p_salary, p_rate));
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE(p_label || ' - Rejected: ' || SQLERRM);
    END run_test;
BEGIN
    run_test('Test 1 (5000, +2%)',      5000,  0.02);   -- 5100
    run_test('Test 2 (7500, +10%)',     7500,  0.10);   -- 8250
    run_test('Test 3 (negative salary)', -1000, 0.05);  -- rejected: ORA-20010
    run_test('Test 4 (NULL salary)',    NULL,  0.05);   -- rejected: ORA-20010
END;
/
