/*
Procedure: get_salary_statistics

OPTIMIZED: ONE query instead of FOUR.
The old version ran four separate SELECTs (SUM, AVG, COUNT, COUNT above
threshold), each re-reading the same department/date rows. All four values
come from a single scan:
  - SUM, AVG and COUNT(*) are computed together.
  - The threshold count uses conditional aggregation:
        COUNT(CASE WHEN salary > threshold THEN 1 END)
    CASE returns NULL for the other rows, and COUNT ignores NULLs.

IMPROVED date filter: "hire_date >= start AND hire_date < end + 1" instead of
"BETWEEN start AND end". BETWEEN on a DATE stops at midnight of the end day,
so a row stamped later that day would be missed. The half-open range
includes the whole last day and still uses an index on hire_date.

FIXED: "WHEN OTHERS THEN PUT_LINE" hid real errors; it is gone.
FIXED: the test asked for 2023, but HR hire dates run from 2001 to 2008, so it
always reported "No employees found". The test now uses 2002-2007.
*/

CREATE OR REPLACE PROCEDURE get_salary_statistics(
    p_department_id    IN employees.department_id%TYPE,
    p_start_date       IN DATE,
    p_end_date         IN DATE,
    p_salary_threshold IN employees.salary%TYPE
)
IS
    v_total_salary      NUMBER;
    v_average_salary    NUMBER;
    v_employee_count    PLS_INTEGER;
    v_rows_above_thresh PLS_INTEGER;
BEGIN
    -- One implicit cursor computes every statistic in a single pass.
    -- An aggregate query always returns exactly one row (never NO_DATA_FOUND).
    SELECT NVL(SUM(salary), 0),
           NVL(AVG(salary), 0),
           COUNT(*),
           COUNT(CASE WHEN salary > p_salary_threshold THEN 1 END)
    INTO v_total_salary,
         v_average_salary,
         v_employee_count,
         v_rows_above_thresh
    FROM employees
    WHERE department_id = p_department_id
      AND hire_date >= p_start_date
      AND hire_date <  p_end_date + 1;   -- whole end day included

    -- Check if any employees exist in the period
    IF v_employee_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No employees found in department ' || p_department_id || ' for the given date range.');
        RETURN;
    END IF;

    -- Output the message
    DBMS_OUTPUT.PUT_LINE(
        'Department ' || p_department_id || ': ' ||
        'Total Salary = ' || v_total_salary || ', ' ||
        'Average Salary = ' || ROUND(v_average_salary, 2) || ', ' ||
        'Employees above salary threshold (' || p_salary_threshold || '): ' || v_rows_above_thresh || ', ' ||
        'Total Employees Processed: ' || v_employee_count);
END;
/

/*
Test department 30, from 01-JAN-2002 to 31-DEC-2007, salary threshold 3000
*/
SET SERVEROUTPUT ON;

BEGIN
    get_salary_statistics(
        p_department_id    => 30,
        p_start_date       => DATE '2002-01-01',
        p_end_date         => DATE '2007-12-31',
        p_salary_threshold => 3000
    );
END;
/
