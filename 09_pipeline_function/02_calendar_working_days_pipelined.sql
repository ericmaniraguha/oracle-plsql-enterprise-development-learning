/* ============================================================
   TITLE: Pipelined Function - Calendar Generator & Working Days

   QUESTION:
   HR needs a calendar to count working days (Monday-Friday).
   Write a pipelined function FN_CALENDAR(p_from, p_to) that returns
   ONE ROW PER DAY between the two dates with:
     - the date
     - the day name (MON, TUE, ...)
     - the ISO week number
     - a flag: is it a weekend? (Y/N)

   Then use it to:
     1. count the working days of each month of 2026
     2. count the working days each employee has worked this year
     3. find the last working day of every month (salary payment day)

   WHY PIPELINED?
   The function creates rows that do not exist in any table.
   A 10-year calendar is ~3650 rows, piped one at a time, so memory
   stays small and the first rows arrive immediately.
   ============================================================ */


/* ============================================================
   STEP 0: CLEAN START (function first, then the types)
   ============================================================ */
BEGIN
    FOR o IN (SELECT object_name, object_type FROM user_objects
              WHERE object_name IN ('FN_CALENDAR', 'T_CALENDAR_TAB', 'T_CALENDAR_ROW')
              ORDER BY DECODE(object_name, 'FN_CALENDAR', 1, 'T_CALENDAR_TAB', 2, 3)) LOOP
        EXECUTE IMMEDIATE 'DROP ' || o.object_type || ' '
                          || DBMS_ASSERT.ENQUOTE_NAME(o.object_name);
    END LOOP;
END;
/


/* ============================================================
   STEP 1: ROW TYPE AND COLLECTION TYPE
   ============================================================ */
CREATE OR REPLACE TYPE t_calendar_row AS OBJECT (
    cal_date    DATE,
    day_name    VARCHAR2(3),
    iso_week    NUMBER(2),
    month_name  VARCHAR2(9),
    is_weekend  CHAR(1)
);
/

CREATE OR REPLACE TYPE t_calendar_tab AS TABLE OF t_calendar_row;
/


/* ============================================================
   STEP 2: THE PIPELINED FUNCTION
   Day names are produced in English whatever the session language
   (NLS_DATE_LANGUAGE=ENGLISH), so 'SAT' / 'SUN' always match.
   ============================================================ */
CREATE OR REPLACE FUNCTION fn_calendar (
    p_from IN DATE,
    p_to   IN DATE
) RETURN t_calendar_tab PIPELINED
IS
    v_day  DATE := TRUNC(p_from);
    v_name VARCHAR2(3);
BEGIN
    IF p_from IS NULL OR p_to IS NULL OR p_to < p_from THEN
        RAISE_APPLICATION_ERROR(-20110,
            'Invalid range: p_from and p_to are required and p_to >= p_from.');
    END IF;

    WHILE v_day <= TRUNC(p_to) LOOP
        v_name := TO_CHAR(v_day, 'DY', 'NLS_DATE_LANGUAGE=ENGLISH');

        PIPE ROW (
            t_calendar_row(
                v_day,
                v_name,
                TO_NUMBER(TO_CHAR(v_day, 'IW')),
                TRIM(TO_CHAR(v_day, 'MONTH', 'NLS_DATE_LANGUAGE=ENGLISH')),
                CASE WHEN v_name IN ('SAT', 'SUN') THEN 'Y' ELSE 'N' END
            )
        );

        v_day := v_day + 1;
    END LOOP;

    RETURN;
END fn_calendar;
/


/* ============================================================
   STEP 3: TESTS
   ============================================================ */

-- 3.1 One week (16-Nov-2026 is a Monday)
SELECT *
FROM TABLE(fn_calendar(DATE '2026-11-16', DATE '2026-11-22'));

-- 3.2 Working days only, current month
SELECT cal_date, day_name
FROM TABLE(fn_calendar(TRUNC(SYSDATE, 'MM'), LAST_DAY(SYSDATE)))
WHERE is_weekend = 'N';


/* ============================================================
   STEP 4: REPORTS
   ============================================================ */

-- 4.1 Working days in every month of 2026
SELECT TO_CHAR(cal_date, 'MM')                             AS month_no,
       MAX(month_name)                                     AS month_name,
       COUNT(*)                                            AS calendar_days,
       SUM(CASE WHEN is_weekend = 'N' THEN 1 ELSE 0 END)   AS working_days
FROM TABLE(fn_calendar(DATE '2026-01-01', DATE '2026-12-31'))
GROUP BY TO_CHAR(cal_date, 'MM')
ORDER BY month_no;

-- 4.2 Salary payment day = last working day of every month in 2026
SELECT month_name,
       MAX(cal_date) AS payment_day,
       TO_CHAR(MAX(cal_date), 'Day', 'NLS_DATE_LANGUAGE=ENGLISH') AS weekday
FROM TABLE(fn_calendar(DATE '2026-01-01', DATE '2026-12-31'))
WHERE is_weekend = 'N'
GROUP BY TO_CHAR(cal_date, 'MM'), month_name
ORDER BY MAX(cal_date);

-- 4.3 Working days each employee has worked since 1-Jan of this year
--     (or since the hire date, if hired this year).
--     The calendar is generated ONCE and joined to EMPLOYEES.
SELECT e.employee_id,
       e.first_name || ' ' || e.last_name AS full_name,
       e.hire_date,
       COUNT(c.cal_date)                   AS working_days_this_year
FROM employees e
JOIN TABLE(fn_calendar(TRUNC(SYSDATE, 'YYYY'), TRUNC(SYSDATE))) c
     ON c.cal_date >= e.hire_date
    AND c.is_weekend = 'N'
WHERE e.department_id = 60
GROUP BY e.employee_id, e.first_name, e.last_name, e.hire_date
ORDER BY e.employee_id;

-- 4.4 Daily salary = monthly salary / working days of the current month
SELECT e.employee_id,
       e.first_name || ' ' || e.last_name AS full_name,
       e.salary,
       w.working_days,
       ROUND(e.salary / w.working_days, 2) AS daily_rate
FROM employees e
CROSS JOIN (
    SELECT COUNT(*) AS working_days
    FROM TABLE(fn_calendar(TRUNC(SYSDATE, 'MM'), LAST_DAY(SYSDATE)))
    WHERE is_weekend = 'N'
) w
WHERE e.department_id = 90;

-- 4.5 Error test: p_to before p_from -> ORA-20110
-- SELECT * FROM TABLE(fn_calendar(DATE '2026-12-31', DATE '2026-01-01'));


/* ============================================================
   CLEAN UP
   ============================================================ */
-- DROP FUNCTION fn_calendar;
-- DROP TYPE t_calendar_tab;
-- DROP TYPE t_calendar_row;
