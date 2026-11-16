/*
QUESTION:

A company stores employee information in a table called employees
(emp_id, emp_name, salary, department_id, status).

Write a PL/SQL program that:
1. Uses a cursor to retrieve all ACTIVE employees.
2. Processes each employee one by one.
3. Calculates a bonus as follows:
   - Department 10: 10% of salary
   - Department 20: 15% of salary
   - Other departments: 5% of salary
4. Displays the employee name and calculated bonus.

Explain why a cursor is used in this scenario.

Note: the HR EMPLOYEES table has no STATUS column, so the HR version below
processes all employees. With a STATUS column, add "WHERE status = 'ACTIVE'".

--------------------------------------------------

ANSWER:

A cursor is used because:
- The program needs to process multiple rows one by one.
- Each employee may need different procedural work (here: display a line).

CORRECTION: the bonus rule itself does NOT need row-by-row logic. A CASE
expression calculates it in SQL, in a single statement:

    SELECT first_name,
           salary * CASE department_id
                        WHEN 10 THEN 0.10
                        WHEN 20 THEN 0.15
                        ELSE 0.05
                    END AS bonus
    FROM employees;

Rule of thumb: do the calculation in SQL whenever you can, and use a cursor
loop only for the work SQL cannot do (printing, calling procedures, etc.).

--------------------------------------------------

PL/SQL CODE:
OPTIMIZED: a cursor FOR loop (no manual OPEN / FETCH / CLOSE, and Oracle
fetches 100 rows per round trip), with the bonus computed by the SQL CASE
expression instead of an IF/ELSIF chain in PL/SQL.
*/

SET SERVEROUTPUT ON;

DECLARE
    -- Cursor declaration: the bonus is calculated by SQL
    CURSOR emp_cursor IS
        SELECT employee_id,
               first_name,
               salary,
               department_id,
               salary * CASE department_id
                            WHEN 10 THEN 0.10
                            WHEN 20 THEN 0.15
                            ELSE 0.05
                        END AS bonus
        FROM employees
        ORDER BY employee_id;
BEGIN
    FOR emp_rec IN emp_cursor LOOP
        -- Display result
        DBMS_OUTPUT.PUT_LINE('Employee: ' || emp_rec.first_name ||
                             ' | Dept: ' || NVL(TO_CHAR(emp_rec.department_id), 'none') ||
                             ' | Bonus: ' || emp_rec.bonus);
    END LOOP;
END;
/
