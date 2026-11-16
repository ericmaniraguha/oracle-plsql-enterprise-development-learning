/*
  Simple addition calculation

  FIXED: the CREATE FUNCTION and the test block had no "/" after them.
  SQL*Plus / SQL Developer therefore kept reading the following lines as
  part of the function body, so the function failed to compile and the
  test block never ran.
  Also: both parameters are now explicitly IN with p_ names, and the
  function is DETERMINISTIC (same inputs, same result).
*/
CREATE OR REPLACE FUNCTION add_number(
    p_a IN NUMBER,
    p_b IN NUMBER
)
RETURN NUMBER
DETERMINISTIC
IS
BEGIN
    RETURN p_a + p_b;
END;
/

-- Test or Call the function
-- Testing using anonymous block
SET SERVEROUTPUT ON;

BEGIN
     DBMS_OUTPUT.PUT_LINE('Sum of two numbers: '|| add_number(12, 2));
END;
/

--Test the function using selection

SELECT add_number (78, 5) AS "Adding Two Numbers"  FROM DUAL;

SELECT add_number (15, 5) AS AddingTwoNumbers  FROM DUAL;
