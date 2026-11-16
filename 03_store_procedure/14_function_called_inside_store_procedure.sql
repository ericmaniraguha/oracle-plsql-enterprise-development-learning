
-- This PL/SQL procedure `display_ann_salary` retrieves employee details (name, department, and salary), calculates the annual salary using a function, and displays the results.


/*
1. How can we retrieve an employee's full name, department, and salary using a JOIN?

2. How do we calculate annual salary from a monthly salary using a function?

3. How can we display results in PL/SQL using DBMS_OUTPUT?

4. How do we handle cases where the employee ID does not exist?

5. How can we test a stored procedure using:
   - Direct EXEC call
   - Anonymous block
   - Multiple test inputs

6. How can we structure clean and readable PL/SQL code with proper variables?

FIXES / IMPROVEMENTS:
- LEFT JOIN instead of JOIN: an employee with no department (employee 178)
  used to be reported as "No such Employee ID" because the inner join
  removed the row.
- Variables use %TYPE, so they always match the column sizes.
- The function is DETERMINISTIC (same input -> same output). Oracle can then
  cache results when the function is called from SQL.
- Test variables are named after what they hold (employee IDs, not salaries).
*/

---

-- 1. Function to calculate annual salary
CREATE OR REPLACE FUNCTION calc_ann_salary(p_salary IN NUMBER)
RETURN NUMBER
DETERMINISTIC
IS
BEGIN
    RETURN p_salary * 12;
END;
/

---

-- 2. Procedure Implementation

CREATE OR REPLACE PROCEDURE display_ann_salary(
    p_emp_id IN employees.employee_id%TYPE   -- Input parameter: Employee ID
)
IS
    v_names          VARCHAR2(50);                        -- first_name(20) + ' ' + last_name(25)
    v_dept_name      departments.department_name%TYPE;    -- Stores department name
    v_monthly_salary employees.salary%TYPE;               -- Stores monthly salary
    v_annual_salary  NUMBER;                              -- Stores computed annual salary
BEGIN

    -- Retrieve employee details using JOIN
    SELECT e.first_name || ' ' || e.last_name,
           NVL(d.department_name, 'No department'),
           e.salary
    INTO v_names,
         v_dept_name,
         v_monthly_salary
    FROM employees e
    LEFT JOIN departments d
        ON e.department_id = d.department_id
    WHERE e.employee_id = p_emp_id;

    -- Calculate annual salary using function
    v_annual_salary := calc_ann_salary(v_monthly_salary);

    -- Display results
    DBMS_OUTPUT.PUT_LINE('Employee Name       : ' || v_names);
    DBMS_OUTPUT.PUT_LINE('Department          : ' || v_dept_name);
    DBMS_OUTPUT.PUT_LINE('Monthly Salary      : ' || v_monthly_salary);
    DBMS_OUTPUT.PUT_LINE('Annual Salary       : ' || v_annual_salary);

-- Exception handling
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No such Employee ID: ' || p_emp_id);
END;
/

--- 3. Test Cases

-- Enable output
SET SERVEROUTPUT ON;

-- 3.1. Direct Execution
EXEC display_ann_salary(250);
EXECUTE display_ann_salary(100);

-- 3.2. Anonymous Block (Multiple Tests)
DECLARE
    v_emp_missing   employees.employee_id%TYPE := 45;
    v_emp_existing  employees.employee_id%TYPE := 120;
    v_emp_no_dept   employees.employee_id%TYPE := 178;   -- works now thanks to LEFT JOIN
BEGIN
    display_ann_salary(v_emp_missing);

    DBMS_OUTPUT.PUT_LINE('------------------------------------------');

    display_ann_salary(v_emp_existing);

    DBMS_OUTPUT.PUT_LINE('------------------------------------------');

    display_ann_salary(v_emp_no_dept);
END;
/

---  Expected Results (Answers)

-- If employee exists:
--    - Full name is displayed
--    - Department name is shown ('No department' if none)
--    - Monthly salary is printed
--    - Annual salary is calculated and displayed

-- If employee does NOT exist:
--    Output:
--    No such Employee ID: <id>

---  Key Concepts

-- JOIN between tables (employees & departments)
-- SELECT INTO for single-row retrieval
-- Calling user-defined functions
-- DBMS_OUTPUT for displaying results
-- Exception handling (NO_DATA_FOUND)
-- Procedure testing methods
