-- Enable output in SQL*Plus / SQL Developer
SET SERVEROUTPUT ON;

-- =====================================================
-- Create a reusable stored procedure in Oracle
-- This procedure will remain stored in the database
-- and can be called anytime when needed
-- =====================================================

CREATE OR REPLACE PROCEDURE display_score (
    p_index IN PLS_INTEGER   -- Parameter: position of the score to display
)
AS
    -- Step 1: Define a VARRAY type with a maximum size of 5
    TYPE score_array IS VARRAY(5) OF NUMBER;

    -- Step 2: Initialize the VARRAY with sample scores
    scores score_array := score_array(80, 90, 85);
BEGIN
    -- Step 3: Display the score at the given index
    DBMS_OUTPUT.PUT_LINE(
        'Score at position ' || p_index || ' is: ' || scores(p_index)
    );

-- Step 4: Handle possible errors
-- FIXED: added SUBSCRIPT_OUTSIDE_LIMIT (index > 5 or < 1), and removed
-- "WHEN OTHERS THEN PUT_LINE('Unexpected error occurred.')", which hid the
-- real error message from the caller.
EXCEPTION
    WHEN SUBSCRIPT_BEYOND_COUNT THEN
        DBMS_OUTPUT.PUT_LINE(
            'Error: Index ' || p_index || ' exceeds the number of elements (' || scores.COUNT || ').'
        );

    WHEN SUBSCRIPT_OUTSIDE_LIMIT THEN
        DBMS_OUTPUT.PUT_LINE(
            'Error: Index ' || p_index || ' is outside the VARRAY limit (1 to ' || scores.LIMIT || ').'
        );
END;
/


--How to Call the Stored Procedure
--Method 1 (Recommended)
BEGIN
    display_score(2);
END;
/

--Method 2 (Short form)
EXEC display_score(1);

EXECUTE display_score(3);

-- Invalid positions
EXEC display_score(4);
EXEC display_score(9);
