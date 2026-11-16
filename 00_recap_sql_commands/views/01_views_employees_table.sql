-- A VIEW is a STORED QUERY with a name. It stores no data itself:
-- every time you select from the view, Oracle runs its query.
-- You use it exactly like a table:  SELECT * FROM my_view;

/*
Why use views?
    1. Simplicity : hide complex joins / calculations behind a simple name
    2. Security   : show only some columns or rows (e.g. no salary column)
                    and grant SELECT on the view instead of the table
    3. Consistency: everyone uses the same business rule (e.g. "annual salary")
    4. Stability  : applications keep working if the tables behind change

Kinds of views
    Simple view      : one table, no GROUP BY / DISTINCT -> usually updatable
    Complex view     : joins, GROUP BY, functions -> usually read-only
    Materialized view: STORES the result; refreshed on demand / on commit
*/

-- ============================================
-- VIEW SYNTAX
-- ============================================
-- CREATE [OR REPLACE] [FORCE] VIEW view_name [(alias1, alias2, ...)] AS
-- SELECT ...
-- [WITH CHECK OPTION [CONSTRAINT name]]
-- [WITH READ ONLY];
--
-- DROP VIEW view_name;


-- ============================================
-- EXAMPLE 1: SIMPLE VIEW - hide sensitive columns
-- Staff directory without salary / commission.
-- ============================================
CREATE OR REPLACE VIEW vw_emp_directory AS
SELECT employee_id,
       first_name,
       last_name,
       email,
       phone_number,
       department_id
FROM employees;

SELECT * FROM vw_emp_directory WHERE department_id = 60;

-- Security: other users can read the view but not the table
-- GRANT SELECT ON vw_emp_directory TO some_user;


-- ============================================
-- EXAMPLE 2: COMPLEX VIEW - joins + calculated columns
-- ============================================
CREATE OR REPLACE VIEW vw_emp_details AS
SELECT e.employee_id,
       e.first_name || ' ' || e.last_name        AS full_name,
       j.job_title,
       d.department_name,
       l.city,
       e.salary,
       e.salary * 12                              AS annual_salary,
       m.first_name || ' ' || m.last_name         AS manager_name
FROM employees e
JOIN jobs j             ON j.job_id        = e.job_id
LEFT JOIN departments d ON d.department_id = e.department_id
LEFT JOIN locations l   ON l.location_id   = d.location_id
LEFT JOIN employees m   ON m.employee_id   = e.manager_id;

-- The users only see a "table"; the joins are hidden
SELECT full_name, job_title, department_name, city, annual_salary
FROM vw_emp_details
WHERE city = 'Seattle'
ORDER BY annual_salary DESC;


-- ============================================
-- EXAMPLE 3: AGGREGATE VIEW - department statistics
-- Column names given in the header (alias list).
-- ============================================
CREATE OR REPLACE VIEW vw_dept_stats (department_id, department_name, employees,
                                      total_salary, avg_salary, max_salary) AS
SELECT d.department_id,
       d.department_name,
       COUNT(e.employee_id),
       SUM(e.salary),
       ROUND(AVG(e.salary), 2),
       MAX(e.salary)
FROM departments d
JOIN employees e ON e.department_id = d.department_id
GROUP BY d.department_id, d.department_name;

SELECT * FROM vw_dept_stats ORDER BY total_salary DESC;

-- A view can be used in joins and in other views
SELECT v.full_name, v.salary, s.avg_salary
FROM vw_emp_details v
JOIN vw_dept_stats s ON s.department_name = v.department_name
WHERE v.salary > s.avg_salary;


-- ============================================
-- EXAMPLE 4: DML THROUGH A SIMPLE VIEW
-- INSERT / UPDATE / DELETE on a simple view change the BASE TABLE.
-- Practice on a copy so HR data is not changed.
-- ============================================
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE emp_view_demo PURGE';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

CREATE TABLE emp_view_demo AS
SELECT employee_id, first_name, last_name, email, job_id, salary, department_id, hire_date
FROM employees;

CREATE OR REPLACE VIEW vw_it_staff AS
SELECT employee_id, first_name, last_name, email, job_id, salary, department_id, hire_date
FROM emp_view_demo
WHERE department_id = 60;

-- Update through the view -> the base table is updated
UPDATE vw_it_staff SET salary = salary + 500 WHERE employee_id = 104;

SELECT employee_id, salary FROM emp_view_demo WHERE employee_id = 104;

-- PROBLEM: without CHECK OPTION a row can "escape" the view
UPDATE vw_it_staff SET department_id = 90 WHERE employee_id = 105;
SELECT COUNT(*) AS still_visible FROM vw_it_staff WHERE employee_id = 105;  -- 0

ROLLBACK;


-- ============================================
-- EXAMPLE 5: WITH CHECK OPTION
-- DML through the view must keep the row INSIDE the view.
-- ============================================
CREATE OR REPLACE VIEW vw_it_staff AS
SELECT employee_id, first_name, last_name, email, job_id, salary, department_id, hire_date
FROM emp_view_demo
WHERE department_id = 60
WITH CHECK OPTION CONSTRAINT vw_it_staff_chk;

-- Now refused: ORA-01402: view WITH CHECK OPTION where-clause violation
-- UPDATE vw_it_staff SET department_id = 90 WHERE employee_id = 105;

-- Insert into IT is allowed
INSERT INTO vw_it_staff (employee_id, first_name, last_name, email, job_id, salary, department_id, hire_date)
VALUES (500, 'Eric', 'Mugisha', 'EMUGISHA', 'IT_PROG', 5500, 60, SYSDATE);

-- Insert into another department through this view is refused (ORA-01402)
-- INSERT INTO vw_it_staff (employee_id, last_name, email, job_id, department_id, hire_date)
-- VALUES (501, 'Uwase', 'AUWASE', 'SA_REP', 80, SYSDATE);

ROLLBACK;


-- ============================================
-- EXAMPLE 6: WITH READ ONLY
-- ============================================
CREATE OR REPLACE VIEW vw_salary_report AS
SELECT employee_id, last_name, salary, department_id
FROM emp_view_demo
WITH READ ONLY;

SELECT * FROM vw_salary_report WHERE salary > 12000;

-- Any DML is refused: ORA-42399: cannot perform a DML operation on a read-only view
-- UPDATE vw_salary_report SET salary = 1 WHERE employee_id = 100;


-- ============================================
-- EXAMPLE 7: WHICH VIEW COLUMNS CAN BE UPDATED?
-- Complex views are mostly read-only (ORA-01732 / ORA-01779).
-- ============================================
SELECT table_name, column_name, updatable, insertable, deletable
FROM user_updatable_columns
WHERE table_name IN ('VW_IT_STAFF', 'VW_DEPT_STATS', 'VW_EMP_DETAILS')
ORDER BY table_name, column_name;


-- ============================================
-- EXAMPLE 8: MATERIALIZED VIEW (stores the result)
-- Needs the CREATE MATERIALIZED VIEW privilege:
--     GRANT CREATE MATERIALIZED VIEW TO your_user;   (as DBA)
-- Good for heavy reports that do not need second-by-second data.
-- ============================================
BEGIN
    EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW mv_dept_salary';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -12003 THEN RAISE; END IF;   -- does not exist
END;
/

CREATE MATERIALIZED VIEW mv_dept_salary
BUILD IMMEDIATE            -- fill it now
REFRESH COMPLETE ON DEMAND -- refresh only when asked
AS
SELECT department_id, COUNT(*) AS employees, SUM(salary) AS total_salary
FROM emp_view_demo
GROUP BY department_id;

SELECT * FROM mv_dept_salary ORDER BY department_id;

-- Change the base table: the materialized view does NOT change yet
UPDATE emp_view_demo SET salary = salary + 1000 WHERE department_id = 60;
COMMIT;

SELECT * FROM mv_dept_salary WHERE department_id = 60;   -- old total

EXEC DBMS_MVIEW.REFRESH('MV_DEPT_SALARY');

SELECT * FROM mv_dept_salary WHERE department_id = 60;   -- new total


-- ============================================
-- EXAMPLE 9: VIEWS IN THE DATA DICTIONARY
-- ============================================
SELECT view_name, text_length, read_only
FROM user_views
ORDER BY view_name;

-- The stored query of a view
SELECT text FROM user_views WHERE view_name = 'VW_EMP_DIRECTORY';

-- A view becomes INVALID if its table changes; it is recompiled automatically
-- on next use, or manually:
ALTER VIEW vw_emp_details COMPILE;

SELECT object_name, object_type, status
FROM user_objects
WHERE object_type IN ('VIEW', 'MATERIALIZED VIEW')
ORDER BY object_name;


-- ============================================
-- EXERCISES
-- ============================================

-- EX1:
-- Create a view VW_HIGH_EARNERS of employees earning more than 10000
-- (name, job title, department, salary).

-- EX2:
-- Create a view VW_EMP_SERVICE showing each employee's years of service
-- (TRUNC(MONTHS_BETWEEN(SYSDATE, hire_date) / 12)).

-- EX3:
-- Create a view on EMP_VIEW_DEMO for department 80 WITH CHECK OPTION.
-- Try to move an employee to department 50 through the view. What happens?

-- EX4:
-- Create a READ ONLY view of jobs with min/max salary and the number of
-- employees in each job.

-- EX5:
-- Find all views of your schema that are INVALID.


-- ============================================
-- CLEAN UP (views first, then the table)
-- ============================================
-- DROP MATERIALIZED VIEW mv_dept_salary;
-- DROP VIEW vw_salary_report;
-- DROP VIEW vw_it_staff;
-- DROP VIEW vw_dept_stats;
-- DROP VIEW vw_emp_details;
-- DROP VIEW vw_emp_directory;
-- DROP TABLE emp_view_demo PURGE;
