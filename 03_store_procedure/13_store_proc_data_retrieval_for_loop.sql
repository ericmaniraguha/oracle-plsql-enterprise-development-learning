/*
    Procedure Name: list_employees_by_min_id

    Description:
    This procedure retrieves and displays employees whose employee_id
    is greater than or equal to a given input parameter (p_min_id).
    It also numbers each row using a counter.

    Input Parameter:
    p_min_id - Minimum employee_id to filter records

    Output:
    Displays employee details (ID, First Name, Last Name) using DBMS_OUTPUT

    Improvements:
    - Counter renamed from "row_number" (the name of a SQL function) to v_row_num.
    - Parameter uses employees.employee_id%TYPE so it always matches the column.
    - PLS_INTEGER is the fastest PL/SQL type for an integer counter.
*/

CREATE OR REPLACE PROCEDURE list_employees_by_min_id (
    p_min_id IN employees.employee_id%TYPE  -- Input parameter: minimum employee ID
)
AS
    v_row_num PLS_INTEGER := 1;  -- Variable to keep track of row numbering
BEGIN
    /*
        Loop through employees table:
        - Filters employees with ID >= p_min_id (can use the primary key index)
        - Orders results by employee_id in ascending order
    */
    FOR rec IN (SELECT employee_id, first_name, last_name
                FROM employees
                WHERE employee_id >= p_min_id
                ORDER BY employee_id) LOOP

        -- Print each employee record with a row number
        DBMS_OUTPUT.PUT_LINE(
            v_row_num || ': ' ||
            rec.employee_id || ' - ' ||
            rec.first_name || ' ' ||
            rec.last_name
        );

        -- Increment the row counter after each iteration
        v_row_num := v_row_num + 1;
    END LOOP;

    -- Indicate completion (optional for clarity)
    DBMS_OUTPUT.PUT_LINE('--- End of Employee List ---');

END;
/

/* Enable output display in SQL*Plus or SQL Developer */
SET SERVEROUTPUT ON;

/* Execute the procedure with a sample input value */
BEGIN
    list_employees_by_min_id(200);  -- Change 200 to test different values (HR IDs run from 100 to 206)
END;
/
