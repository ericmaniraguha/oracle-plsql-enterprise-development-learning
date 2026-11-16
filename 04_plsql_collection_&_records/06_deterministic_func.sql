---------------------------------------------------------------------
-- Enable output so we can print results from PL/SQL blocks
---------------------------------------------------------------------
SET SERVEROUTPUT ON;

---------------------------------------------------------------------
-- STEP 1: Create a deterministic function
-- This function calculates 15% tax from a given amount.
--
-- DETERMINISTIC means:
-- If the function receives the same input value,
-- it will always return the same output value.
--
-- Example:
-- calculate_tax(1000) will always return 150
---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION calculate_tax(p_amount IN NUMBER)
RETURN NUMBER
DETERMINISTIC
IS
    v_tax NUMBER;
BEGIN
    -- Calculate 15% tax
    v_tax := p_amount * 0.15;

    -- Return the computed tax
    RETURN v_tax;
END;
/

---------------------------------------------------------------------
-- STEP 2: Test the function using SELECT
-- Functions can be called directly inside SQL queries.
-- DUAL is a special Oracle table used for testing expressions.
---------------------------------------------------------------------

SELECT calculate_tax(1000) AS tax_amount
FROM dual;

---------------------------------------------------------------------
-- STEP 3: Test the function inside a PL/SQL block
-- This allows printing results using DBMS_OUTPUT
---------------------------------------------------------------------

DECLARE
    v_result NUMBER;
BEGIN
    -- Call the function and store the result
    v_result := calculate_tax(2000);

    -- Print the result
    DBMS_OUTPUT.PUT_LINE('Tax for 2000 is: ' || v_result);
END;
/

---------------------------------------------------------------------
-- STEP 4: Test repeated calls with the same input
--
-- Because the function is DETERMINISTIC, Oracle may reuse
-- the previous result instead of recalculating it during
-- the same query execution.
--
-- CLARIFIED: the cache works ROW BY ROW inside ONE query: when many
-- rows pass the same argument, Oracle can skip repeat calls. The
-- EMPLOYEES table is a realistic example: many employees share the
-- same salary (e.g. several earn 2500), so Oracle may run
-- calculate_tax(2500) once and reuse it. (The old UNION ALL of DUAL
-- queries showed 3 separate query blocks, which is not where the
-- caching helps.)
---------------------------------------------------------------------

SELECT employee_id, salary, calculate_tax(salary) AS tax_value
FROM employees
ORDER BY salary;

---------------------------------------------------------------------
-- STEP 5: Test with different values
-- This shows that the function works with multiple inputs.
---------------------------------------------------------------------

SELECT 500  AS amount, calculate_tax(500)  AS tax FROM dual
UNION ALL
SELECT 1000 AS amount, calculate_tax(1000) FROM dual
UNION ALL
SELECT 2000 AS amount, calculate_tax(2000) FROM dual;

---------------------------------------------------------------------
-- End of test script
---------------------------------------------------------------------