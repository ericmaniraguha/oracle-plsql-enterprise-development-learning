SET SERVEROUTPUT ON;  -- Enables printing output to the console

DECLARE
    start_num NUMBER := &start_value;  -- Accept starting value from user input
    end_num   NUMBER := &end_value;    -- Accept ending value from user input

BEGIN
    -- Check if any input is missing (NULL values are not allowed)
    IF start_num IS NULL OR end_num IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Inputs cannot be NULL');
    END IF;

    -- Determine loop direction based on user input
    IF start_num < end_num THEN
        -- Case 1: Ascending order (e.g., 1 to 5)
        FOR i IN start_num .. end_num LOOP
            DBMS_OUTPUT.PUT_LINE('Value: ' || i);  -- Display each number
        END LOOP;

    ELSE
        -- Case 2: Descending order (e.g., 5 to 1)
        -- REVERSE ensures iteration from higher value to lower value
        FOR i IN REVERSE end_num .. start_num LOOP
            DBMS_OUTPUT.PUT_LINE('Value: ' || i);  -- Display each number
        END LOOP;
    END IF;

EXCEPTION
    -- Handles numeric problems at run time (e.g., a value too large for a loop bound).
    -- Note: substitution variables are replaced as TEXT before the block compiles,
    -- so typing letters gives a compile error (PLS-00201), not VALUE_ERROR.
    WHEN VALUE_ERROR THEN
        DBMS_OUTPUT.PUT_LINE('Error: Please enter valid numeric values.');

    -- Removed "WHEN OTHERS THEN PUT_LINE(SQLERRM)": it turned every unexpected
    -- error (including our own ORA-20001 above) into a silent success.
END;
/