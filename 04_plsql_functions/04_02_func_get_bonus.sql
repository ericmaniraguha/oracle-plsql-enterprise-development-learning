-- DETERMINISTIC: the result depends only on the input.
CREATE OR REPLACE FUNCTION get_bonus (
    p_salary IN NUMBER
) RETURN NUMBER
DETERMINISTIC
IS
BEGIN
    RETURN p_salary * 0.1;  -- 10% bonus
END get_bonus;
/
-- FIXED: added the "/" above so the function is actually created when the
-- file is run as a script.
