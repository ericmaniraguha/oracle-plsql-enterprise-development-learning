-- A CONSTRAINT is a RULE stored with the table. Oracle checks it on every
-- INSERT / UPDATE / DELETE and refuses any change that breaks the rule.
-- Constraints keep the data correct no matter which program changes it.

/*
The 5 constraint types
    NOT NULL     a value is required
    UNIQUE       no duplicate values (NULLs are allowed)
    PRIMARY KEY  = NOT NULL + UNIQUE, identifies each row (one per table)
    FOREIGN KEY  value must exist in the parent table (relationship)
    CHECK        value must satisfy a condition (salary > 0)

DEFAULT is NOT a constraint: it only supplies a value when none is given.

What happens to CHILD rows when the PARENT row is deleted?
    (no option)          -> DELETE of the parent is REFUSED (ORA-02292)
    ON DELETE CASCADE    -> the child rows are deleted too
    ON DELETE SET NULL   -> the foreign key in the child rows becomes NULL
*/

-- ============================================
-- CONSTRAINT SYNTAX
-- ============================================
-- Column level:  salary NUMBER CONSTRAINT emp_sal_ck CHECK (salary > 0)
-- Table level :  CONSTRAINT emp_pk PRIMARY KEY (employee_id)
--                CONSTRAINT emp_dept_fk FOREIGN KEY (department_id)
--                    REFERENCES departments (department_id) [ON DELETE CASCADE | SET NULL]
-- Later       :  ALTER TABLE t ADD CONSTRAINT ... ;
--                ALTER TABLE t DROP CONSTRAINT name;
--                ALTER TABLE t DISABLE | ENABLE CONSTRAINT name;
--
-- TIP: always NAME your constraints (table_column_type). Otherwise Oracle
-- calls them SYS_C00123 and error messages are hard to understand.


-- ============================================
-- STEP 0: CLEAN START (children first, or use CASCADE CONSTRAINTS)
-- ============================================
BEGIN
    FOR t IN (SELECT table_name FROM user_tables
              WHERE table_name IN ('CC_ASSIGNMENT', 'CC_PARKING', 'CC_EMPLOYEE',
                                   'CC_PROJECT', 'CC_DEPARTMENT')) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || DBMS_ASSERT.ENQUOTE_NAME(t.table_name)
                          || ' CASCADE CONSTRAINTS PURGE';
    END LOOP;
END;
/


-- ============================================
-- EXAMPLE 1: TABLES WITH ALL CONSTRAINT TYPES
--
--   CC_DEPARTMENT 1---* CC_EMPLOYEE 1---* CC_ASSIGNMENT *---1 CC_PROJECT
--                            1
--                            |
--                            0..1 CC_PARKING
-- ============================================

CREATE TABLE cc_department (
    department_id   NUMBER(4)     CONSTRAINT cc_dept_pk PRIMARY KEY,
    department_name VARCHAR2(30)  CONSTRAINT cc_dept_name_nn NOT NULL
                                  CONSTRAINT cc_dept_name_uk UNIQUE,
    budget          NUMBER(12,2)  DEFAULT 0
                                  CONSTRAINT cc_dept_budget_ck CHECK (budget >= 0)
);

CREATE TABLE cc_employee (
    employee_id   NUMBER(6)     CONSTRAINT cc_emp_pk PRIMARY KEY,
    full_name     VARCHAR2(50)  CONSTRAINT cc_emp_name_nn NOT NULL,
    email         VARCHAR2(50)  CONSTRAINT cc_emp_email_uk UNIQUE,
    gender        CHAR(1)       CONSTRAINT cc_emp_gender_ck CHECK (gender IN ('M', 'F')),
    salary        NUMBER(8,2)   CONSTRAINT cc_emp_salary_ck CHECK (salary > 0),
    hire_date     DATE          DEFAULT SYSDATE NOT NULL,
    department_id NUMBER(4),
    -- ON DELETE CASCADE: deleting a department deletes its employees
    CONSTRAINT cc_emp_dept_fk FOREIGN KEY (department_id)
        REFERENCES cc_department (department_id) ON DELETE CASCADE
);

CREATE TABLE cc_project (
    project_id   NUMBER(6)    CONSTRAINT cc_proj_pk PRIMARY KEY,
    project_name VARCHAR2(50) CONSTRAINT cc_proj_name_nn NOT NULL,
    start_date   DATE,
    end_date     DATE,
    -- CHECK comparing two columns (must be a TABLE-level constraint)
    CONSTRAINT cc_proj_dates_ck CHECK (end_date IS NULL OR end_date >= start_date)
);

-- Composite PRIMARY KEY + two foreign keys
CREATE TABLE cc_assignment (
    employee_id NUMBER(6),
    project_id  NUMBER(6),
    role        VARCHAR2(20) DEFAULT 'MEMBER',
    CONSTRAINT cc_asg_pk PRIMARY KEY (employee_id, project_id),
    -- deleting an employee deletes his/her assignments (CASCADE)
    CONSTRAINT cc_asg_emp_fk FOREIGN KEY (employee_id)
        REFERENCES cc_employee (employee_id) ON DELETE CASCADE,
    -- no ON DELETE option: a project with assignments cannot be deleted
    CONSTRAINT cc_asg_proj_fk FOREIGN KEY (project_id)
        REFERENCES cc_project (project_id)
);

-- ON DELETE SET NULL: the parking spot stays, it just becomes free
CREATE TABLE cc_parking (
    spot_no     VARCHAR2(5) CONSTRAINT cc_park_pk PRIMARY KEY,
    employee_id NUMBER(6)   CONSTRAINT cc_park_emp_uk UNIQUE,   -- one spot per employee
    CONSTRAINT cc_park_emp_fk FOREIGN KEY (employee_id)
        REFERENCES cc_employee (employee_id) ON DELETE SET NULL
);

-- Sample data
INSERT INTO cc_department VALUES (10, 'IT',      50000);
INSERT INTO cc_department VALUES (20, 'Finance', 30000);
INSERT INTO cc_department (department_id, department_name) VALUES (30, 'Marketing');  -- budget DEFAULT 0

INSERT INTO cc_employee (employee_id, full_name, email, gender, salary, department_id)
VALUES (1, 'Eric Mugisha',   'eric@auca.ac.rw',  'M', 6000, 10);
INSERT INTO cc_employee (employee_id, full_name, email, gender, salary, department_id)
VALUES (2, 'Aline Uwase',    'aline@auca.ac.rw', 'F', 5500, 10);
INSERT INTO cc_employee (employee_id, full_name, email, gender, salary, department_id)
VALUES (3, 'Jean Habimana',  'jean@auca.ac.rw',  'M', 4800, 20);
INSERT INTO cc_employee (employee_id, full_name, email, gender, salary, department_id)
VALUES (4, 'Grace Ingabire', 'grace@auca.ac.rw', 'F', 5200, 30);

INSERT INTO cc_project VALUES (100, 'E-Learning Portal', DATE '2026-01-10', DATE '2026-12-20');
INSERT INTO cc_project VALUES (200, 'Payroll Upgrade',   DATE '2026-03-01', NULL);

INSERT INTO cc_assignment VALUES (1, 100, 'LEAD');
INSERT INTO cc_assignment VALUES (2, 100, 'MEMBER');
INSERT INTO cc_assignment VALUES (1, 200, 'MEMBER');
INSERT INTO cc_assignment VALUES (3, 200, 'LEAD');

INSERT INTO cc_parking VALUES ('P01', 1);
INSERT INTO cc_parking VALUES ('P02', 3);
INSERT INTO cc_parking VALUES ('P03', NULL);

COMMIT;


-- ============================================
-- EXAMPLE 2: EACH CONSTRAINT IN ACTION
-- Run them one at a time; each one is REFUSED with the error shown.
-- ============================================

-- PRIMARY KEY  -> ORA-00001: unique constraint (CC_EMP_PK) violated
INSERT INTO cc_employee (employee_id, full_name, salary) VALUES (1, 'Duplicate', 3000);

-- NOT NULL     -> ORA-01400: cannot insert NULL into ("CC_EMPLOYEE"."FULL_NAME")
INSERT INTO cc_employee (employee_id, full_name, salary) VALUES (9, NULL, 3000);

-- UNIQUE       -> ORA-00001: unique constraint (CC_EMP_EMAIL_UK) violated
INSERT INTO cc_employee (employee_id, full_name, email, salary) VALUES (9, 'Copy', 'eric@auca.ac.rw', 3000);

-- CHECK        -> ORA-02290: check constraint (CC_EMP_SALARY_CK) violated
INSERT INTO cc_employee (employee_id, full_name, salary) VALUES (9, 'Zero Pay', 0);

-- CHECK        -> ORA-02290: check constraint (CC_EMP_GENDER_CK) violated
INSERT INTO cc_employee (employee_id, full_name, gender, salary) VALUES (9, 'Test', 'X', 3000);

-- FOREIGN KEY  -> ORA-02291: integrity constraint (CC_EMP_DEPT_FK) violated - parent key not found
INSERT INTO cc_employee (employee_id, full_name, salary, department_id) VALUES (9, 'No Dept', 3000, 99);

-- Two-column CHECK -> ORA-02290: check constraint (CC_PROJ_DATES_CK) violated
INSERT INTO cc_project VALUES (300, 'Bad Dates', DATE '2026-05-01', DATE '2026-04-01');

-- DEFAULT values are used when the column is omitted
INSERT INTO cc_employee (employee_id, full_name, salary) VALUES (9, 'Default Demo', 3000);
SELECT employee_id, full_name, hire_date, department_id FROM cc_employee WHERE employee_id = 9;
ROLLBACK;


-- ============================================
-- EXAMPLE 3: DELETE WITHOUT AN ON DELETE OPTION (restrict)
-- Project 100 still has assignments ->
-- ORA-02292: integrity constraint (CC_ASG_PROJ_FK) violated - child record found
-- ============================================
DELETE FROM cc_project WHERE project_id = 100;

-- Correct order: children first, then the parent
DELETE FROM cc_assignment WHERE project_id = 100;
DELETE FROM cc_project    WHERE project_id = 100;
ROLLBACK;


-- ============================================
-- EXAMPLE 4: ON DELETE CASCADE (several levels deep)
-- Deleting department 10 deletes:
--     employees 1 and 2            (cc_emp_dept_fk  ON DELETE CASCADE)
--     their 3 assignments          (cc_asg_emp_fk   ON DELETE CASCADE)
-- and frees parking spot P01      (cc_park_emp_fk  ON DELETE SET NULL)
-- ============================================

-- Before
SELECT 'DEPARTMENTS' AS tab, COUNT(*) AS rows_count FROM cc_department UNION ALL
SELECT 'EMPLOYEES',   COUNT(*) FROM cc_employee   UNION ALL
SELECT 'ASSIGNMENTS', COUNT(*) FROM cc_assignment UNION ALL
SELECT 'PARKING USED', COUNT(employee_id) FROM cc_parking;

DELETE FROM cc_department WHERE department_id = 10;   -- 1 row deleted ... and more!

-- After: 1 department, 2 employees, 3 assignments fewer; P01 is now free
SELECT 'DEPARTMENTS' AS tab, COUNT(*) AS rows_count FROM cc_department UNION ALL
SELECT 'EMPLOYEES',   COUNT(*) FROM cc_employee   UNION ALL
SELECT 'ASSIGNMENTS', COUNT(*) FROM cc_assignment UNION ALL
SELECT 'PARKING USED', COUNT(employee_id) FROM cc_parking;

SELECT * FROM cc_parking ORDER BY spot_no;

-- WARNING: CASCADE is powerful. One DELETE removed rows from 3 tables.
ROLLBACK;


-- ============================================
-- EXAMPLE 5: ON DELETE SET NULL alone
-- Employee 3 leaves: spot P02 stays, with employee_id = NULL.
-- (His assignment is deleted by CASCADE on cc_asg_emp_fk.)
-- ============================================
DELETE FROM cc_employee WHERE employee_id = 3;

SELECT * FROM cc_parking ORDER BY spot_no;
ROLLBACK;


-- ============================================
-- EXAMPLE 6: ADD / DROP / DISABLE / ENABLE CONSTRAINTS LATER
-- ============================================

-- Add a CHECK constraint to an existing table
ALTER TABLE cc_employee ADD CONSTRAINT cc_emp_salary_max_ck CHECK (salary <= 50000);

-- Add NOT NULL (it is changed with MODIFY)
ALTER TABLE cc_department MODIFY (budget CONSTRAINT cc_dept_budget_nn NOT NULL);

-- Disable during a big data load, then enable again
ALTER TABLE cc_employee DISABLE CONSTRAINT cc_emp_salary_ck;
ALTER TABLE cc_employee ENABLE  CONSTRAINT cc_emp_salary_ck;   -- re-checks all rows

-- ENABLE NOVALIDATE: check only NEW rows, accept existing bad rows
-- ALTER TABLE cc_employee ENABLE NOVALIDATE CONSTRAINT cc_emp_salary_ck;

-- Drop a constraint
ALTER TABLE cc_employee DROP CONSTRAINT cc_emp_salary_max_ck;

-- Change an FK to ON DELETE CASCADE: drop it and add it again
ALTER TABLE cc_assignment DROP CONSTRAINT cc_asg_proj_fk;
ALTER TABLE cc_assignment ADD CONSTRAINT cc_asg_proj_fk
    FOREIGN KEY (project_id) REFERENCES cc_project (project_id) ON DELETE CASCADE;


-- ============================================
-- EXAMPLE 7: DEFERRABLE CONSTRAINT (checked at COMMIT, not per statement)
-- Useful when rows must be inserted in the "wrong" order.
-- ============================================
ALTER TABLE cc_employee DROP CONSTRAINT cc_emp_dept_fk;
ALTER TABLE cc_employee ADD CONSTRAINT cc_emp_dept_fk
    FOREIGN KEY (department_id) REFERENCES cc_department (department_id)
    ON DELETE CASCADE
    DEFERRABLE INITIALLY IMMEDIATE;

SET CONSTRAINT cc_emp_dept_fk DEFERRED;

-- Child BEFORE parent: accepted now, checked at COMMIT
INSERT INTO cc_employee (employee_id, full_name, salary, department_id) VALUES (10, 'New Hire', 4000, 40);
INSERT INTO cc_department (department_id, department_name) VALUES (40, 'Research');
COMMIT;   -- OK: department 40 exists at commit time


-- ============================================
-- EXAMPLE 8: DROP A PARENT TABLE
-- ============================================
-- DROP TABLE cc_project;
--     -> ORA-02449: unique/primary keys in table referenced by foreign keys
-- DROP TABLE cc_project CASCADE CONSTRAINTS;
--     -> drops the table AND the foreign keys pointing to it
--        (the child rows in cc_assignment stay)


-- ============================================
-- EXAMPLE 9: CONSTRAINTS IN THE DATA DICTIONARY
-- constraint_type: P = primary key, U = unique, R = foreign key (referential),
--                  C = check / not null
-- ============================================
SELECT table_name, constraint_name, constraint_type, delete_rule,
       r_constraint_name, status, deferrable
FROM user_constraints
WHERE table_name LIKE 'CC\_%' ESCAPE '\'
ORDER BY table_name, constraint_type;

-- Columns of each constraint
SELECT constraint_name, table_name, column_name, position
FROM user_cons_columns
WHERE table_name LIKE 'CC\_%' ESCAPE '\'
ORDER BY table_name, constraint_name, position;

-- Every foreign key with parent table and delete rule
SELECT c.table_name   AS child_table,
       c.constraint_name,
       p.table_name   AS parent_table,
       c.delete_rule  -- NO ACTION / CASCADE / SET NULL
FROM user_constraints c
JOIN user_constraints p ON p.constraint_name = c.r_constraint_name
WHERE c.constraint_type = 'R'
  AND c.table_name LIKE 'CC\_%' ESCAPE '\'
ORDER BY child_table;

-- The same for the real HR schema
SELECT c.table_name AS child_table, c.constraint_name, p.table_name AS parent_table, c.delete_rule
FROM user_constraints c
JOIN user_constraints p ON p.constraint_name = c.r_constraint_name
WHERE c.constraint_type = 'R'
  AND c.table_name IN ('EMPLOYEES', 'DEPARTMENTS', 'JOB_HISTORY', 'LOCATIONS', 'COUNTRIES')
ORDER BY child_table;


-- ============================================
-- EXERCISES
-- ============================================

-- EX1:
-- Create a table CC_STUDENT (reg_no PK, names NOT NULL, email UNIQUE,
-- age CHECK between 16 and 80, faculty DEFAULT 'IT').

-- EX2:
-- Create CC_COURSE and CC_ENROLLMENT (reg_no, course_code) with a composite
-- primary key. Deleting a student must delete his/her enrollments; deleting a
-- course that has enrollments must be refused. Test both.

-- EX3:
-- Change the foreign key of CC_PARKING to ON DELETE CASCADE and explain
-- the difference when employee 1 is deleted.

-- EX4:
-- Write a query listing every CHECK constraint of your schema with its
-- condition (column SEARCH_CONDITION of USER_CONSTRAINTS).

-- EX5:
-- Disable CC_EMP_SALARY_CK, insert an employee with salary 0, then try to
-- ENABLE the constraint. What happens? How can ENABLE NOVALIDATE help?


-- ============================================
-- CLEAN UP
-- ============================================
-- DROP TABLE cc_assignment PURGE;
-- DROP TABLE cc_parking    PURGE;
-- DROP TABLE cc_employee   PURGE;
-- DROP TABLE cc_project    PURGE;
-- DROP TABLE cc_department PURGE;
