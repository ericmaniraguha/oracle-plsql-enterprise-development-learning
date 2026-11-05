SET SERVEROUTPUT ON;

-- Countdown from 5 to 1 using FOR ... IN REVERSE.
-- FIXED: the old code printed (i - 6), which gave -1, -2, -3, -4, -5
-- instead of a countdown. REVERSE already walks 5, 4, 3, 2, 1.
BEGIN
  FOR i IN REVERSE 1..5 LOOP
    DBMS_OUTPUT.PUT_LINE('Countdown: ' || i);
  END LOOP;
END;
/
