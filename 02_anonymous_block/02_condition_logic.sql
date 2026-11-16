-- ========================================================

-- =========================
-- Exercise 3b: Conditional Logic with CASE
-- =========================
-- Question:
-- Classify a number as positive, negative, or zero using a CASE expression.
-- (03_condition_logic.sql solves the same problem with IF / ELSIF.)
--
-- (This file previously contained a copy of 04_looping_logic.sql.)

-- Solution:
SET SERVEROUTPUT ON;

DECLARE
    v_num    NUMBER := -7;
    v_result VARCHAR2(20);
BEGIN
    -- A searched CASE expression returns a value, so one assignment
    -- replaces three separate PUT_LINE calls.
    v_result := CASE
                    WHEN v_num > 0 THEN 'positive'
                    WHEN v_num < 0 THEN 'negative'
                    ELSE 'zero'
                END;

    DBMS_OUTPUT.PUT_LINE('Number ' || v_num || ' is ' || v_result);
END;
/
