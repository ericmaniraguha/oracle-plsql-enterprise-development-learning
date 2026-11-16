-- Procedure: update_employee_commission
-- Purpose: Update the commission percentage (bonus rate) of an employee safely
-- Inputs:
--   p_emp_id         -> Employee ID
--   p_commission_pct -> Commission rate, e.g. 0.15 = 15% (must be between 0 and 0.99)
-- Features:
--   1. Validates the commission rate BEFORE touching the table
--   2. Checks that the employee exists using SQL%ROWCOUNT (no extra query)
--   3. Raises clear errors instead of only printing messages
--   4. Leaves COMMIT / ROLLBACK to the caller
--
-- RENAMED from update_employee_bonus: 07_ems_savepoint_rollback.sql creates
-- a different procedure with that name (it updates a BONUS amount column).
-- Running both scripts made the second one silently replace the first.
-- This procedure updates COMMISSION_PCT, so the new name says what it does.
--
-- OPTIMIZATIONS:
--   - Old: SELECT COUNT(*) to check existence, then UPDATE = 2 statements.
--     New: UPDATE, then check SQL%ROWCOUNT = 1 statement. The UPDATE already
--     tells us whether the row existed.
--   - Input is validated first, so invalid calls never hit the database.


/*

1. Why is it important to ROLLBACK changes when an error occurs?
   Answer: To ensure the database remains consistent and no partial updates corrupt the data.

2. What happens if we remove the ROLLBACK from the procedure?
   Answer: Partial updates may remain, which can lead to inconsistent or invalid data.
   Note: a SINGLE DML statement is atomic. If this UPDATE fails, Oracle undoes it
   automatically. An explicit ROLLBACK matters when a procedure runs SEVERAL
   statements; use a SAVEPOINT so you undo only your own work (see
   08_store_procedure_rollback_savepoint.sql). A bare ROLLBACK inside a procedure
   would also undo the caller's earlier, unrelated changes.

3. How can we modify the procedure to log errors into a separate database table instead of just displaying messages?
   Answer:
      a) Create an error_log table with columns like error_date, employee_id, error_message.
      b) Write a logging procedure declared with PRAGMA AUTONOMOUS_TRANSACTION
         so the log row is committed even if the main transaction is rolled back.
      c) In the WHEN OTHERS block, call the logging procedure, then RAISE.
*/

CREATE OR REPLACE PROCEDURE update_employee_commission (
    p_emp_id         IN employees.employee_id%TYPE,
    p_commission_pct IN employees.commission_pct%TYPE
)
IS
BEGIN
    -- Validate input first: cheap, and no table access for bad input
    IF p_commission_pct IS NULL OR p_commission_pct < 0 OR p_commission_pct >= 1 THEN
        RAISE_APPLICATION_ERROR(-20001,
            'Commission must be between 0 and 0.99 (got ' || NVL(TO_CHAR(p_commission_pct), 'NULL') || ').');
    END IF;

    -- Update commission and use the implicit cursor to check existence
    UPDATE employees
    SET commission_pct = p_commission_pct
    WHERE employee_id = p_emp_id;

    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Employee ID ' || p_emp_id || ' does not exist.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('Success: Commission updated for Employee ID ' || p_emp_id || ' to ' || p_commission_pct);
END update_employee_commission;
/


SET SERVEROUTPUT ON;

-- Valid update (the caller decides to COMMIT)
BEGIN
    update_employee_commission(101, 0.15);
    COMMIT;
END;
/

-- Employee does not exist (expected: ORA-20002)
BEGIN
    update_employee_commission(999, 0.10);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Expected error: ' || SQLERRM);
END;
/

-- Invalid commission (expected: ORA-20001)
BEGIN
    update_employee_commission(101, -0.05);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Expected error: ' || SQLERRM);
END;
/
