-- An INDEX is a separate structure that helps Oracle FIND rows quickly,
-- like the index at the back of a book: instead of reading every page
-- (FULL TABLE SCAN), Oracle jumps straight to the right rows (INDEX SCAN).

/*
Why use indexes?
    1. Faster WHERE, JOIN and ORDER BY on the indexed columns
    2. UNIQUE indexes guarantee no duplicate values
    3. PRIMARY KEY and UNIQUE constraints create an index automatically

The price:
    1. Every INSERT / UPDATE / DELETE must also maintain the index (slower DML)
    2. Indexes use disk space
    => Index the columns you SEARCH / JOIN on, not every column.
*/

-- ============================================
-- INDEX SYNTAX
-- ============================================
-- CREATE [UNIQUE | BITMAP] INDEX index_name
-- ON table_name (column1 [, column2 ...]);
--
-- DROP INDEX index_name;

-- TYPES OF INDEXES
--   B-tree (default)   : most columns (IDs, names, dates)
--   UNIQUE             : no duplicate values allowed
--   Composite          : several columns (department_id, job_id)
--   Function-based     : on an expression, e.g. UPPER(last_name)
--   Bitmap             : few distinct values (gender, status) in data
--                        warehouses - NOT for tables with many updates
--   Invisible          : exists but ignored by the optimizer (for testing)


-- ============================================
-- STEP 0: PRACTICE TABLE
-- EMPLOYEES has only 107 rows: too small, Oracle would read it all anyway.
-- We build a copy with ~107 000 rows so the indexes are worth using.
-- ============================================
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE emp_idx_demo PURGE';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

CREATE TABLE emp_idx_demo AS
SELECT e.employee_id * 1000 + n.n AS employee_id,   -- unique ID per copy
       e.first_name,
       e.last_name,
       e.email || n.n                AS email,
       e.job_id,
       e.salary,
       e.department_id,
       e.hire_date
FROM employees e
CROSS JOIN (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 1000) n;

-- Statistics help the optimizer choose between index and full scan
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'EMP_IDX_DEMO');

SELECT COUNT(*) AS total_rows FROM emp_idx_demo;


-- ============================================
-- HOW TO SEE WHETHER AN INDEX IS USED: EXPLAIN PLAN
-- ============================================
-- EXPLAIN PLAN FOR <query>;
-- SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));
--     TABLE ACCESS FULL            -> no index used
--     INDEX UNIQUE / RANGE SCAN    -> index used

-- Before any index: FULL scan
EXPLAIN PLAN FOR
SELECT * FROM emp_idx_demo WHERE employee_id = 103500;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));


-- ============================================
-- EXAMPLE 1: PRIMARY KEY -> automatic UNIQUE index
-- ============================================
ALTER TABLE emp_idx_demo ADD CONSTRAINT emp_idx_demo_pk PRIMARY KEY (employee_id);

EXPLAIN PLAN FOR
SELECT * FROM emp_idx_demo WHERE employee_id = 103500;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));   -- INDEX UNIQUE SCAN


-- ============================================
-- EXAMPLE 2: UNIQUE INDEX
-- ============================================
CREATE UNIQUE INDEX emp_idx_demo_email_uix ON emp_idx_demo (email);

-- Duplicate email -> ORA-00001: unique constraint violated
-- INSERT INTO emp_idx_demo (employee_id, last_name, email, job_id, hire_date)
-- VALUES (999999, 'Test', 'SKING1', 'IT_PROG', SYSDATE);


-- ============================================
-- EXAMPLE 3: NORMAL (NON-UNIQUE) B-TREE INDEX
-- ============================================
CREATE INDEX emp_idx_demo_lname_ix ON emp_idx_demo (last_name);

EXPLAIN PLAN FOR
SELECT employee_id, first_name, last_name FROM emp_idx_demo WHERE last_name = 'Hunold';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));   -- INDEX RANGE SCAN


-- ============================================
-- EXAMPLE 4: COMPOSITE INDEX (several columns)
-- Useful when queries filter on BOTH columns, or on the FIRST one.
-- Column ORDER matters: (department_id, job_id) helps
--     WHERE department_id = 60
--     WHERE department_id = 60 AND job_id = 'IT_PROG'
-- but much less  WHERE job_id = 'IT_PROG'  alone.
-- ============================================
CREATE INDEX emp_idx_demo_dept_job_ix ON emp_idx_demo (department_id, job_id);

EXPLAIN PLAN FOR
SELECT * FROM emp_idx_demo WHERE department_id = 60 AND job_id = 'IT_PROG';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));


-- ============================================
-- EXAMPLE 5: WHEN AN INDEX IS *NOT* USED
-- ============================================

-- 5.1 A function on the indexed column hides the index -> FULL scan
EXPLAIN PLAN FOR
SELECT * FROM emp_idx_demo WHERE UPPER(last_name) = 'HUNOLD';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));

-- 5.2 A leading wildcard cannot use the index order -> FULL scan
--     (LIKE 'Hun%' CAN use the index, LIKE '%old' cannot)
EXPLAIN PLAN FOR
SELECT * FROM emp_idx_demo WHERE last_name LIKE '%old';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));

-- 5.3 Other common reasons
--   - WHERE column IS NULL  (B-tree indexes do not store all-NULL keys)
--   - comparing a VARCHAR2 column with a NUMBER (implicit conversion)
--   - the query returns a large part of the table (full scan is cheaper)


-- ============================================
-- EXAMPLE 6: FUNCTION-BASED INDEX (fixes 5.1)
-- ============================================
CREATE INDEX emp_idx_demo_upper_lname_ix ON emp_idx_demo (UPPER(last_name));

EXPLAIN PLAN FOR
SELECT * FROM emp_idx_demo WHERE UPPER(last_name) = 'HUNOLD';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));   -- now INDEX RANGE SCAN


-- ============================================
-- EXAMPLE 7: BITMAP INDEX (few distinct values, read-mostly data)
-- job_id has only ~19 distinct values in 107 000 rows.
-- (Available in Enterprise Edition and Oracle Free / XE 21c+)
-- ============================================
CREATE BITMAP INDEX emp_idx_demo_job_bix ON emp_idx_demo (job_id);


-- ============================================
-- EXAMPLE 8: INVISIBLE INDEX (test the impact before dropping)
-- ============================================
ALTER INDEX emp_idx_demo_lname_ix INVISIBLE;   -- optimizer ignores it
ALTER INDEX emp_idx_demo_lname_ix VISIBLE;     -- back in use


-- ============================================
-- EXAMPLE 9: LIST THE INDEXES OF A TABLE (data dictionary)
-- ============================================
SELECT index_name, index_type, uniqueness, visibility, status
FROM user_indexes
WHERE table_name = 'EMP_IDX_DEMO'
ORDER BY index_name;

SELECT index_name, column_position, column_name
FROM user_ind_columns
WHERE table_name = 'EMP_IDX_DEMO'
ORDER BY index_name, column_position;

-- Expression of the function-based index
SELECT index_name, column_expression
FROM user_ind_expressions
WHERE table_name = 'EMP_IDX_DEMO';

-- Indexes of the real HR tables (see 01_createTable&InsertRecords/02_create_indexes.sql)
SELECT table_name, index_name, uniqueness
FROM user_indexes
WHERE table_name IN ('EMPLOYEES', 'DEPARTMENTS', 'JOBS')
ORDER BY table_name, index_name;


-- ============================================
-- EXAMPLE 10: MAINTENANCE
-- ============================================
ALTER INDEX emp_idx_demo_lname_ix RENAME TO emp_idx_demo_last_name_ix;
ALTER INDEX emp_idx_demo_last_name_ix REBUILD;      -- rebuild a fragmented index
DROP INDEX emp_idx_demo_job_bix;

-- An index created by a constraint is dropped with the constraint:
-- ALTER TABLE emp_idx_demo DROP CONSTRAINT emp_idx_demo_pk;


-- ============================================
-- EXERCISES
-- ============================================

-- EX1:
-- Create an index on EMP_IDX_DEMO(hire_date) and check with EXPLAIN PLAN
-- that  WHERE hire_date = DATE '2005-09-21'  uses it.

-- EX2:
-- Write a query on SALARY that cannot use an index on SALARY
-- (hint: WHERE salary * 12 > 100000) and rewrite it so it can
-- (WHERE salary > 100000 / 12).

-- EX3:
-- Create a composite index (job_id, salary). Which of these use it best?
--   a) WHERE job_id = 'SA_REP'
--   b) WHERE salary > 10000
--   c) WHERE job_id = 'SA_REP' AND salary > 10000

-- EX4:
-- List all indexes of EMP_IDX_DEMO with their columns in one query
-- (join USER_INDEXES and USER_IND_COLUMNS).


-- ============================================
-- CLEAN UP (dropping the table drops all its indexes)
-- ============================================
-- DROP TABLE emp_idx_demo PURGE;
