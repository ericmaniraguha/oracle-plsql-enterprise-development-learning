-- ========================================================
-- Procedure: list_employees_by_department
-- Purpose  : List employees for a given department using a FOR loop
-- Parameter: p_dept_id (Department ID)
--
-- FIXED: a cursor FOR loop NEVER raises NO_DATA_FOUND. When the query
-- returns no rows the loop body simply does not run, so the old
-- "WHEN NO_DATA_FOUND" message was never printed. We now count the rows
-- and print the message when the count is zero.
-- Also removed "WHEN OTHERS THEN PUT_LINE", which hid real errors.
-- ========================================================

CREATE OR REPLACE PROCEDURE list_employees_by_department (
    p_dept_id IN employees.department_id%TYPE
)
IS
    v_rows PLS_INTEGER := 0;   -- PLS_INTEGER: fastest integer type for counters
BEGIN
    -- Loop through all employees in the given department
    -- (the WHERE clause uses the emp_department_ix index)
    FOR emp_rec IN (
        SELECT employee_id, first_name, last_name, salary
        FROM employees
        WHERE department_id = p_dept_id
        ORDER BY last_name, first_name
    )
    LOOP
        v_rows := v_rows + 1;

        -- Display employee info
        DBMS_OUTPUT.PUT_LINE(
            'Employee ID: ' || emp_rec.employee_id ||
            ' | Name: ' || emp_rec.first_name || ' ' || emp_rec.last_name ||
            ' | Salary: ' || emp_rec.salary
        );
    END LOOP;

    IF v_rows = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No employees found for department ID ' || p_dept_id);
    END IF;
END list_employees_by_department;
/
-- ========================================================

-- Example call:
SET SERVEROUTPUT ON;

BEGIN
    -- Replace 10 with the department_id you want to query
    list_employees_by_department(10);
END;
/
