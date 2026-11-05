-- List employees in ID order, numbered as a countdown (N, N-1, ..., 1).
--
-- OPTIMIZED: the old block ran TWO queries: SELECT COUNT(*) to get N, then a
-- second query to list the rows, and counted down in PL/SQL. An analytic
-- function computes the countdown number in the SAME query:
--     ROW_NUMBER() OVER (ORDER BY employee_id DESC)
-- gives the highest ID number 1 and the lowest ID number N.
-- One query, one scan, and the number can never drift out of sync with the
-- rows (e.g. if someone inserts an employee between the two old queries).

SET SERVEROUTPUT ON;

BEGIN
    FOR rec IN (
        SELECT employee_id, first_name, last_name,
               ROW_NUMBER() OVER (ORDER BY employee_id DESC) AS countdown
        FROM employees
        ORDER BY employee_id  -- normal order
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(rec.countdown || '. ' ||
            rec.employee_id || ' - ' ||
            rec.first_name || ' ' ||
            rec.last_name
        );
    END LOOP;
END;
/
