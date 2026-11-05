-- FIXES:
-- - NULL inputs are rejected with a clear message. Before, a NULL bound
--   made the FOR loop raise VALUE_ERROR, which was hidden behind the
--   returned text "Error: ...".
-- - Removed "WHEN OTHERS THEN RETURN 'Error: ' || SQLERRM": returning an
--   error as if it were a normal result means the caller cannot tell
--   success from failure. Errors (e.g. a range too long for 4000 chars)
--   now reach the caller.
-- - RTRIM removes the trailing space after the last number.
CREATE OR REPLACE FUNCTION print_range_fn(p_start IN PLS_INTEGER, p_end IN PLS_INTEGER)
RETURN VARCHAR2
IS
    v_result VARCHAR2(4000);  -- Variable to store output (starts as NULL = '')
BEGIN
    IF p_start IS NULL OR p_end IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Start and end values cannot be NULL.');
    END IF;

    -- Determine direction
    IF p_start < p_end THEN
        -- Ascending
        FOR i IN p_start .. p_end LOOP
            v_result := v_result || i || ' ';
        END LOOP;
    ELSE
        -- Descending
        FOR i IN REVERSE p_end .. p_start LOOP
            v_result := v_result || i || ' ';
        END LOOP;
    END IF;

    RETURN RTRIM(v_result);  -- Return the full result
END;
/

-- Test the function

SET SERVEROUTPUT ON;

BEGIN
    DBMS_OUTPUT.PUT_LINE(print_range_fn(&start_value, &end_value));
END;
/
