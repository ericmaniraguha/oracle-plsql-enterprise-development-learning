-- Enable output display
SET SERVEROUTPUT ON;

DECLARE
    -- Step 1: Define a VARRAY type with a maximum size of 5
    TYPE score_array IS VARRAY(5) OF NUMBER;

    -- Step 2: Initialize the VARRAY with 3 elements
    scores score_array := score_array(80, 90, 85);

    -- Step 3: Procedure with parameter to access a specific index
    PROCEDURE display_score(p_index PLS_INTEGER) IS
    BEGIN
        -- Attempt to display the element at the given index
        DBMS_OUTPUT.PUT_LINE(
            'Score at position ' || p_index || ' is: ' || scores(p_index)
        );

    -- Exception handling if index is invalid
    -- FIXED: index 12 is larger than the VARRAY's LIMIT (5), which raises
    -- SUBSCRIPT_OUTSIDE_LIMIT, not SUBSCRIPT_BEYOND_COUNT. The old code
    -- fell through to "WHEN OTHERS" and printed a vague "Invalid index."
    --   SUBSCRIPT_BEYOND_COUNT : index <= LIMIT but > COUNT  (e.g. 4 here)
    --   SUBSCRIPT_OUTSIDE_LIMIT: index > LIMIT or index < 1   (e.g. 12 or 0)
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

BEGIN
    -- Step 4: Call procedure with a valid index
    display_score(2);

    -- Step 5: Call procedure with invalid indexes (demonstrates error handling)
    display_score(4);    -- within LIMIT, beyond COUNT
    display_score(12);   -- beyond LIMIT
END;
/
