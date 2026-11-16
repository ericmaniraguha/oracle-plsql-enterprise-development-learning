/* ============================================================
   TITLE: Pipelined Function - Split a Delimited String into Rows

   QUESTION:
   An application sends a list of department IDs as ONE string,
   for example '10,20,60'. Write a pipelined function that turns the
   string into rows so it can be used directly in SQL:

       SELECT column_value FROM TABLE(fn_split_string('10,20,60'));

       COLUMN_VALUE
       ------------
       10
       20
       60

   Then use it to list the employees of those departments.

   REMINDER (see 00_introduction_pipelined_function_basics.sql):
   RETURN <collection type> PIPELINED  ->  PIPE ROW(x)  ->  RETURN;
   ============================================================ */


/* ============================================================
   STEP 0: CLEAN START (function first, then the type)
   ============================================================ */
BEGIN
    EXECUTE IMMEDIATE 'DROP FUNCTION fn_split_string';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -4043 THEN RAISE; END IF;   -- ORA-04043: does not exist
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TYPE t_varchar_tab FORCE';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -4043 THEN RAISE; END IF;
END;
/


/* ============================================================
   STEP 1: COLLECTION TYPE (one text value per row)
   ============================================================ */
CREATE OR REPLACE TYPE t_varchar_tab AS TABLE OF VARCHAR2(4000);
/


/* ============================================================
   STEP 2: THE PIPELINED FUNCTION
   - Walks through the string with INSTR / SUBSTR.
   - Pipes every piece (trimmed) as soon as it is found.
   - Empty pieces ('10,,20') are skipped.
   ============================================================ */
CREATE OR REPLACE FUNCTION fn_split_string (
    p_text      IN VARCHAR2,
    p_delimiter IN VARCHAR2 DEFAULT ','
) RETURN t_varchar_tab PIPELINED
IS
    v_start PLS_INTEGER := 1;     -- where the current piece starts
    v_pos   PLS_INTEGER;          -- position of the next delimiter
    v_piece VARCHAR2(4000);
BEGIN
    IF p_delimiter IS NULL THEN
        RAISE_APPLICATION_ERROR(-20100, 'Delimiter must not be NULL.');
    END IF;

    IF p_text IS NULL THEN
        RETURN;                   -- nothing to split: zero rows
    END IF;

    LOOP
        v_pos := INSTR(p_text, p_delimiter, v_start);

        IF v_pos = 0 THEN
            v_piece := TRIM(SUBSTR(p_text, v_start));                  -- last piece
        ELSE
            v_piece := TRIM(SUBSTR(p_text, v_start, v_pos - v_start));
        END IF;

        IF v_piece IS NOT NULL THEN
            PIPE ROW (v_piece);
        END IF;

        EXIT WHEN v_pos = 0;
        v_start := v_pos + LENGTH(p_delimiter);
    END LOOP;

    RETURN;
END fn_split_string;
/


/* ============================================================
   STEP 3: TESTS
   ============================================================ */

-- 3.1 Basic split
SELECT column_value AS department_id
FROM TABLE(fn_split_string('10,20,60'));

-- 3.2 Another delimiter, spaces and empty pieces are handled
SELECT ROWNUM AS position, column_value AS fruit
FROM TABLE(fn_split_string(' apple ; banana ;; mango ', ';'));

-- 3.3 Multi-character delimiter
SELECT column_value AS skill
FROM TABLE(fn_split_string('SQL || PL/SQL || Java', '||'));

-- 3.4 NULL text -> no rows
SELECT COUNT(*) AS rows_returned
FROM TABLE(fn_split_string(NULL));


/* ============================================================
   STEP 4: REAL USE - EMPLOYEES OF A LIST OF DEPARTMENTS
   ============================================================ */

-- 4.1 Filter with IN (...)
SELECT e.employee_id,
       e.first_name || ' ' || e.last_name AS full_name,
       e.department_id,
       e.salary
FROM employees e
WHERE e.department_id IN (
          SELECT TO_NUMBER(column_value)
          FROM TABLE(fn_split_string('10,20,60'))
      )
ORDER BY e.department_id, e.employee_id;

-- 4.2 Join, to show requested IDs that have NO department (e.g. 999)
SELECT TO_NUMBER(s.column_value)                AS requested_id,
       NVL(d.department_name, '** not found **') AS department_name
FROM TABLE(fn_split_string('10, 60, 999')) s
LEFT JOIN departments d ON d.department_id = TO_NUMBER(s.column_value)
ORDER BY requested_id;

-- 4.3 Inside PL/SQL: a procedure that receives the list as a string
CREATE OR REPLACE PROCEDURE prc_show_departments (p_dept_list IN VARCHAR2)
IS
BEGIN
    FOR r IN (
        SELECT d.department_id, d.department_name, COUNT(e.employee_id) AS staff
        FROM departments d
        LEFT JOIN employees e ON e.department_id = d.department_id
        WHERE d.department_id IN (
                  SELECT TO_NUMBER(column_value)
                  FROM TABLE(fn_split_string(p_dept_list))
              )
        GROUP BY d.department_id, d.department_name
        ORDER BY d.department_id
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(r.department_id, 6) || RPAD(r.department_name, 25)
            || r.staff || ' employee(s)');
    END LOOP;
END prc_show_departments;
/

SET SERVEROUTPUT ON;
EXEC prc_show_departments('10,20,50,60,90');


/* ============================================================
   CLEAN UP (procedure and function first, then the type)
   ============================================================ */
-- DROP PROCEDURE prc_show_departments;
-- DROP FUNCTION fn_split_string;
-- DROP TYPE t_varchar_tab;
