/*
Nested Procedure Example
This demonstrates how a procedure can call another procedure defined inside it.
The outer procedure updates an employee's salary by a given percentage.

FIXES / OPTIMIZATIONS:
- validate_percentage now rejects NULL. "NULL <= 0" is not TRUE, so NULL used
  to pass validation and "salary + salary * NULL / 100" set the salary to NULL.
- Removed "WHEN OTHERS THEN PUT_LINE; ROLLBACK". It had two problems:
    * It swallowed the error, so the caller thought the update succeeded
      (Test Case 2 printed an error but finished "successfully").
    * A bare ROLLBACK inside a procedure undoes the CALLER's whole
      transaction, not just this procedure's work.
  A single UPDATE is atomic on its own: if it fails, Oracle undoes it.
- "Employee not found" is now raised with RAISE_APPLICATION_ERROR so the
  caller can react to it, instead of only seeing a printed message.
- The procedure does not COMMIT; the caller decides when the transaction ends.
*/

CREATE OR REPLACE PROCEDURE update_salary_nested (
    p_emp_id    IN employees.employee_id%TYPE,
    p_percent   IN NUMBER
)
IS
    -- Inner procedure to validate the salary percentage
    PROCEDURE validate_percentage(p IN NUMBER) IS
    BEGIN
        IF p IS NULL OR p <= 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Percentage must be a positive number.');
        END IF;
    END validate_percentage;

BEGIN
    -- Call inner procedure to validate the input (before touching the table)
    validate_percentage(p_percent);

    -- Update the employee's salary
    UPDATE employees
    SET salary = salary + (salary * p_percent / 100)
    WHERE employee_id = p_emp_id;

    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'No employee found with ID ' || p_emp_id);
    END IF;

    DBMS_OUTPUT.PUT_LINE('Salary updated for employee ID ' || p_emp_id);
END update_salary_nested;
/


-- Enable output
SET SERVEROUTPUT ON;

-- Test Case 1: Valid update
BEGIN
    update_salary_nested(101, 10);  -- Increase salary of employee_id 101 by 10%
END;
/

-- Test Case 2: Invalid percentage (negative)
-- Expected: ORA-20001 from the nested procedure. The handler below exists only
-- so the test prints the error instead of stopping the script.
BEGIN
    update_salary_nested(101, -5);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Expected error: ' || SQLERRM);
END;
/

-- Test Case 3: Non-existent employee
-- Expected: ORA-20002
BEGIN
    update_salary_nested(999, 5);   -- Employee 999 does not exist
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Expected error: ' || SQLERRM);
END;
/

-- Keep (COMMIT) or discard (ROLLBACK) the Test Case 1 raise yourself.
