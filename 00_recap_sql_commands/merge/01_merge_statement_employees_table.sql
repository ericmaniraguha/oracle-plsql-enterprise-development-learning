-- MERGE combines INSERT, UPDATE (and optionally DELETE) in ONE statement.
-- It compares a SOURCE with a TARGET table row by row:
--     row exists in target  -> UPDATE it (or DELETE it)
--     row does not exist    -> INSERT it
-- This is often called an "UPSERT" (UPDate + inSERT).

/*
Why use MERGE?
    1. One statement instead of "UPDATE ... then INSERT ..." (less code)
    2. The target is read only once (faster on big tables)
    3. Typical for synchronising tables: loading staging data,
       nightly ETL, keeping a summary table up to date
    4. Each part can have its own WHERE condition
*/

-- ============================================
-- MERGE SYNTAX
-- ============================================

-- MERGE INTO target_table t
-- USING source_table_or_query s
-- ON (t.key = s.key)                            -- how rows are matched
-- WHEN MATCHED THEN
--     UPDATE SET t.col1 = s.col1, ...
--     [WHERE condition]                         -- update only some rows
--     [DELETE WHERE condition]                  -- remove some updated rows
-- WHEN NOT MATCHED THEN
--     INSERT (t.col1, t.col2, ...)
--     VALUES (s.col1, s.col2, ...)
--     [WHERE condition];                        -- insert only some rows

-- RULES
--  - Both WHEN clauses are optional, but at least one is required.
--  - The columns used in ON (...) CANNOT be updated  (ORA-38104).
--  - Each target row may be matched by ONE source row only (ORA-30926).
--  - MERGE is DML: finish with COMMIT or ROLLBACK.


-- ============================================
-- STEP 0: PRACTICE TABLES
-- We work on COPIES so the real HR tables are not changed.
-- ============================================

BEGIN
    FOR t IN (SELECT table_name FROM user_tables
              WHERE table_name IN ('EMP_MERGE_TARGET', 'EMP_MERGE_SOURCE', 'DEPT_SALARY_SUMMARY')) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || DBMS_ASSERT.ENQUOTE_NAME(t.table_name) || ' PURGE';
    END LOOP;
END;
/

-- TARGET: current IT (60) and Executive (90) employees
CREATE TABLE emp_merge_target AS
SELECT employee_id, first_name, last_name, email, job_id, salary, department_id
FROM employees
WHERE department_id IN (60, 90);

ALTER TABLE emp_merge_target ADD CONSTRAINT emp_merge_target_pk PRIMARY KEY (employee_id);

-- SOURCE: changes sent by HR (like a file loaded into a staging table)
--   action_flag: U = update, I = new employee, D = employee has left
CREATE TABLE emp_merge_source (
    employee_id   NUMBER(6),
    first_name    VARCHAR2(20),
    last_name     VARCHAR2(25),
    email         VARCHAR2(25),
    job_id        VARCHAR2(10),
    salary        NUMBER(8,2),
    department_id NUMBER(4),
    action_flag   CHAR(1)
);

INSERT INTO emp_merge_source VALUES (103, 'Alexander', 'Hunold',  'AHUNOLD',  'IT_PROG', 9900, 60, 'U'); -- raise 9000 -> 9900
INSERT INTO emp_merge_source VALUES (104, 'Bruce',     'Ernst',   'BERNST',   'IT_PROG', 6000, 90, 'U'); -- moves to dept 90
INSERT INTO emp_merge_source VALUES (105, 'David',     'Austin',  'DAUSTIN',  'IT_PROG', 4800, 60, 'U'); -- NO real change
INSERT INTO emp_merge_source VALUES (107, 'Diana',     'Lorentz', 'DLORENTZ', 'IT_PROG', 4200, 60, 'D'); -- has left
INSERT INTO emp_merge_source VALUES (300, 'Eric',      'Mugisha', 'EMUGISHA', 'IT_PROG', 5500, 60, 'I'); -- new, IT
INSERT INTO emp_merge_source VALUES (301, 'Aline',     'Uwase',   'AUWASE',   'SA_REP',  7000, 80, 'I'); -- new, Sales
COMMIT;

-- Look at both tables before merging
SELECT * FROM emp_merge_target ORDER BY employee_id;
SELECT * FROM emp_merge_source ORDER BY employee_id;


-- ============================================
-- EXAMPLE 1: BASIC UPSERT
-- Update existing employees, insert new ones.
-- Expected: 6 rows merged (4 updated: 103, 104, 105, 107 / 2 inserted: 300, 301)
-- ============================================

MERGE INTO emp_merge_target t
USING emp_merge_source s
ON (t.employee_id = s.employee_id)
WHEN MATCHED THEN
    UPDATE SET t.salary        = s.salary,
               t.job_id        = s.job_id,
               t.department_id = s.department_id
WHEN NOT MATCHED THEN
    INSERT (employee_id, first_name, last_name, email, job_id, salary, department_id)
    VALUES (s.employee_id, s.first_name, s.last_name, s.email, s.job_id, s.salary, s.department_id);

SELECT * FROM emp_merge_target ORDER BY employee_id;

ROLLBACK;   -- undo, so every example starts from the same data


-- ============================================
-- EXAMPLE 2: CONDITIONAL UPDATE AND INSERT
--  - Update ONLY rows whose data really changed (105 and 107 are skipped:
--    their salary, job and department are the same in source and target)
--  - Insert ONLY new IT employees (department 60): 301 is skipped
-- Expected: 3 rows merged (103, 104 updated / 300 inserted)
-- ============================================

MERGE INTO emp_merge_target t
USING emp_merge_source s
ON (t.employee_id = s.employee_id)
WHEN MATCHED THEN
    UPDATE SET t.salary        = s.salary,
               t.job_id        = s.job_id,
               t.department_id = s.department_id
    WHERE t.salary        <> s.salary
       OR t.job_id        <> s.job_id
       OR t.department_id <> s.department_id
WHEN NOT MATCHED THEN
    INSERT (employee_id, first_name, last_name, email, job_id, salary, department_id)
    VALUES (s.employee_id, s.first_name, s.last_name, s.email, s.job_id, s.salary, s.department_id)
    WHERE s.department_id = 60;

SELECT * FROM emp_merge_target ORDER BY employee_id;

ROLLBACK;


-- ============================================
-- EXAMPLE 3: UPDATE + DELETE + INSERT IN ONE STATEMENT
-- DELETE WHERE removes matched rows AFTER they are updated.
-- Employee 107 (flag 'D') is removed from the target.
-- Note: DELETE WHERE only affects rows that the UPDATE part touched.
-- ============================================

MERGE INTO emp_merge_target t
USING emp_merge_source s
ON (t.employee_id = s.employee_id)
WHEN MATCHED THEN
    UPDATE SET t.salary        = s.salary,
               t.job_id        = s.job_id,
               t.department_id = s.department_id
    DELETE WHERE s.action_flag = 'D'
WHEN NOT MATCHED THEN
    INSERT (employee_id, first_name, last_name, email, job_id, salary, department_id)
    VALUES (s.employee_id, s.first_name, s.last_name, s.email, s.job_id, s.salary, s.department_id)
    WHERE s.action_flag = 'I';

-- 107 is gone, 300 and 301 are new
SELECT * FROM emp_merge_target ORDER BY employee_id;

ROLLBACK;


-- ============================================
-- EXAMPLE 4: INSERT ONLY (no WHEN MATCHED)
-- "Add the employees that are missing, do not touch the others."
-- Expected: 2 rows inserted (300, 301)
-- ============================================

MERGE INTO emp_merge_target t
USING emp_merge_source s
ON (t.employee_id = s.employee_id)
WHEN NOT MATCHED THEN
    INSERT (employee_id, first_name, last_name, email, job_id, salary, department_id)
    VALUES (s.employee_id, s.first_name, s.last_name, s.email, s.job_id, s.salary, s.department_id);

ROLLBACK;


-- ============================================
-- EXAMPLE 5: SOURCE = A QUERY (aggregation)
-- Keep a department salary summary table up to date.
-- Run the MERGE, change salaries, run it again: only differences change.
-- ============================================

CREATE TABLE dept_salary_summary (
    department_id  NUMBER(4) PRIMARY KEY,
    employee_count NUMBER,
    total_salary   NUMBER(12,2),
    avg_salary     NUMBER(10,2),
    last_refreshed DATE
);

MERGE INTO dept_salary_summary t
USING (
    SELECT department_id,
           COUNT(*)              AS employee_count,
           SUM(salary)           AS total_salary,
           ROUND(AVG(salary), 2) AS avg_salary
    FROM employees
    WHERE department_id IS NOT NULL
    GROUP BY department_id
) s
ON (t.department_id = s.department_id)
WHEN MATCHED THEN
    UPDATE SET t.employee_count = s.employee_count,
               t.total_salary   = s.total_salary,
               t.avg_salary     = s.avg_salary,
               t.last_refreshed = SYSDATE
WHEN NOT MATCHED THEN
    INSERT (department_id, employee_count, total_salary, avg_salary, last_refreshed)
    VALUES (s.department_id, s.employee_count, s.total_salary, s.avg_salary, SYSDATE);

COMMIT;

SELECT * FROM dept_salary_summary ORDER BY department_id;


-- ============================================
-- EXAMPLE 6: SINGLE-ROW UPSERT FROM DUAL (inside PL/SQL)
-- "Save this employee: update if it exists, insert if not."
-- SQL%ROWCOUNT tells how many rows the MERGE touched.
-- ============================================

CREATE OR REPLACE PROCEDURE prc_save_employee (
    p_id     IN NUMBER,
    p_first  IN VARCHAR2,
    p_last   IN VARCHAR2,
    p_email  IN VARCHAR2,
    p_job    IN VARCHAR2,
    p_salary IN NUMBER,
    p_dept   IN NUMBER
) IS
BEGIN
    MERGE INTO emp_merge_target t
    USING (SELECT p_id AS employee_id FROM dual) s
    ON (t.employee_id = s.employee_id)
    WHEN MATCHED THEN
        UPDATE SET t.first_name    = p_first,
                   t.last_name     = p_last,
                   t.email         = p_email,
                   t.job_id        = p_job,
                   t.salary        = p_salary,
                   t.department_id = p_dept
    WHEN NOT MATCHED THEN
        INSERT (employee_id, first_name, last_name, email, job_id, salary, department_id)
        VALUES (p_id, p_first, p_last, p_email, p_job, p_salary, p_dept);

    DBMS_OUTPUT.PUT_LINE('Employee ' || p_id || ' saved (' || SQL%ROWCOUNT || ' row).');
END prc_save_employee;
/

SET SERVEROUTPUT ON;
EXEC prc_save_employee(400, 'Grace', 'Ingabire', 'GINGABIRE', 'IT_PROG', 5000, 60);  -- inserted
EXEC prc_save_employee(400, 'Grace', 'Ingabire', 'GINGABIRE', 'IT_PROG', 5600, 60);  -- updated

SELECT * FROM emp_merge_target WHERE employee_id = 400;

ROLLBACK;


-- ============================================
-- EXAMPLE 7: COMMON MERGE ERRORS
-- ============================================

-- 7.1 ORA-38104: Columns referenced in the ON Clause cannot be updated
-- MERGE INTO emp_merge_target t
-- USING emp_merge_source s
-- ON (t.employee_id = s.employee_id)
-- WHEN MATCHED THEN
--     UPDATE SET t.employee_id = s.employee_id;

-- 7.2 ORA-30926: unable to get a stable set of rows in the source tables
--     The SAME target row is matched by TWO source rows.
-- INSERT INTO emp_merge_source VALUES (103, 'Alexander', 'Hunold', 'AHUNOLD', 'IT_PROG', 9500, 60, 'U');
-- MERGE INTO emp_merge_target t
-- USING emp_merge_source s
-- ON (t.employee_id = s.employee_id)
-- WHEN MATCHED THEN UPDATE SET t.salary = s.salary;
-- ROLLBACK;
--
--     FIX: make the source unique, e.g. keep the highest salary per employee
--     USING (SELECT employee_id, MAX(salary) AS salary
--            FROM emp_merge_source GROUP BY employee_id) s


-- ============================================
-- MERGE vs UPDATE + INSERT
-- ============================================
-- Without MERGE you need two statements (and the target is read twice):
--
-- UPDATE emp_merge_target t
-- SET salary = (SELECT s.salary FROM emp_merge_source s WHERE s.employee_id = t.employee_id)
-- WHERE EXISTS (SELECT 1 FROM emp_merge_source s WHERE s.employee_id = t.employee_id);
--
-- INSERT INTO emp_merge_target (employee_id, first_name, last_name, email, job_id, salary, department_id)
-- SELECT employee_id, first_name, last_name, email, job_id, salary, department_id
-- FROM emp_merge_source s
-- WHERE NOT EXISTS (SELECT 1 FROM emp_merge_target t WHERE t.employee_id = s.employee_id);


-- ============================================
-- EXERCISES
-- ============================================

-- EX1:
-- Using EMP_MERGE_SOURCE, give a 10% raise to the matched employees
-- (t.salary = t.salary * 1.10) and insert the new ones with their salary.

-- EX2:
-- Merge only the rows with action_flag = 'U'
-- (hint: filter the source in USING (SELECT ... WHERE action_flag = 'U')).

-- EX3:
-- Create a table JOB_SALARY_SUMMARY (job_id, min_salary, max_salary, employees)
-- and keep it up to date from EMPLOYEES with a MERGE (like Example 5).

-- EX4:
-- Write a procedure PRC_SAVE_DEPARTMENT(p_id, p_name, p_location_id)
-- that inserts or updates a row in a copy of DEPARTMENTS using MERGE ... USING dual.

-- EX5:
-- Use one MERGE to: update matched rows, delete matched rows whose new
-- salary is below 5000, and insert new rows only for department 60.


-- ============================================
-- CLEAN UP
-- ============================================
-- DROP PROCEDURE prc_save_employee;
-- DROP TABLE emp_merge_target PURGE;
-- DROP TABLE emp_merge_source PURGE;
-- DROP TABLE dept_salary_summary PURGE;
