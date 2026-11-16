SET SERVEROUTPUT ON;

DECLARE
    emp_rec employees%ROWTYPE;   -- one field for every column of EMPLOYEES
BEGIN
    SELECT * INTO emp_rec
    FROM employees
    WHERE employee_id = 101;

    DBMS_OUTPUT.PUT_LINE(emp_rec.first_name || ' ' || emp_rec.last_name);

    -- SQL%ROWCOUNT after SELECT INTO will always be 1
    DBMS_OUTPUT.PUT_LINE('Rows fetched: ' || SQL%ROWCOUNT);
END;
/
-- FIXED: added the "/" above; without it the block is never executed.
-- NOTE: %ROWTYPE with SELECT * is convenient, but it fetches every column.
-- When you only need two columns, a custom RECORD (see
-- 00_records_type_fetch_data.sql) moves less data.
