-- ========================================================
-- Exercise 8: Highest Salary Employee with Exception Handling
-- ========================================================
-- FIXED: the old check "IF v_salary IS NULL THEN RAISE e_no_employee_found"
-- could never run. With an empty table MAX(salary) is NULL, "salary = NULL"
-- matches nothing, and SELECT INTO raised NO_DATA_FOUND first.
-- Now the block reads MAX(salary) on its own. An aggregate query ALWAYS
-- returns exactly one row (even on an empty table), so the user-defined
-- exception is reachable.
-- ========================================================
DECLARE
    v_first_name employees.first_name%TYPE;
    v_last_name  employees.last_name%TYPE;
    v_max_salary employees.salary%TYPE;

    -- User-defined exception
    e_no_employee_found EXCEPTION;
BEGIN
    -- Step 1: aggregate query, never raises NO_DATA_FOUND
    SELECT MAX(salary)
    INTO v_max_salary
    FROM employees;

    IF v_max_salary IS NULL THEN
        RAISE e_no_employee_found;
    END IF;

    -- Step 2: fetch the employee who earns it
    SELECT first_name, last_name
    INTO v_first_name, v_last_name
    FROM employees
    WHERE salary = v_max_salary;

    DBMS_OUTPUT.PUT_LINE('Highest salary employee: ' || v_first_name || ' ' || v_last_name || ' - Salary: ' || v_max_salary);

EXCEPTION
    -- Handle user-defined exception
    WHEN e_no_employee_found THEN
        DBMS_OUTPUT.PUT_LINE('Error: No employees (with a salary) found in the table.');

    -- Handle predefined exception: two or more employees share the top salary
    WHEN TOO_MANY_ROWS THEN
        DBMS_OUTPUT.PUT_LINE('Error: More than one employee has the highest salary (' || v_max_salary || ').');

    -- Anything else is unexpected: report it, then RE-RAISE so the caller
    -- (and SQL Developer) still sees the real error instead of a silent success.
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Unexpected error: ' || SQLERRM);
        RAISE;
END;
/
-- ========================================================
