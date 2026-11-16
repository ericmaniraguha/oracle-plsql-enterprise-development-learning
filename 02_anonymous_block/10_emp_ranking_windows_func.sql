-- ========================================================
-- Exercise: Employee Ranking and Salary Analysis using PL/SQL
-- ========================================================
-- Context:
-- You have the employees and departments tables in your Oracle database.
-- Use anonymous PL/SQL blocks to answer the following questions.
-- Combine JOINs and window functions like ROW_NUMBER(), RANK(), or COUNT() OVER () where needed.
-- Print results using DBMS_OUTPUT.PUT_LINE.
--
-- OPTIMIZATION NOTES:
-- 1. Filter in SQL, not in the PL/SQL loop. The old loops fetched every
--    joined row and relied on EXIT WHEN to stop. Putting the filter in the
--    WHERE clause lets Oracle return only the rows we print.
-- 2. Always add ORDER BY. A query without ORDER BY has no guaranteed row
--    order, so "EXIT WHEN rn > 2" could stop at the wrong row.
-- 3. FIXED a bug in "Last 5": rows arrived with rn_asc = 1, 2, 3... and
--    "EXIT WHEN rn_asc <= total_count - 5" was TRUE on the very first row,
--    so the loop exited immediately and printed nothing.
-- ========================================================

SET SERVEROUTPUT ON;

BEGIN
    -- ================= First 2 Employees =================
    DBMS_OUTPUT.PUT_LINE('--- First 2 Employees ---');
    FOR rec IN (
        SELECT emp_name, salary, department_name, rn
        FROM (
            SELECT e.first_name || ' ' || e.last_name AS emp_name,
                   e.salary,
                   d.department_name,
                   ROW_NUMBER() OVER (ORDER BY e.employee_id) AS rn
            FROM employees e
            JOIN departments d ON e.department_id = d.department_id
        )
        WHERE rn <= 2
        ORDER BY rn
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(rec.rn || ': ' || rec.emp_name || ' | Salary: ' || rec.salary || ' | Dept: ' || rec.department_name);
    END LOOP;

    -- ================= Top 10 Employees by Salary =================
    -- RANK() gives tied salaries the same rank, so this can print more than 10 rows.
    DBMS_OUTPUT.PUT_LINE('--- Top 10 Employees by Salary ---');
    FOR rec IN (
        SELECT emp_name, salary, department_name, rnk
        FROM (
            SELECT e.first_name || ' ' || e.last_name AS emp_name,
                   e.salary,
                   d.department_name,
                   RANK() OVER (ORDER BY e.salary DESC) AS rnk
            FROM employees e
            JOIN departments d ON e.department_id = d.department_id
        )
        WHERE rnk <= 10
        ORDER BY rnk
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(rec.rnk || ': ' || rec.emp_name || ' | Salary: ' || rec.salary || ' | Dept: ' || rec.department_name);
    END LOOP;

    -- ================= Last 5 Employees by Salary =================
    -- Number from the LOWEST salary up; the 5 lowest are rn_asc 1..5.
    -- No COUNT(*) OVER () is needed.
    DBMS_OUTPUT.PUT_LINE('--- Last 5 Employees by Salary ---');
    FOR rec IN (
        SELECT emp_name, salary, department_name, rn_asc
        FROM (
            SELECT e.first_name || ' ' || e.last_name AS emp_name,
                   e.salary,
                   d.department_name,
                   ROW_NUMBER() OVER (ORDER BY e.salary ASC, e.employee_id) AS rn_asc
            FROM employees e
            JOIN departments d ON e.department_id = d.department_id
        )
        WHERE rn_asc <= 5
        ORDER BY rn_asc
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(rec.rn_asc || ': ' || rec.emp_name || ' | Salary: ' || rec.salary || ' | Dept: ' || rec.department_name);
    END LOOP;

    -- ================= 50th Employee by Salary =================
    DBMS_OUTPUT.PUT_LINE('--- 50th Employee by Salary ---');
    FOR rec IN (
        SELECT emp_name, salary, department_name, rn
        FROM (
            SELECT e.first_name || ' ' || e.last_name AS emp_name,
                   e.salary,
                   d.department_name,
                   ROW_NUMBER() OVER (ORDER BY e.salary DESC, e.employee_id) AS rn
            FROM employees e
            JOIN departments d ON e.department_id = d.department_id
        )
        WHERE rn = 50
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(rec.rn || ': ' || rec.emp_name || ' | Salary: ' || rec.salary || ' | Dept: ' || rec.department_name);
    END LOOP;

    -- No "WHEN OTHERS THEN PUT_LINE" here: printing and swallowing an error
    -- makes a failed block look successful. Let unexpected errors surface.
END;
/
