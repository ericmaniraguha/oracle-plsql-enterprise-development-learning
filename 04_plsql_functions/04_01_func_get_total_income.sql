-- Requires get_bonus (04_02_func_get_bonus.sql): create that function first.
-- DETERMINISTIC: same salary in, same total out.
CREATE OR REPLACE FUNCTION get_total_income (p_salary IN NUMBER)
RETURN NUMBER
DETERMINISTIC
IS
BEGIN
    -- Call function inside another function
    -- (no temporary variable needed: return the expression directly)
    RETURN p_salary + get_bonus(p_salary);
END get_total_income;
/
-- FIXED: added the "/" above so the function is actually created when the
-- file is run as a script.
