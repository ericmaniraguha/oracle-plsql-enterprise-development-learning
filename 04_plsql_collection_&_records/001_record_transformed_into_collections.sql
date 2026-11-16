SET SERVEROUTPUT ON;

DECLARE
    -- Step 1: Define a record type
    TYPE emp_rec_type IS RECORD (
        first_name employees.first_name%TYPE,
        last_name  employees.last_name%TYPE,
        salary     employees.salary%TYPE
    );

    -- Step 2: Define a collection (table of records)
    TYPE emp_table_type IS TABLE OF emp_rec_type;

    -- Step 3: Declare a collection variable
    emp_table emp_table_type;
BEGIN
    -- Step 4: Bulk collect rows into the collection
    -- (one round trip fetches every row, instead of one fetch per row)
    SELECT first_name, last_name, salary
    BULK COLLECT INTO emp_table
    FROM employees
    WHERE department_id = 30   -- fetch multiple rows (department 10 has only one employee)
    ORDER BY last_name, first_name;

    -- Step 5: Loop through the collection
    -- BULK COLLECT always fills the collection densely from index 1,
    -- so 1..COUNT is safe. An empty result simply gives COUNT = 0.
    FOR i IN 1..emp_table.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE(emp_table(i).first_name || ' ' || emp_table(i).last_name || ' earns ' || emp_table(i).salary);
    END LOOP;
END;
/
-- FIXED: added the "/" above; without it the block is never executed.
-- NOTE: BULK COLLECT without LIMIT loads ALL rows into memory. That is fine
-- here (dozens of rows). For very large tables, fetch in batches with
-- "FETCH cursor BULK COLLECT INTO ... LIMIT 1000" inside a loop.
