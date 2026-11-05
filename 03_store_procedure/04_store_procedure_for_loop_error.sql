-- =============================================
-- Procedure: show_first_employee_in_dept
-- Purpose  : Show the first employee's first name in a given department
-- Note     : This version uses SELECT INTO, which can only handle
--            one row at a time. Without the row-limiting clause, a
--            department with several employees throws
--            ORA-01422 (exact fetch returns more than one row).
--
-- RENAMED from list_employees_by_department: 04_store_procedure_for_loop.sql
-- uses that name, so running this file silently replaced that procedure.
--
-- IMPROVED: "AND ROWNUM = 1" returned an ARBITRARY employee, because there is
-- no ORDER BY. "ORDER BY ... FETCH FIRST 1 ROW ONLY" (Oracle 12c+) returns
-- a predictable "first" employee every time.
-- =============================================

CREATE OR REPLACE PROCEDURE show_first_employee_in_dept (
    p_dept_id IN employees.department_id%TYPE  -- input parameter: department id
)
IS
    v_emp_name employees.first_name%TYPE;     -- variable to hold first_name
BEGIN
    -- SELECT INTO fetches a single value
    -- If multiple employees exist for the department without the
    -- FETCH FIRST clause, it will fail with TOO_MANY_ROWS
    SELECT first_name
    INTO v_emp_name
    FROM employees
    WHERE department_id = p_dept_id
    ORDER BY employee_id
    FETCH FIRST 1 ROW ONLY;  -- limits the result to 1 row to prevent the error

    DBMS_OUTPUT.PUT_LINE('First employee: ' || v_emp_name);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No employees found in this department.');
    WHEN TOO_MANY_ROWS THEN
        -- This will not occur here because of FETCH FIRST 1 ROW ONLY
        DBMS_OUTPUT.PUT_LINE('Error: More than one employee found.');
END;
/

-- Enable output so you can see DBMS_OUTPUT
SET SERVEROUTPUT ON;

-- Call the procedure for department 10 (example)
BEGIN
    show_first_employee_in_dept(10);
END;
/
