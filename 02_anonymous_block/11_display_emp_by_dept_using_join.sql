-- ========================================================
-- Exercise: Display Employees with Departments using Anonymous Block
-- ========================================================
-- Question:
-- Write an anonymous PL/SQL block that prints all employees along with their department names.
-- Include:
-- 1. Employee ID
-- 2. Employee full name (first_name + last_name)
-- 3. Salary
-- 4. Department name
-- Sort the results by employee ID in ascending order.
--
-- FIXED: LEFT JOIN instead of JOIN. The question asks for ALL employees.
-- An inner join silently drops employees without a department
-- (employee 178, Kimberely Grant, in the HR data).
-- ========================================================

SET SERVEROUTPUT ON;

BEGIN
    DBMS_OUTPUT.PUT_LINE('--- Employees and Their Departments ---');

    -- A cursor FOR loop opens, fetches (100 rows at a time behind the scenes),
    -- and closes the cursor automatically.
    FOR rec IN (
        SELECT e.employee_id,
               e.first_name || ' ' || e.last_name AS employee_name,
               e.salary,
               NVL(d.department_name, 'No department') AS department_name
        FROM employees e
        LEFT JOIN departments d
          ON e.department_id = d.department_id
        ORDER BY e.employee_id
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            'ID: ' || rec.employee_id ||
            ' | Name: ' || rec.employee_name ||
            ' | Salary: ' || rec.salary ||
            ' | Dept: ' || rec.department_name
        );
    END LOOP;

    -- Removed "WHEN OTHERS THEN PUT_LINE(SQLERRM)": it hid real errors.
END;
/
