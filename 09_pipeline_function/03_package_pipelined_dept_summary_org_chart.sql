/* ============================================================
   TITLE: Pipelined Functions inside a PACKAGE
          (Department Summary + Organisation Chart)

   WHAT IS NEW HERE?
   In the previous examples the row and collection types were created
   with CREATE TYPE (schema-level objects).
   Since Oracle 12c, a pipelined function in a PACKAGE can use
   RECORD and TABLE types declared in the PACKAGE SPECIFICATION:
   no CREATE TYPE needed, and %TYPE can be used for the columns.

   QUESTION:
   Create a package PKG_HR_PIPE with two pipelined functions:
   1. FN_DEPT_SUMMARY(p_min_employees)
        one row per department: number of employees, total and average
        salary, and the best-paid employee. Only departments with at
        least p_min_employees employees are returned.
   2. FN_TEAM(p_manager_id)
        every employee who reports (directly or indirectly) to the
        given manager, with level and reporting path (organisation chart).
   ============================================================ */


/* ============================================================
   STEP 1: PACKAGE SPECIFICATION - types + function headers
   ============================================================ */
CREATE OR REPLACE PACKAGE pkg_hr_pipe AS

    -- ---------- 1. Department summary ----------
    TYPE r_dept_summary IS RECORD (
        department_id   departments.department_id%TYPE,
        department_name departments.department_name%TYPE,
        employee_count  NUMBER,
        total_salary    NUMBER,
        avg_salary      NUMBER,
        best_paid       VARCHAR2(50),
        best_salary     employees.salary%TYPE
    );
    TYPE t_dept_summary IS TABLE OF r_dept_summary;

    FUNCTION fn_dept_summary (
        p_min_employees IN NUMBER DEFAULT 1
    ) RETURN t_dept_summary PIPELINED;

    -- ---------- 2. Organisation chart ----------
    TYPE r_team_member IS RECORD (
        org_level      NUMBER,
        employee_id    employees.employee_id%TYPE,
        employee_name  VARCHAR2(60),       -- indented by level
        job_id         employees.job_id%TYPE,
        manager_id     employees.manager_id%TYPE,
        salary         employees.salary%TYPE,
        reporting_path VARCHAR2(4000)
    );
    TYPE t_team IS TABLE OF r_team_member;

    FUNCTION fn_team (
        p_manager_id IN employees.employee_id%TYPE
    ) RETURN t_team PIPELINED;

END pkg_hr_pipe;
/


/* ============================================================
   STEP 2: PACKAGE BODY
   ============================================================ */
CREATE OR REPLACE PACKAGE BODY pkg_hr_pipe AS

    /* --------------------------------------------------------
       1. Department summary
       KEEP (DENSE_RANK LAST ORDER BY salary) picks the name that
       goes with the highest salary in each department.
       -------------------------------------------------------- */
    FUNCTION fn_dept_summary (
        p_min_employees IN NUMBER DEFAULT 1
    ) RETURN t_dept_summary PIPELINED
    IS
        v_row r_dept_summary;
    BEGIN
        FOR r IN (
            SELECT d.department_id,
                   d.department_name,
                   COUNT(e.employee_id)       AS employee_count,
                   NVL(SUM(e.salary), 0)      AS total_salary,
                   ROUND(AVG(e.salary), 2)    AS avg_salary,
                   MAX(e.first_name || ' ' || e.last_name)
                       KEEP (DENSE_RANK LAST ORDER BY e.salary NULLS FIRST) AS best_paid,
                   MAX(e.salary)              AS best_salary
            FROM departments d
            LEFT JOIN employees e ON e.department_id = d.department_id
            GROUP BY d.department_id, d.department_name
            HAVING COUNT(e.employee_id) >= p_min_employees
            ORDER BY d.department_id
        ) LOOP
            v_row.department_id   := r.department_id;
            v_row.department_name := r.department_name;
            v_row.employee_count  := r.employee_count;
            v_row.total_salary    := r.total_salary;
            v_row.avg_salary      := r.avg_salary;
            v_row.best_paid       := r.best_paid;
            v_row.best_salary     := r.best_salary;

            PIPE ROW (v_row);      -- a RECORD can be piped directly
        END LOOP;
        RETURN;
    END fn_dept_summary;

    /* --------------------------------------------------------
       2. Organisation chart (hierarchical query with CONNECT BY)
       -------------------------------------------------------- */
    FUNCTION fn_team (
        p_manager_id IN employees.employee_id%TYPE
    ) RETURN t_team PIPELINED
    IS
        v_row r_team_member;
    BEGIN
        FOR r IN (
            SELECT LEVEL AS org_level,
                   employee_id,
                   LPAD(' ', (LEVEL - 1) * 3) || first_name || ' ' || last_name AS employee_name,
                   job_id,
                   manager_id,
                   salary,
                   LTRIM(SYS_CONNECT_BY_PATH(last_name, ' > '), ' > ') AS reporting_path
            FROM employees
            START WITH employee_id = p_manager_id
            CONNECT BY PRIOR employee_id = manager_id
            ORDER SIBLINGS BY last_name
        ) LOOP
            v_row.org_level      := r.org_level;
            v_row.employee_id    := r.employee_id;
            v_row.employee_name  := r.employee_name;
            v_row.job_id         := r.job_id;
            v_row.manager_id     := r.manager_id;
            v_row.salary         := r.salary;
            v_row.reporting_path := r.reporting_path;

            PIPE ROW (v_row);
        END LOOP;
        RETURN;
    END fn_team;

END pkg_hr_pipe;
/


/* ============================================================
   STEP 3: USE THE PACKAGE FUNCTIONS
   ============================================================ */

-- 3.1 All departments that have at least one employee
SELECT *
FROM TABLE(pkg_hr_pipe.fn_dept_summary());

-- 3.2 Only "big" departments (5 employees or more)
SELECT department_name, employee_count, total_salary, avg_salary, best_paid
FROM TABLE(pkg_hr_pipe.fn_dept_summary(5))
ORDER BY total_salary DESC;

-- 3.3 Departments with NO employees (p_min_employees = 0, then filter)
SELECT department_id, department_name
FROM TABLE(pkg_hr_pipe.fn_dept_summary(0))
WHERE employee_count = 0;

-- 3.4 Whole company, starting from the president (employee 100)
SELECT org_level, employee_name, job_id, salary
FROM TABLE(pkg_hr_pipe.fn_team(100));

-- 3.5 Team of manager 101 (Kochhar) with the reporting path
SELECT employee_id, employee_name, reporting_path
FROM TABLE(pkg_hr_pipe.fn_team(101));

-- 3.6 Combine: size and salary cost of each VP's team
SELECT e.employee_id,
       e.first_name || ' ' || e.last_name AS vp_name,
       (SELECT COUNT(*) - 1  FROM TABLE(pkg_hr_pipe.fn_team(e.employee_id))) AS team_size,
       (SELECT SUM(salary)   FROM TABLE(pkg_hr_pipe.fn_team(e.employee_id))) AS team_salary_cost
FROM employees e
WHERE e.job_id = 'AD_VP';


/* ============================================================
   STEP 4: CHECK
   ============================================================ */
SELECT object_name, procedure_name, pipelined
FROM user_procedures
WHERE object_name = 'PKG_HR_PIPE'
  AND procedure_name IS NOT NULL;


/* ============================================================
   CLEAN UP
   ============================================================ */
-- DROP PACKAGE pkg_hr_pipe;


/* ============================================================
   KEY POINTS
   - Types for a pipelined function can live in the PACKAGE SPEC
     (RECORD + TABLE OF record) - no CREATE TYPE needed (12c+).
   - A whole RECORD can be piped: PIPE ROW(v_row).
   - Call with the package prefix: TABLE(pkg_hr_pipe.fn_team(100)).
   - Types declared in the package BODY are NOT visible to SQL:
     they must be in the specification.
   ============================================================ */
