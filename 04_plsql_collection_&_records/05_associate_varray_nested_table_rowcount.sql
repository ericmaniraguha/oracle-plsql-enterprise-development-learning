-- ============================================================================
-- Title      : PL/SQL Collections and Exception Handling Examples
-- Author     : Eric Maniraguha
-- Purpose    : Demonstrates the use of different PL/SQL collections
--              (associative arrays, nested tables, nested table of records)
--              along with exception handling mechanisms including:
--                1. User-defined exceptions
--                2. Predefined exceptions (VALUE_ERROR, NO_DATA_FOUND)
--                3. Outer exception block for unexpected errors
--
-- Sections   :
--   1. Associative Array with user-defined exception
--   2. Nested Table with exception handling for calculation errors
--   3. Nested Table of Records integrated with table data and exception handling
--
-- Notes      :
--   - Illustrates safe data access using EXISTS() check
--   - Demonstrates handling errors during computations
--   - Shows how to use BULK COLLECT with exception handling
--   - Shows SQL%ROWCOUNT after a BULK COLLECT query
--
-- FIXES:
--   - The old comment said %ROWCOUNT does not work with BULK COLLECT.
--     It does: after SELECT ... BULK COLLECT INTO, SQL%ROWCOUNT holds the
--     number of rows fetched. Exercise 3 now demonstrates it.
--   - Exercise 3 reused e_invalid_key ("invalid array key") to mean "no rows
--     found". It now has its own exception, e_no_rows.
--   - WHEN OTHERS handlers now re-raise instead of swallowing the error.
-- ============================================================================
SET SERVEROUTPUT ON;

DECLARE
    ---------------------------------------------------------------------
    -- Exercise 1: Associative Array with Exception Handling
    ---------------------------------------------------------------------
    TYPE emp_array IS TABLE OF VARCHAR2(50) INDEX BY PLS_INTEGER;
    employees_arr emp_array;
    v_id PLS_INTEGER;

    -- User-defined exception for invalid array keys
    e_invalid_key EXCEPTION;

    ---------------------------------------------------------------------
    -- Exercise 2: Nested Table with Exception Handling
    ---------------------------------------------------------------------
    TYPE num_table IS TABLE OF NUMBER;
    numbers num_table := num_table();
    total NUMBER := 0;

    ---------------------------------------------------------------------
    -- Exercise 3: Nested Table of Records with Exception Handling
    ---------------------------------------------------------------------
    TYPE emp_rec_type IS RECORD (
        emp_id   employees.employee_id%TYPE,
        emp_name employees.first_name%TYPE,
        salary   employees.salary%TYPE
    );

    TYPE emp_table_type IS TABLE OF emp_rec_type;
    emp_list emp_table_type;

    -- User-defined exception for "query returned no rows"
    e_no_rows EXCEPTION;

BEGIN
    ---------------------------------------------------------------------
    -- Exercise 1: Associative Array Example
    ---------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('--- Exercise 1: Associative Array ---');

    -- Adding sample employees
    employees_arr(101) := 'Alice';
    employees_arr(102) := 'Bob';
    employees_arr(103) := 'Charlie';

    v_id := 102;  -- Example key

    BEGIN
        -- Check existence before accessing
        IF NOT employees_arr.EXISTS(v_id) THEN
            RAISE e_invalid_key;
        END IF;

        DBMS_OUTPUT.PUT_LINE('Employee ID ' || v_id || ' -> ' || employees_arr(v_id));
    EXCEPTION
        WHEN e_invalid_key THEN
            DBMS_OUTPUT.PUT_LINE('User-defined exception: key ' || v_id || ' does not exist.');
    END;

    ---------------------------------------------------------------------
    -- Exercise 2: Nested Table Example
    ---------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('--- Exercise 2: Nested Table ---');

    numbers.EXTEND(3);
    numbers(1) := 10;
    numbers(2) := 20;
    numbers(3) := 15;

    BEGIN
        FOR i IN 1..numbers.COUNT LOOP
            -- Simulate an error if multiplied value is too large
            IF numbers(i) * 100 > 1000 THEN
                RAISE VALUE_ERROR;
            END IF;
            total := total + numbers(i);
        END LOOP;

        DBMS_OUTPUT.PUT_LINE('Total sum of numbers: ' || total);
        DBMS_OUTPUT.PUT_LINE('Number of elements processed: ' || numbers.COUNT);

    EXCEPTION
        WHEN VALUE_ERROR THEN
            DBMS_OUTPUT.PUT_LINE('Error: Value too large in calculation.');
    END;

    ---------------------------------------------------------------------
    -- Exercise 3: Nested Table of Records with Exception Handling
    ---------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('--- Exercise 3: Nested Table of Records ---');

    BEGIN
        -- Collect employees with salary > 5000
        -- (a BULK COLLECT query never raises NO_DATA_FOUND; it returns an
        --  empty collection instead, so we check the count ourselves)
        SELECT employee_id, first_name, salary
        BULK COLLECT INTO emp_list
        FROM employees
        WHERE salary > 5000
        ORDER BY salary DESC;

        -- SQL%ROWCOUNT = number of rows the BULK COLLECT fetched.
        -- Read it immediately, before any other SQL statement runs.
        DBMS_OUTPUT.PUT_LINE('SQL%ROWCOUNT after BULK COLLECT: ' || SQL%ROWCOUNT);
        DBMS_OUTPUT.PUT_LINE('Number of employees retrieved (COUNT): ' || emp_list.COUNT);

        IF emp_list.COUNT = 0 THEN
            RAISE e_no_rows;
        END IF;

        -- Loop through collected records
        FOR i IN 1..emp_list.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE(
                'Name: ' || emp_list(i).emp_name || ', Salary: ' || emp_list(i).salary
            );
        END LOOP;

        DBMS_OUTPUT.PUT_LINE('Processed ' || emp_list.COUNT || ' employee records.');

    EXCEPTION
        WHEN e_no_rows THEN
            DBMS_OUTPUT.PUT_LINE('User-defined exception: No employees found with salary > 5000.');
    END;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Unexpected error in main block: ' || SQLERRM);
        RAISE;   -- report it, but do not hide it
END;
/
