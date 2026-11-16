-- PREDEFINED (BUILT-IN) FUNCTIONS are functions supplied by Oracle.
-- You call them in SQL (SELECT, WHERE, ORDER BY ...) and in PL/SQL.

/*
Two big families
    1. SINGLE-ROW functions : one result PER ROW
         Character, Number, Date, Conversion, NULL-handling,
         Conditional, Regular expressions
    2. AGGREGATE (group) functions : one result PER GROUP of rows
         COUNT, SUM, AVG, MIN, MAX, LISTAGG ...
    (Analytic / window functions: see ../windows_function/)

DUAL is a one-row table used to test a function:
    SELECT UPPER('auca') FROM dual;
*/


-- ============================================
-- 1. CHARACTER FUNCTIONS
-- ============================================

-- 1.1 Case conversion
SELECT UPPER('oracle pl/sql')   AS upper_case,      -- ORACLE PL/SQL
       LOWER('ORACLE PL/SQL')   AS lower_case,      -- oracle pl/sql
       INITCAP('oracle pl/sql') AS init_cap         -- Oracle Pl/Sql
FROM dual;

-- 1.2 Joining, length, part of a string
SELECT first_name,
       last_name,
       CONCAT(first_name, last_name)        AS concat_fn,     -- only 2 arguments
       first_name || ' ' || last_name       AS full_name,     -- || joins any number
       LENGTH(last_name)                    AS name_length,
       SUBSTR(first_name, 1, 1) || '. ' || last_name AS short_name,   -- S. King
       INSTR(email, 'A')                    AS first_a_position      -- 0 = not found
FROM employees
WHERE department_id = 60;

-- 1.3 Padding, trimming, replacing
SELECT LPAD(salary, 10, '*')               AS lpad_salary,    -- ******9000
       RPAD(last_name, 12, '.')            AS rpad_name,      -- Hunold......
       TRIM('   AUCA   ')                  AS trim_both,
       LTRIM('000123', '0')                AS ltrim_zeros,    -- 123
       RTRIM('Kigali!!!', '!')             AS rtrim_chars,    -- Kigali
       REPLACE(phone_number, '.', '-')     AS phone_dashes,   -- 590-423-4567
       TRANSLATE('2026-11-15', '-', '/')   AS translate_chr   -- 2026/11/15
FROM employees
WHERE employee_id = 103;

-- 1.4 Practical: generate a login name -> first letter + last name, lower case
SELECT employee_id,
       LOWER(SUBSTR(first_name, 1, 1) || REPLACE(last_name, ' ', '')) AS login_name
FROM employees
WHERE department_id = 90;

-- 1.5 In WHERE: case-insensitive search
SELECT employee_id, first_name, last_name
FROM employees
WHERE UPPER(last_name) LIKE 'K%';


-- ============================================
-- 2. NUMBER FUNCTIONS
-- ============================================
SELECT ROUND(1234.5678, 2)  AS round_2,       -- 1234.57
       ROUND(1234.5678, -2) AS round_hundred, -- 1200
       TRUNC(1234.5678, 2)  AS trunc_2,       -- 1234.56 (cuts, no rounding)
       CEIL(10.1)           AS ceil_up,       -- 11
       FLOOR(10.9)          AS floor_down,    -- 10
       MOD(17, 5)           AS mod_rest,      -- 2
       ABS(-250)            AS absolute,      -- 250
       POWER(2, 10)         AS power_2_10,    -- 1024
       SQRT(144)            AS square_root,   -- 12
       SIGN(-15)            AS sign_value     -- -1 / 0 / 1
FROM dual;

-- Practical: monthly, daily and hourly pay
SELECT employee_id,
       last_name,
       salary,
       ROUND(salary * 12, 2)        AS annual_salary,
       ROUND(salary / 22, 2)        AS daily_rate,     -- 22 working days
       TRUNC(salary / 22 / 8, 2)    AS hourly_rate,
       MOD(employee_id, 2)          AS odd_even_id     -- 0 = even, 1 = odd
FROM employees
WHERE department_id = 60;


-- ============================================
-- 3. DATE FUNCTIONS
-- ============================================
SELECT SYSDATE                                      AS today,
       SYSTIMESTAMP                                 AS now_with_time_zone,
       ADD_MONTHS(SYSDATE, 6)                       AS in_6_months,
       ADD_MONTHS(SYSDATE, -1)                      AS one_month_ago,
       LAST_DAY(SYSDATE)                            AS last_day_of_month,
       NEXT_DAY(SYSDATE, 'MONDAY')                  AS next_monday,   -- day name follows NLS language
       TRUNC(SYSDATE, 'MM')                         AS first_day_of_month,
       TRUNC(SYSDATE, 'YYYY')                       AS first_day_of_year,
       EXTRACT(YEAR  FROM SYSDATE)                  AS this_year,
       EXTRACT(MONTH FROM SYSDATE)                  AS this_month,
       SYSDATE + 30                                 AS plus_30_days
FROM dual;

-- Practical: length of service
SELECT employee_id,
       last_name,
       hire_date,
       TRUNC(SYSDATE - hire_date)                       AS days_worked,
       TRUNC(MONTHS_BETWEEN(SYSDATE, hire_date))        AS months_worked,
       TRUNC(MONTHS_BETWEEN(SYSDATE, hire_date) / 12)   AS years_worked,
       ADD_MONTHS(hire_date, 6)                         AS probation_end
FROM employees
WHERE department_id = 90
ORDER BY hire_date;

-- Employees hired in a given year / month
SELECT last_name, hire_date
FROM employees
WHERE EXTRACT(YEAR FROM hire_date) = 2005
ORDER BY hire_date;


-- ============================================
-- 4. CONVERSION FUNCTIONS
-- ============================================

-- 4.1 TO_CHAR: date -> text, number -> text
SELECT TO_CHAR(SYSDATE, 'DD-MON-YYYY')              AS date_1,       -- 15-NOV-2026
       TO_CHAR(SYSDATE, 'Day, DD Month YYYY')       AS date_2,
       TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS')    AS date_time,
       TO_CHAR(SYSDATE, 'Q')                        AS quarter,
       TO_CHAR(1234567.891, '9,999,999.99')         AS number_fmt,   -- 1,234,567.89
       TO_CHAR(0.25, '990.00') || '%'               AS percent_fmt
FROM dual;

SELECT last_name,
       TO_CHAR(salary, '$99,999.00')                      AS salary_usd,
       TO_CHAR(hire_date, 'fmDD Month YYYY')              AS hired_on,     -- fm removes padding
       TO_CHAR(hire_date, 'Day', 'NLS_DATE_LANGUAGE=ENGLISH') AS hired_weekday
FROM employees
WHERE department_id = 90;

-- 4.2 TO_DATE / TO_NUMBER: text -> date / number
SELECT TO_DATE('15/11/2026', 'DD/MM/YYYY')          AS a_date,
       TO_DATE('2026-11-15 14:30', 'YYYY-MM-DD HH24:MI') AS a_date_time,
       TO_NUMBER('1,500.75', '9,999.99')            AS a_number,
       DATE '2026-12-25'                            AS date_literal    -- ANSI literal
FROM dual;

-- 4.3 CAST: general conversion
SELECT CAST('2500' AS NUMBER)             AS text_to_number,
       CAST(SYSDATE AS TIMESTAMP)         AS date_to_timestamp,
       CAST(employee_id AS VARCHAR2(10))  AS number_to_text
FROM employees
WHERE employee_id = 100;

-- 4.4 Safe conversion (Oracle 12.2+): no error on bad input
SELECT TO_NUMBER('12A' DEFAULT 0 ON CONVERSION ERROR)                   AS bad_number,
       TO_DATE('31/02/2026' DEFAULT NULL ON CONVERSION ERROR, 'DD/MM/YYYY') AS bad_date,
       VALIDATE_CONVERSION('12A' AS NUMBER)                              AS is_valid   -- 0 = no
FROM dual;


-- ============================================
-- 5. NULL-HANDLING FUNCTIONS
-- Any arithmetic with NULL gives NULL: salary + NULL = NULL
-- ============================================
SELECT last_name,
       salary,
       commission_pct,
       salary * commission_pct                         AS commission_wrong,   -- NULL for many
       NVL(commission_pct, 0)                          AS nvl_comm,           -- NULL -> 0
       salary + salary * NVL(commission_pct, 0)        AS total_pay,
       NVL2(commission_pct, 'Has commission', 'None')  AS nvl2_text,          -- not null / null
       NULLIF(salary, 24000)                           AS nullif_24000,       -- equal -> NULL
       COALESCE(commission_pct, manager_id, 0)         AS first_not_null      -- 1st non-NULL
FROM employees
WHERE department_id IN (80, 90)
  AND ROWNUM <= 8;


-- ============================================
-- 6. CONDITIONAL FUNCTIONS: DECODE and CASE
-- ============================================

-- 6.1 DECODE (Oracle only): compare one value with a list
SELECT last_name,
       job_id,
       DECODE(job_id,
              'IT_PROG', 'Programmer',
              'AD_PRES', 'President',
              'AD_VP',   'Vice President',
              'Other')                AS job_label
FROM employees
WHERE department_id IN (60, 90);

-- 6.2 CASE (ANSI SQL): any condition, more readable
SELECT last_name,
       salary,
       CASE
           WHEN salary >= 15000 THEN 'Executive'
           WHEN salary >= 8000  THEN 'High'
           WHEN salary >= 4000  THEN 'Medium'
           ELSE 'Low'
       END AS salary_band,
       CASE department_id
           WHEN 60 THEN 'IT'
           WHEN 90 THEN 'Executive'
           ELSE 'Other'
       END AS dept_label
FROM employees
WHERE department_id IN (50, 60, 90)
ORDER BY salary DESC;

-- 6.3 GREATEST / LEAST
SELECT GREATEST(10, 45, 30)          AS biggest,   -- 45
       LEAST('Kigali', 'Huye', 'Musanze') AS first_alphabetically  -- Huye
FROM dual;


-- ============================================
-- 7. REGULAR EXPRESSION FUNCTIONS
-- ============================================
SELECT phone_number,
       REGEXP_REPLACE(phone_number, '[^0-9]', '')       AS digits_only,    -- 5904234567
       REGEXP_SUBSTR(phone_number, '[0-9]+', 1, 2)      AS second_group,   -- 423
       REGEXP_COUNT(phone_number, '\.')                 AS dot_count,
       REGEXP_INSTR(phone_number, '[0-9]{4}')           AS pos_4_digits
FROM employees
WHERE department_id = 60;

-- REGEXP_LIKE in WHERE: last names starting with a vowel
SELECT last_name
FROM employees
WHERE REGEXP_LIKE(last_name, '^[AEIOU]', 'i')
ORDER BY last_name;

-- Validate email format (example data)
SELECT email_value,
       CASE WHEN REGEXP_LIKE(email_value, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
            THEN 'VALID' ELSE 'INVALID' END AS check_result
FROM (SELECT 'eric@auca.ac.rw' AS email_value FROM dual UNION ALL
      SELECT 'wrong.email@'                  FROM dual UNION ALL
      SELECT 'aline.uwase@gmail.com'         FROM dual);


-- ============================================
-- 8. AGGREGATE (GROUP) FUNCTIONS
-- They ignore NULLs (except COUNT(*)).
-- ============================================
SELECT COUNT(*)                 AS all_rows,
       COUNT(commission_pct)    AS rows_with_commission,   -- NULLs not counted
       COUNT(DISTINCT job_id)   AS different_jobs,
       SUM(salary)              AS total_salary,
       ROUND(AVG(salary), 2)    AS average_salary,
       MIN(salary)              AS lowest_salary,
       MAX(salary)              AS highest_salary,
       MIN(hire_date)           AS first_hire,
       MAX(hire_date)           AS last_hire
FROM employees;

-- Per department, with HAVING to filter groups
SELECT department_id,
       COUNT(*)                AS employees,
       SUM(salary)             AS total_salary,
       ROUND(AVG(salary), 2)   AS avg_salary,
       ROUND(STDDEV(salary),2) AS salary_stddev
FROM employees
WHERE department_id IS NOT NULL
GROUP BY department_id
HAVING COUNT(*) >= 3
ORDER BY total_salary DESC;

-- LISTAGG: join the values of a group into one string
SELECT department_id,
       LISTAGG(last_name, ', ') WITHIN GROUP (ORDER BY last_name) AS employees
FROM employees
WHERE department_id IN (20, 60, 90, 110)
GROUP BY department_id;


-- ============================================
-- 9. USER / ENVIRONMENT FUNCTIONS
-- ============================================
SELECT USER                                      AS db_user,
       SYS_CONTEXT('USERENV', 'SESSION_USER')    AS session_user_name,
       SYS_CONTEXT('USERENV', 'DB_NAME')         AS database_name,
       SYS_CONTEXT('USERENV', 'IP_ADDRESS')      AS client_ip,
       SYS_CONTEXT('USERENV', 'HOST')            AS client_host,
       SYS_GUID()                                AS unique_id
FROM dual;


-- ============================================
-- 10. PREDEFINED FUNCTIONS INSIDE PL/SQL
-- Most single-row functions work directly in PL/SQL expressions.
-- (DECODE and aggregate functions only inside a SQL statement.)
-- ============================================
SET SERVEROUTPUT ON;

DECLARE
    v_name    employees.last_name%TYPE;
    v_salary  employees.salary%TYPE;
    v_hired   employees.hire_date%TYPE;
    v_comm    employees.commission_pct%TYPE;
BEGIN
    SELECT last_name, salary, hire_date, commission_pct
    INTO v_name, v_salary, v_hired, v_comm
    FROM employees
    WHERE employee_id = 145;

    DBMS_OUTPUT.PUT_LINE('Name         : ' || UPPER(v_name));
    DBMS_OUTPUT.PUT_LINE('Name length  : ' || LENGTH(v_name));
    DBMS_OUTPUT.PUT_LINE('Salary       : ' || TO_CHAR(v_salary, '99,999.00'));
    DBMS_OUTPUT.PUT_LINE('Commission   : ' || NVL(TO_CHAR(v_comm * 100), 'none') || '%');
    DBMS_OUTPUT.PUT_LINE('Total pay    : ' || ROUND(v_salary * (1 + NVL(v_comm, 0)), 2));
    DBMS_OUTPUT.PUT_LINE('Hired on     : ' || TO_CHAR(v_hired, 'fmDD Month YYYY'));
    DBMS_OUTPUT.PUT_LINE('Years worked : ' || TRUNC(MONTHS_BETWEEN(SYSDATE, v_hired) / 12));
    DBMS_OUTPUT.PUT_LINE('Band         : ' ||
        CASE WHEN v_salary >= 10000 THEN 'High' ELSE 'Standard' END);
END;
/


-- ============================================
-- EXERCISES
-- ============================================

-- EX1:
-- Display every employee's full name in UPPER case and the number of
-- characters of the full name, longest names first.

-- EX2:
-- Show employees hired on a MONDAY
-- (hint: TO_CHAR(hire_date, 'DY', 'NLS_DATE_LANGUAGE=ENGLISH') = 'MON').

-- EX3:
-- Show each employee's salary formatted as '$24,000.00' and a 7.5% raise
-- rounded to the nearest 100.

-- EX4:
-- Display last_name and commission; show 'No Commission' when it is NULL
-- (hint: NVL(TO_CHAR(commission_pct), 'No Commission')).

-- EX5:
-- Using CASE, classify employees by years of service:
-- < 15 'Junior', 15-19 'Senior', 20+ 'Veteran'.

-- EX6:
-- For each job_id show the number of employees, min, max and average salary,
-- and the list of last names (LISTAGG). Keep only jobs with more than 2 employees.

-- EX7:
-- Using REGEXP_REPLACE, remove all vowels from the last names of department 50.
