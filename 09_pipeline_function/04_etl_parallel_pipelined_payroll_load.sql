/* ============================================================
   TITLE: Pipelined Function for ETL - Load a Payroll Staging Table
          (CURSOR input, validation, PARALLEL_ENABLE, INSERT ... SELECT)

   ETL = Extract -> Transform -> Load
     Extract   : a query on EMPLOYEES, passed in with CURSOR( ... )
     Transform : a pipelined function that validates every employee
                 and calculates gross, deductions and net pay
     Load      : ONE  INSERT INTO ... SELECT ... FROM TABLE(fn(...))

   QUESTION:
   Load the November payroll into PAYROLL_STAGE. For each employee:
     - gross pay   = salary + commission (salary * commission_pct)
     - pension     = 6% of gross            (demo rate)
     - income tax  = 30% / 20% / 10% of gross (> 10000 / > 5000 / other)
     - net pay     = gross - pension - tax
   Employees who cannot be paid are still loaded, but with
   STATUS = 'REJECTED' and the reason (no salary, no department),
   so HR can fix them.

   WHY A PIPELINED FUNCTION FOR ETL?
   - Rows flow straight from the source query into the INSERT:
     no big collection in memory, no row-by-row INSERT in a loop.
   - PARALLEL_ENABLE lets Oracle split the work over several parallel
     processes when the statement runs in parallel (big tables).
   ============================================================ */


/* ============================================================
   STEP 0: CLEAN START (function, table, then types)
   ============================================================ */
BEGIN
    FOR o IN (SELECT object_name, object_type FROM user_objects
              WHERE object_name IN ('FN_TRANSFORM_PAYROLL', 'PAYROLL_STAGE',
                                    'T_PAYROLL_TAB', 'T_PAYROLL_ROW')
                AND object_type IN ('FUNCTION', 'TABLE', 'TYPE')
              ORDER BY DECODE(object_name, 'FN_TRANSFORM_PAYROLL', 1,
                                           'PAYROLL_STAGE', 2,
                                           'T_PAYROLL_TAB', 3, 4)) LOOP
        EXECUTE IMMEDIATE 'DROP ' || o.object_type || ' '
                          || DBMS_ASSERT.ENQUOTE_NAME(o.object_name)
                          || CASE o.object_type WHEN 'TABLE' THEN ' PURGE' END;
    END LOOP;
END;
/


/* ============================================================
   STEP 1: TARGET (STAGING) TABLE
   ============================================================ */
CREATE TABLE payroll_stage (
    pay_period     VARCHAR2(7),       -- 'YYYY-MM'
    employee_id    NUMBER(6),
    full_name      VARCHAR2(50),
    department_id  NUMBER(4),
    gross_pay      NUMBER(10,2),
    pension        NUMBER(10,2),
    income_tax     NUMBER(10,2),
    net_pay        NUMBER(10,2),
    status         VARCHAR2(10),      -- VALID / REJECTED
    reject_reason  VARCHAR2(200),
    loaded_at      TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT payroll_stage_pk PRIMARY KEY (pay_period, employee_id)
);


/* ============================================================
   STEP 2: ROW TYPE + COLLECTION TYPE (same columns as the INSERT)
   ============================================================ */
CREATE OR REPLACE TYPE t_payroll_row AS OBJECT (
    pay_period     VARCHAR2(7),
    employee_id    NUMBER(6),
    full_name      VARCHAR2(50),
    department_id  NUMBER(4),
    gross_pay      NUMBER(10,2),
    pension        NUMBER(10,2),
    income_tax     NUMBER(10,2),
    net_pay        NUMBER(10,2),
    status         VARCHAR2(10),
    reject_reason  VARCHAR2(200)
);
/

CREATE OR REPLACE TYPE t_payroll_tab AS TABLE OF t_payroll_row;
/


/* ============================================================
   STEP 3: THE TRANSFORM FUNCTION
   Input cursor columns (in this order):
       employee_id, first_name, last_name, department_id,
       salary, commission_pct

   PARALLEL_ENABLE (PARTITION p_source BY ANY):
       Oracle may give each parallel process any subset of rows.
       Fine here, because every row is processed independently.
   ============================================================ */
CREATE OR REPLACE FUNCTION fn_transform_payroll (
    p_source     IN SYS_REFCURSOR,
    p_pay_period IN VARCHAR2
) RETURN t_payroll_tab PIPELINED
  PARALLEL_ENABLE (PARTITION p_source BY ANY)
IS
    c_pension_rate CONSTANT NUMBER := 0.06;

    v_emp_id    employees.employee_id%TYPE;
    v_first     employees.first_name%TYPE;
    v_last      employees.last_name%TYPE;
    v_dept      employees.department_id%TYPE;
    v_salary    employees.salary%TYPE;
    v_comm      employees.commission_pct%TYPE;

    v_gross     NUMBER;
    v_pension   NUMBER;
    v_tax       NUMBER;
    v_reason    VARCHAR2(200);
BEGIN
    LOOP
        FETCH p_source INTO v_emp_id, v_first, v_last, v_dept, v_salary, v_comm;
        EXIT WHEN p_source%NOTFOUND;

        -- ---------- Validate ----------
        v_reason := NULL;
        IF v_salary IS NULL OR v_salary <= 0 THEN
            v_reason := 'Missing or invalid salary. ';
        END IF;
        IF v_dept IS NULL THEN
            v_reason := v_reason || 'No department assigned. ';
        END IF;

        IF v_reason IS NOT NULL THEN
            -- Rejected rows are still piped, with the reason
            PIPE ROW (t_payroll_row(p_pay_period, v_emp_id, v_first || ' ' || v_last,
                                    v_dept, NULL, NULL, NULL, NULL,
                                    'REJECTED', TRIM(v_reason)));
        ELSE
            -- ---------- Transform ----------
            v_gross   := ROUND(v_salary * (1 + NVL(v_comm, 0)), 2);
            v_pension := ROUND(v_gross * c_pension_rate, 2);
            v_tax     := ROUND(v_gross * CASE
                                             WHEN v_gross > 10000 THEN 0.30
                                             WHEN v_gross > 5000  THEN 0.20
                                             ELSE 0.10
                                         END, 2);

            PIPE ROW (t_payroll_row(p_pay_period, v_emp_id, v_first || ' ' || v_last,
                                    v_dept, v_gross, v_pension, v_tax,
                                    v_gross - v_pension - v_tax,
                                    'VALID', NULL));
        END IF;
    END LOOP;

    CLOSE p_source;
    RETURN;
EXCEPTION
    WHEN NO_DATA_NEEDED THEN
        IF p_source%ISOPEN THEN CLOSE p_source; END IF;
END fn_transform_payroll;
/


/* ============================================================
   STEP 4: PREVIEW THE TRANSFORMATION (nothing is loaded yet)
   ============================================================ */
SELECT employee_id, full_name, gross_pay, pension, income_tax, net_pay, status, reject_reason
FROM TABLE(fn_transform_payroll(
         CURSOR(SELECT employee_id, first_name, last_name, department_id,
                       salary, commission_pct
                FROM employees
                WHERE department_id = 80 OR department_id IS NULL),
         '2026-11'))
FETCH FIRST 10 ROWS ONLY;


/* ============================================================
   STEP 5: LOAD - ONE SET-BASED INSERT
   ============================================================ */
INSERT INTO payroll_stage
    (pay_period, employee_id, full_name, department_id,
     gross_pay, pension, income_tax, net_pay, status, reject_reason)
SELECT pay_period, employee_id, full_name, department_id,
       gross_pay, pension, income_tax, net_pay, status, reject_reason
FROM TABLE(fn_transform_payroll(
         CURSOR(SELECT employee_id, first_name, last_name, department_id,
                       salary, commission_pct
                FROM employees),
         '2026-11'));

COMMIT;

-- For very large tables the same INSERT can run in parallel:
-- ALTER SESSION ENABLE PARALLEL DML;
-- INSERT /*+ APPEND PARALLEL(payroll_stage, 4) */ INTO payroll_stage (...)
-- SELECT ... FROM TABLE(fn_transform_payroll(
--            CURSOR(SELECT /*+ PARALLEL(e, 4) */ ... FROM employees e), '2026-11'));
-- COMMIT;


/* ============================================================
   STEP 6: CHECK THE LOAD
   ============================================================ */

-- 6.1 Load summary
SELECT status,
       COUNT(*)        AS employees,
       SUM(gross_pay)  AS total_gross,
       SUM(pension)    AS total_pension,
       SUM(income_tax) AS total_tax,
       SUM(net_pay)    AS total_net
FROM payroll_stage
WHERE pay_period = '2026-11'
GROUP BY status;

-- 6.2 Rows HR must fix (e.g. Kimberely Grant has no department)
SELECT employee_id, full_name, reject_reason
FROM payroll_stage
WHERE pay_period = '2026-11'
  AND status = 'REJECTED';

-- 6.3 Payroll cost per department
SELECT p.department_id,
       d.department_name,
       COUNT(*)       AS paid_employees,
       SUM(p.net_pay) AS total_net_pay
FROM payroll_stage p
JOIN departments d ON d.department_id = p.department_id
WHERE p.pay_period = '2026-11'
  AND p.status = 'VALID'
GROUP BY p.department_id, d.department_name
ORDER BY total_net_pay DESC;

-- 6.4 The function is pipelined AND parallel-enabled
SELECT object_name, pipelined, parallel
FROM user_procedures
WHERE object_name = 'FN_TRANSFORM_PAYROLL';


/* ============================================================
   CLEAN UP (function and table first, then the types)
   ============================================================ */
-- DROP FUNCTION fn_transform_payroll;
-- DROP TABLE payroll_stage PURGE;
-- DROP TYPE t_payroll_tab;
-- DROP TYPE t_payroll_row;


/* ============================================================
   KEY POINTS
   - A pipelined function can take a query as input: CURSOR(SELECT ...).
   - INSERT INTO target SELECT ... FROM TABLE(fn(CURSOR(...)))
     = a full ETL in one set-based statement.
   - Invalid rows can be piped with a status/reason instead of failing
     the whole load.
   - PARALLEL_ENABLE (PARTITION <cursor param> BY ANY) allows Oracle to
     run the function in several parallel processes.
     (BY HASH / BY RANGE require a strongly typed REF CURSOR.)
   ============================================================ */
