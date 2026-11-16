-- ========================================================
-- Example: WHILE Loop with Table, Parameter, and Exception Handling
--
-- OPTIMIZED: the old version ran a NEW query on every loop iteration:
--     SELECT ... FROM (SELECT ..., ROW_NUMBER() OVER (ORDER BY employee_id) rn
--                      FROM employees) WHERE rn = v_counter;
-- Each of those queries read and sorted the WHOLE employees table just to
-- keep one row, so printing N employees cost N full sorts (quadratic work).
-- Now ONE cursor returns the first p_max rows in order, and the WHILE loop
-- walks through it. That is one query, one sort, and Oracle stops after
-- p_max rows.
--
-- FIXED: v_emp_name was declared as employees.first_name%TYPE (20 chars)
-- but holds "first_name || ' ' || last_name" (up to 46 chars). A long name
-- would raise ORA-06502 (value too large).
-- ========================================================

SET SERVEROUTPUT ON;

-- Create a procedure with an input parameter
CREATE OR REPLACE PROCEDURE print_employees(
    p_max IN PLS_INTEGER   -- input: number of employees to print
)
IS
    CURSOR c_emp IS
        SELECT first_name || ' ' || last_name AS full_name
        FROM employees
        ORDER BY employee_id
        FETCH FIRST p_max ROWS ONLY;

    v_counter  PLS_INTEGER := 0;   -- counter for loop
    v_emp_name VARCHAR2(50);       -- first_name(20) + ' ' + last_name(25) fits

    -- User-defined exception
    e_invalid_count EXCEPTION;
BEGIN
    IF p_max IS NULL OR p_max <= 0 THEN
        RAISE e_invalid_count;  -- raise user-defined exception if input invalid
    END IF;

    DBMS_OUTPUT.PUT_LINE('--- Printing first ' || p_max || ' employees ---');

    OPEN c_emp;
    FETCH c_emp INTO v_emp_name;

    -- WHILE loop driven by the cursor attribute %FOUND
    WHILE c_emp%FOUND LOOP
        v_counter := v_counter + 1;
        DBMS_OUTPUT.PUT_LINE('Employee ' || v_counter || ': ' || v_emp_name);
        FETCH c_emp INTO v_emp_name;
    END LOOP;

    CLOSE c_emp;

    IF v_counter < p_max THEN
        DBMS_OUTPUT.PUT_LINE('Only ' || v_counter || ' employees exist.');
    END IF;

EXCEPTION
    WHEN e_invalid_count THEN
        DBMS_OUTPUT.PUT_LINE('User-defined error: Number of employees must be greater than 0.');
    WHEN OTHERS THEN
        -- Close the cursor before leaving, then re-raise so the error is not hidden
        IF c_emp%ISOPEN THEN
            CLOSE c_emp;
        END IF;
        RAISE;
END;
/

--How to Run the Procedure with a Parameter

-- Example: Print first 3 employees
BEGIN
    print_employees(3);
END;
/
