SET SERVEROUTPUT ON;

-- Nested table + FOR loop, using the constructor to fill the table.
-- (04_nested_table.sql shows the EXTEND approach; this file used to be an
-- exact copy of it.)

DECLARE
    -- Step 1: Define a nested table type to store numbers
    TYPE num_table IS TABLE OF NUMBER;

    -- Step 2: Declare AND fill the nested table in one step with the constructor.
    -- No EXTEND needed when all values are known up front.
    numbers num_table := num_table(10, 20, 15, 25, 30);

    -- Step 3: Variable to calculate total sum
    total NUMBER := 0;
BEGIN
    -- Step 4: Delete one element to show that nested tables can become sparse
    numbers.DELETE(2);   -- removes the value 20; COUNT is now 4, LAST is still 5

    -- Step 5: Loop with FIRST..LAST and skip the gaps.
    -- "FOR i IN 1..numbers.COUNT" would stop at index 4 and also fail on the
    -- deleted index 2 (NO_DATA_FOUND), so it is not safe for sparse tables.
    FOR i IN numbers.FIRST .. numbers.LAST LOOP
        IF numbers.EXISTS(i) THEN
            total := total + numbers(i);
        END IF;
    END LOOP;

    -- Step 6: Display the total sum
    DBMS_OUTPUT.PUT_LINE('Elements left: ' || numbers.COUNT);
    DBMS_OUTPUT.PUT_LINE('Total sum of numbers: ' || total);   -- 10 + 15 + 25 + 30 = 80
END;
/
