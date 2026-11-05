-- ========================================================
-- Function: get_bonus
-- Purpose: Calculate a simple bonus (e.g., 10% of salary)
--
-- DETERMINISTIC: the result depends only on the input, so Oracle may reuse
-- results for repeated inputs when the function is called from SQL.
-- (Same function as 04_02_func_get_bonus.sql.)
-- ========================================================
CREATE OR REPLACE FUNCTION get_bonus (
    p_salary IN NUMBER
) RETURN NUMBER
DETERMINISTIC
IS
BEGIN
    RETURN p_salary * 0.1;  -- 10% bonus
END get_bonus;
/

-- PL/SQL test with output:

SET SERVEROUTPUT ON;

DECLARE
    v_bonus NUMBER;
BEGIN
    v_bonus := get_bonus(5000);  -- assign function result (500)
    DBMS_OUTPUT.PUT_LINE('Bonus: ' || v_bonus);
END;
/
