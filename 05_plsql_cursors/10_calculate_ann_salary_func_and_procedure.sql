/* =====================================================
   QUESTION 1: Create a Function
   Create a function calc_annual_salary that:
   - Takes monthly salary as input
   - Returns annual salary
===================================================== */

-- ANSWER
-- DETERMINISTIC: same input, same output, so Oracle may cache the result
-- when the function is called from SQL.
CREATE OR REPLACE FUNCTION calc_annual_salary (
    p_monthly_salary IN NUMBER
) RETURN NUMBER
DETERMINISTIC
IS
BEGIN
    RETURN p_monthly_salary * 12;
END;
/

/* =====================================================
   QUESTION 2: Create a Procedure
   Create a procedure show_employee_salary that:
   - Takes an employee ID
   - Displays the employee's name, monthly salary, and
     annual salary (using calc_annual_salary)
   - Handles the case where the employee does not exist

   FIXED: this file contained QUESTION 1 twice and never created
   show_employee_salary, so QUESTION 4 failed with PLS-00201
   (identifier must be declared).
===================================================== */

-- ANSWER
CREATE OR REPLACE PROCEDURE show_employee_salary (
    p_emp_id IN employees.employee_id%TYPE
)
IS
    v_full_name VARCHAR2(50);              -- first_name(20) + ' ' + last_name(25)
    v_salary    employees.salary%TYPE;
BEGIN
    SELECT first_name || ' ' || last_name, salary
    INTO v_full_name, v_salary
    FROM employees
    WHERE employee_id = p_emp_id;

    DBMS_OUTPUT.PUT_LINE('Employee       : ' || v_full_name);
    DBMS_OUTPUT.PUT_LINE('Monthly Salary : ' || v_salary);
    DBMS_OUTPUT.PUT_LINE('Annual Salary  : ' || calc_annual_salary(v_salary));
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No employee found with ID ' || p_emp_id);
END;
/

/* =====================================================
   QUESTION 3: Exception Handling
   Already included in the procedure above:
   - Handles NO_DATA_FOUND
===================================================== */


/* =====================================================
   QUESTION 4: Execute the Procedure
   Call the procedure with employee ID
===================================================== */

-- ANSWER
SET SERVEROUTPUT ON;

BEGIN
    show_employee_salary(101);
    show_employee_salary(999);   -- does not exist
END;
/
