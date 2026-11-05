
-- Same procedure as 13_store_proc_data_retrieval_for_loop.sql (that file has
-- the fully commented version).
--
-- IMPROVED: the counter variable was named "row_number", which is also the
-- name of the SQL function ROW_NUMBER(). It works, but it is confusing and
-- would break if this code ever moved into a SQL statement. Renamed to v_row_num.
-- The parameter now uses %TYPE so it always matches the column.
CREATE OR REPLACE PROCEDURE list_employees_by_min_id (
    p_min_id IN employees.employee_id%TYPE  -- input parameter
)
AS
    v_row_num PLS_INTEGER := 1;  -- counter to number each row
BEGIN
    -- Loop over the SELECT statement with input parameter filter
    -- (employee_id >= p_min_id can use the primary key index)
    FOR rec IN (SELECT employee_id, first_name, last_name
                FROM employees
                WHERE employee_id >= p_min_id
                ORDER BY employee_id) LOOP
        DBMS_OUTPUT.PUT_LINE(v_row_num || ': '
                             || rec.employee_id || ' - '
                             || rec.first_name || ' '
                             || rec.last_name);
        v_row_num := v_row_num + 1;  -- increment the counter
    END LOOP;
END;
/


-- Test the store procedure
SET SERVEROUTPUT ON;

BEGIN
    list_employees_by_min_id(100);  -- replace 100 with your desired min employee_id
END;
/
