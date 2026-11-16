
-- =========================
-- Exercise 2: Simple Addition
-- =========================
-- Question:
-- Write an anonymous block that adds two numbers stored in variables
-- and prints the result.
--
-- (This file previously contained a copy of 03_condition_logic.sql.)

-- Solution:
SET SERVEROUTPUT ON;

DECLARE
    v_num1 CONSTANT NUMBER := 12;   -- CONSTANT: the value never changes
    v_num2 CONSTANT NUMBER := 8;
    v_sum  NUMBER;
BEGIN
    v_sum := v_num1 + v_num2;
    DBMS_OUTPUT.PUT_LINE(v_num1 || ' + ' || v_num2 || ' = ' || v_sum);
END;
/
