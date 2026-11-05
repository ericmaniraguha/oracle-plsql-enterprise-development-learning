/*
PL/SQL function that calculates annual salaries for all employees in a given
department and returns a result set with full name, monthly salary, and
annual salary.

PL/SQL Function Creation
*/

-- Step 1: Create the function
CREATE OR REPLACE FUNCTION get_annual_salaries(p_dept_id IN employees.department_id%TYPE)
RETURN SYS_REFCURSOR
IS
    emp_cursor SYS_REFCURSOR;
BEGIN
    -- Open cursor for employees in the given department
    -- (the caller fetches the rows and must CLOSE the cursor)
    OPEN emp_cursor FOR
        SELECT
            first_name || ' ' || last_name AS full_name,
            salary AS monthly_salary,
            salary * 12 AS annual_salary
        FROM employees
        WHERE department_id = p_dept_id
        ORDER BY last_name, first_name;

    RETURN emp_cursor;
END;
/

/*
Explanation:
1. `p_dept_id IN employees.department_id%TYPE`: input parameter for department ID.
2. `SYS_REFCURSOR`: allows returning a result set.
3. `first_name || ' ' || last_name`: concatenates first and last names.
4. `salary * 12`: calculates annual salary.
*/


/*

2. Displaying the Result
Display the output by calling the function in an anonymous PL/SQL block:

FIXED: v_full_name was declared as employees.first_name%TYPE (20 characters),
but it receives first_name || ' ' || last_name (up to 46 characters).
A long name raised ORA-06502 (value too large).
*/

SET SERVEROUTPUT ON

DECLARE
    v_cursor         SYS_REFCURSOR;
    v_full_name      VARCHAR2(50);                 -- first_name(20) + ' ' + last_name(25)
    v_monthly_salary employees.salary%TYPE;
    v_annual_salary  NUMBER;
BEGIN
    -- Call the function for department ID 90
    v_cursor := get_annual_salaries(90);

    -- Loop through the cursor to display results
    LOOP
        FETCH v_cursor INTO v_full_name, v_monthly_salary, v_annual_salary;
        EXIT WHEN v_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(
            'Name: ' || v_full_name ||
            ', Monthly Salary: ' || v_monthly_salary ||
            ', Annual Salary: ' || v_annual_salary
        );
    END LOOP;

    CLOSE v_cursor;
END;
/
