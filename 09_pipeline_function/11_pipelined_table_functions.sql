/* ============================================================
   TITLE: Pipelined Table Functions in PL/SQL

   WHAT IS A PIPELINED FUNCTION?
   A function that returns a COLLECTION, but sends ("pipes") each row
   to the caller AS SOON AS IT IS READY with  PIPE ROW(...),
   instead of building the whole collection in memory first.
   The caller uses it like a table:

       SELECT * FROM TABLE(my_function(...));

   NORMAL TABLE FUNCTION              PIPELINED FUNCTION
   ---------------------------------  ---------------------------------
   builds the full collection, then   returns rows one by one
   returns it                         (first rows arrive immediately)
   memory grows with the result       memory stays small
   RETURN my_collection;              PIPE ROW(x); ... RETURN;

   RULES:
   1. The return type must be a COLLECTION type (nested table or
      VARRAY) that SQL can see: created with CREATE TYPE, or declared
      in a package specification.
   2. Add the keyword PIPELINED after the return type.
   3. Send each row with PIPE ROW(value).
   4. End with a plain RETURN;  (no value).

   CONTENT:
   Example 1 - simple number generator
   Example 2 - employee salary report (object type + BULK COLLECT)
   Example 3 - transforming a cursor passed as a parameter (CURSOR(...))
   Example 4 - stopping early and NO_DATA_NEEDED
   ============================================================ */


/* ============================================================
   STEP 0: CLEAN START
   Functions first, then the types they depend on.
   ============================================================ */
BEGIN
    FOR o IN (
        SELECT object_name, object_type
        FROM user_objects
        WHERE object_name IN ('FN_GENERATE_NUMBERS', 'FN_EMP_SALARY_REPORT',
                              'FN_SALARY_BAND',
                              'T_NUMBER_TAB', 'T_EMP_SALARY_TAB', 'T_EMP_SALARY_ROW',
                              'T_SALARY_BAND_TAB', 'T_SALARY_BAND_ROW')
        ORDER BY CASE object_type WHEN 'FUNCTION' THEN 1 ELSE 2 END,
                 CASE WHEN object_name LIKE '%\_TAB' ESCAPE '\' THEN 1 ELSE 2 END
    ) LOOP
        EXECUTE IMMEDIATE 'DROP ' || o.object_type || ' '
                          || DBMS_ASSERT.ENQUOTE_NAME(o.object_name)
                          || CASE o.object_type WHEN 'TYPE' THEN ' FORCE' END;
    END LOOP;
END;
/


/* ============================================================
   EXAMPLE 1: SIMPLE NUMBER GENERATOR
   Returns the numbers p_start .. p_end as rows.
   ============================================================ */

-- SQL-level collection type (required for the return type)
CREATE OR REPLACE TYPE t_number_tab AS TABLE OF NUMBER;
/

CREATE OR REPLACE FUNCTION fn_generate_numbers (
    p_start IN NUMBER,
    p_end   IN NUMBER
) RETURN t_number_tab PIPELINED
IS
BEGIN
    FOR i IN p_start .. p_end LOOP
        PIPE ROW (i);              -- send one row to the caller now
    END LOOP;
    RETURN;                        -- nothing after RETURN: rows are already sent
END fn_generate_numbers;
/

-- Use it like a table. A collection of scalars has one column: COLUMN_VALUE
SELECT column_value AS num
FROM TABLE(fn_generate_numbers(1, 10));

-- It can be joined, filtered and aggregated like any table
SELECT column_value AS num,
       column_value * column_value AS square
FROM TABLE(fn_generate_numbers(1, 5))
WHERE MOD(column_value, 2) = 1;

-- Oracle 18c and later: the TABLE( ) keyword is optional
-- SELECT * FROM fn_generate_numbers(1, 10);


/* ============================================================
   EXAMPLE 2: EMPLOYEE SALARY REPORT
   Returns several columns per row -> use an OBJECT type for the row
   and a TABLE OF that object for the collection.

   Each row: employee, department, monthly salary, annual salary,
   tax rate, tax and net monthly salary.
   Tax bands (demo): > 10000 -> 30%, > 5000 -> 20%, otherwise 10%.
   ============================================================ */

-- 2.1 Row type (one row of the result)
CREATE OR REPLACE TYPE t_emp_salary_row AS OBJECT (
    employee_id     NUMBER(6),
    full_name       VARCHAR2(50),
    department_name VARCHAR2(30),
    salary          NUMBER(8,2),
    annual_salary   NUMBER(10,2),
    tax_rate_pct    NUMBER(3),
    tax_amount      NUMBER(8,2),
    net_salary      NUMBER(8,2)
);
/

-- 2.2 Collection type (the whole result)
CREATE OR REPLACE TYPE t_emp_salary_tab AS TABLE OF t_emp_salary_row;
/

-- 2.3 The pipelined function
--     p_department_id = NULL -> all employees
CREATE OR REPLACE FUNCTION fn_emp_salary_report (
    p_department_id IN NUMBER DEFAULT NULL
) RETURN t_emp_salary_tab PIPELINED
IS
    CURSOR c_emp IS
        SELECT e.employee_id,
               e.first_name || ' ' || e.last_name AS full_name,
               NVL(d.department_name, 'No department') AS department_name,
               e.salary
        FROM employees e
        LEFT JOIN departments d ON d.department_id = e.department_id
        WHERE p_department_id IS NULL
           OR e.department_id = p_department_id
        ORDER BY e.employee_id;

    TYPE t_emp_list IS TABLE OF c_emp%ROWTYPE;
    v_emps     t_emp_list;
    v_rate     NUMBER;
    v_tax      NUMBER;
BEGIN
    OPEN c_emp;
    LOOP
        -- Read 100 rows at a time (fast), but pipe them one by one
        FETCH c_emp BULK COLLECT INTO v_emps LIMIT 100;
        EXIT WHEN v_emps.COUNT = 0;

        FOR i IN 1 .. v_emps.COUNT LOOP
            v_rate := CASE
                          WHEN v_emps(i).salary > 10000 THEN 30
                          WHEN v_emps(i).salary > 5000  THEN 20
                          ELSE 10
                      END;
            v_tax := ROUND(v_emps(i).salary * v_rate / 100, 2);

            PIPE ROW (
                t_emp_salary_row(
                    v_emps(i).employee_id,
                    v_emps(i).full_name,
                    v_emps(i).department_name,
                    v_emps(i).salary,
                    v_emps(i).salary * 12,
                    v_rate,
                    v_tax,
                    v_emps(i).salary - v_tax
                )
            );
        END LOOP;
    END LOOP;
    CLOSE c_emp;
    RETURN;
EXCEPTION
    -- Raised when the caller stops reading early (see Example 4).
    -- Just tidy up; it is not a real error.
    WHEN NO_DATA_NEEDED THEN
        IF c_emp%ISOPEN THEN
            CLOSE c_emp;
        END IF;
END fn_emp_salary_report;
/

-- 2.4 Use it
-- All employees of department 60 (IT)
SELECT *
FROM TABLE(fn_emp_salary_report(60));

-- All employees, only selected columns, filtered and sorted
SELECT employee_id, full_name, department_name, salary, tax_amount, net_salary
FROM TABLE(fn_emp_salary_report())
WHERE tax_rate_pct = 30
ORDER BY net_salary DESC;

-- Totals per department, computed on top of the function result
SELECT department_name,
       COUNT(*)        AS employees,
       SUM(salary)     AS total_salary,
       SUM(tax_amount) AS total_tax,
       SUM(net_salary) AS total_net
FROM TABLE(fn_emp_salary_report())
GROUP BY department_name
ORDER BY total_salary DESC;

-- Join the function result with a real table
SELECT r.full_name, r.net_salary, j.job_title
FROM TABLE(fn_emp_salary_report(90)) r
JOIN employees e ON e.employee_id = r.employee_id
JOIN jobs j      ON j.job_id      = e.job_id;

-- Use it from PL/SQL as well
BEGIN
    FOR r IN (SELECT * FROM TABLE(fn_emp_salary_report(60))) LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(r.full_name, 22) || ' salary: ' || LPAD(r.salary, 8)
            || '  tax ' || r.tax_rate_pct || '%: ' || LPAD(r.tax_amount, 8)
            || '  net: ' || LPAD(r.net_salary, 8));
    END LOOP;
END;
/


/* ============================================================
   EXAMPLE 3: TRANSFORMING A CURSOR (data pipeline)
   The INPUT is itself a query, passed with CURSOR( ... ).
   The function reads it row by row and pipes out transformed rows.
   Any query with (employee_id, salary) can be fed in.
   ============================================================ */

CREATE OR REPLACE TYPE t_salary_band_row AS OBJECT (
    employee_id NUMBER(6),
    salary      NUMBER(8,2),
    salary_band VARCHAR2(10)
);
/

CREATE OR REPLACE TYPE t_salary_band_tab AS TABLE OF t_salary_band_row;
/

CREATE OR REPLACE FUNCTION fn_salary_band (
    p_cur IN SYS_REFCURSOR
) RETURN t_salary_band_tab PIPELINED
IS
    v_id     employees.employee_id%TYPE;
    v_salary employees.salary%TYPE;
BEGIN
    LOOP
        FETCH p_cur INTO v_id, v_salary;
        EXIT WHEN p_cur%NOTFOUND;

        PIPE ROW (
            t_salary_band_row(
                v_id,
                v_salary,
                CASE
                    WHEN v_salary >= 15000 THEN 'EXECUTIVE'
                    WHEN v_salary >= 8000  THEN 'HIGH'
                    WHEN v_salary >= 4000  THEN 'MEDIUM'
                    ELSE 'LOW'
                END
            )
        );
    END LOOP;
    CLOSE p_cur;
    RETURN;
EXCEPTION
    WHEN NO_DATA_NEEDED THEN
        IF p_cur%ISOPEN THEN
            CLOSE p_cur;
        END IF;
END fn_salary_band;
/

-- Feed it a query with CURSOR( ... )
SELECT *
FROM TABLE(fn_salary_band(CURSOR(
         SELECT employee_id, salary FROM employees WHERE department_id IN (50, 80)
     )));

-- How many employees in each band (whole company)
SELECT salary_band, COUNT(*) AS employees, MIN(salary) AS min_sal, MAX(salary) AS max_sal
FROM TABLE(fn_salary_band(CURSOR(SELECT employee_id, salary FROM employees)))
GROUP BY salary_band
ORDER BY MIN(salary) DESC;


/* ============================================================
   EXAMPLE 4: STOPPING EARLY (the real advantage of pipelining)
   Because rows are piped one at a time, Oracle can stop the function
   as soon as it has enough rows. The function is NOT run to the end:
   Oracle raises NO_DATA_NEEDED inside it, which our handler uses to
   close the cursor.
   ============================================================ */

-- Only the first 5 rows are produced, even though the loop goes to 1 000 000
SELECT column_value
FROM TABLE(fn_generate_numbers(1, 1000000))
FETCH FIRST 5 ROWS ONLY;

-- Same for the report: only 3 employees are calculated
SELECT employee_id, full_name, net_salary
FROM TABLE(fn_emp_salary_report())
FETCH FIRST 3 ROWS ONLY;


/* ============================================================
   CHECK THE OBJECTS
   ============================================================ */
SELECT object_name, object_type, status
FROM user_objects
WHERE object_name IN ('FN_GENERATE_NUMBERS', 'FN_EMP_SALARY_REPORT', 'FN_SALARY_BAND',
                      'T_NUMBER_TAB', 'T_EMP_SALARY_ROW', 'T_EMP_SALARY_TAB',
                      'T_SALARY_BAND_ROW', 'T_SALARY_BAND_TAB')
ORDER BY object_type, object_name;

-- PIPELINED = 'YES' confirms the functions are pipelined
SELECT object_name, pipelined
FROM user_procedures
WHERE object_name IN ('FN_GENERATE_NUMBERS', 'FN_EMP_SALARY_REPORT', 'FN_SALARY_BAND');


/* ============================================================
   CLEAN UP (functions first, then row/collection types)
   ============================================================ */
-- DROP FUNCTION fn_generate_numbers;
-- DROP FUNCTION fn_emp_salary_report;
-- DROP FUNCTION fn_salary_band;
-- DROP TYPE t_number_tab;
-- DROP TYPE t_emp_salary_tab;
-- DROP TYPE t_emp_salary_row;
-- DROP TYPE t_salary_band_tab;
-- DROP TYPE t_salary_band_row;


/* ============================================================
   KEY POINTS
   - RETURN <collection type> PIPELINED  +  PIPE ROW(x)  +  RETURN;
   - The collection type must be visible to SQL (CREATE TYPE or a
     package specification).
   - Several columns -> OBJECT type for the row, TABLE OF it for the result.
   - Query with  SELECT ... FROM TABLE(fn(...))  (TABLE optional in 18c+).
   - Rows reach the caller immediately; memory stays small.
   - Pass a query in with CURSOR(SELECT ...) to build data pipelines.
   - Handle NO_DATA_NEEDED to clean up when the caller stops early.
   - A pipelined function cannot be called directly in PL/SQL
     (v := fn(...)); always select FROM it.
   ============================================================ */
