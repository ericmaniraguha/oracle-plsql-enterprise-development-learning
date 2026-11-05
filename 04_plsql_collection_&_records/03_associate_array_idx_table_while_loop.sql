-- 1 - Associative Array (Index-by Table)
SET SERVEROUTPUT ON;

DECLARE
    -- Step 1: Define an associative array type
    -- Key: Employee ID (integer)
    -- Value: Employee Name (string)
    TYPE emp_array IS TABLE OF VARCHAR2(50) INDEX BY PLS_INTEGER;

    -- Step 2: Declare a variable of this type
    -- RENAMED from "employees": a variable with the same name as the
    -- EMPLOYEES table makes the code hard to read (is "employees" the
    -- table or the array?). Give PL/SQL variables names that cannot be
    -- confused with database objects.
    emp_names emp_array;

    -- Step 3: Iterator variable for looping through keys
    v_id PLS_INTEGER;
BEGIN
    -- Step 4: Populate the associative array
    emp_names(101) := 'Alice';
    emp_names(102) := 'Bob';
    emp_names(103) := 'Charlie';

    -- Step 5: Loop through all keys to display employee names
    -- FIRST / NEXT visits only the keys that exist, so it also works for
    -- sparse arrays (e.g. keys 101, 205, 9000), unlike FOR i IN 1..COUNT.
    v_id := emp_names.FIRST;  -- Get first key
    WHILE v_id IS NOT NULL LOOP
        DBMS_OUTPUT.PUT_LINE('Employee ID ' || v_id || ' -> ' || emp_names(v_id));
        v_id := emp_names.NEXT(v_id);  -- Move to next key
    END LOOP;
END;
/
