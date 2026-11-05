/*
EMS: SAVEPOINT and ROLLBACK inside a procedure (update_employee_bonus)

WHAT CHANGED AND WHY
--------------------
This file used to hold three copies of the same procedure plus scratch
statements. It is now one script you can run top to bottom, as many times as
you like.

Fixed bugs:
1. "END;/" on one line is not valid SQL*Plus syntax; the "/" must be on its
   own line.
2. Employee 114 (Den Raphaely) and his job_history row already exist in the
   HR seed data, so the sample INSERTs failed with ORA-00001. "INSERT INTO
   employees (employee_id, bonus)" also failed because LAST_NAME, EMAIL,
   HIRE_DATE and JOB_ID are NOT NULL. The script now uses the existing rows.
3. The EMPLOYEES table had no BONUS column. Step 1 adds it, only if missing.
4. SAVEPOINT was created AFTER the two SELECTs. When the employee did not
   exist, the first SELECT raised NO_DATA_FOUND, and the handler's
   "ROLLBACK TO before_update" failed with ORA-01086 (savepoint never
   established). The savepoint is now the first statement.
5. Employees WITHOUT job history could not get a bonus at all, because the
   job_history SELECT raised NO_DATA_FOUND ("not found in job_history").
   Only a few employees have history rows, so most calls failed. A missing
   history row is now allowed.
6. "ROWNUM = 1" picked an arbitrary job_history row; the code now takes the
   most recent one (ORDER BY start_date DESC FETCH FIRST 1 ROW ONLY).
7. Errors were printed and swallowed, so callers could not tell the update
   had failed. Errors are now rolled back to the savepoint and re-raised.

Optimization:
- SELECT ... FOR UPDATE reads the current bonus AND locks the row, so no other
  session can change it between our read and our UPDATE (no "lost update").
  It also proves the employee exists, so no separate existence check is needed.
*/

SET SERVEROUTPUT ON;

-- 1. Add the BONUS column used by this lesson (skipped if it already exists)
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE employees ADD (bonus NUMBER(8,2))';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -1430 THEN   -- -1430 = column being added already exists
            RAISE;
        END IF;
END;
/

-- 2. Sample data
--    Employee 114 (Den Raphaely) and one job_history row for him are created
--    by 03_populate_tables.sql in the 01_createTable folder. Nothing to insert.

-- 3. Create procedure to update bonus with SAVEPOINT
CREATE OR REPLACE PROCEDURE update_employee_bonus (
    p_emp_id IN employees.employee_id%TYPE,
    p_bonus  IN employees.bonus%TYPE
) AS
    v_current_bonus employees.bonus%TYPE;
    v_job_id        job_history.job_id%TYPE;
    v_dept_id       job_history.department_id%TYPE;
BEGIN
    -- Savepoint FIRST, so every handler below can safely roll back to it.
    -- ROLLBACK TO before_update undoes only THIS procedure's work, not
    -- changes the caller made earlier in the same transaction.
    SAVEPOINT before_update;

    -- Validate input before touching the table
    IF p_bonus IS NULL OR p_bonus < 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Bonus must be zero or a positive amount.');
    END IF;

    -- Read the current bonus and lock the employee row.
    -- NO_DATA_FOUND here means the employee does not exist.
    SELECT bonus
    INTO v_current_bonus
    FROM employees
    WHERE employee_id = p_emp_id
    FOR UPDATE;

    -- Most recent job_history entry, if there is one.
    -- No history is a normal case, so it is handled right here.
    BEGIN
        SELECT job_id, department_id
        INTO v_job_id, v_dept_id
        FROM job_history
        WHERE employee_id = p_emp_id
        ORDER BY start_date DESC
        FETCH FIRST 1 ROW ONLY;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_job_id  := NULL;   -- no history: report job/department as empty
            v_dept_id := NULL;
    END;

    -- Update bonus (the row exists: we locked it above)
    UPDATE employees
    SET bonus = p_bonus
    WHERE employee_id = p_emp_id;

    -- Output result
    DBMS_OUTPUT.PUT_LINE(
        'Employee ID: ' || p_emp_id ||
        ' | Old Bonus: ' || NVL(v_current_bonus, 0) ||
        ' | New Bonus: ' || p_bonus ||
        ' | Last Job: ' || NVL(v_job_id, 'none') ||
        ' | Last Dept: ' || NVL(TO_CHAR(v_dept_id), 'none')
    );

    -- This lesson commits inside the procedure to show the full
    -- SAVEPOINT / ROLLBACK / COMMIT cycle. In real applications the
    -- caller usually owns the COMMIT.
    -- COMMIT is the LAST statement: it erases all savepoints, so nothing
    -- that might fail (and need ROLLBACK TO before_update) may come after it.
    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK TO before_update;
        RAISE_APPLICATION_ERROR(-20002, 'Employee ID ' || p_emp_id || ' does not exist.');
    WHEN OTHERS THEN
        ROLLBACK TO before_update;   -- undo our work and release the row lock
        RAISE;                       -- never hide the real error
END update_employee_bonus;
/

-- 4. Test the procedure
-- 4.1 Valid employee (Den Raphaely, has job history)
BEGIN
    update_employee_bonus(114, 1500);
END;
/

-- 4.2 Valid employee WITHOUT job history (Steven King). This failed before.
BEGIN
    update_employee_bonus(100, 2000);
END;
/

-- 4.3 Employee does not exist (expected: ORA-20002)
BEGIN
    update_employee_bonus(999, 500);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Expected error: ' || SQLERRM);
END;
/

-- 4.4 Invalid bonus (expected: ORA-20001)
BEGIN
    update_employee_bonus(114, -10);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Expected error: ' || SQLERRM);
END;
/

-- 5. Verify update
SELECT employee_id, first_name, last_name, bonus
FROM employees
WHERE employee_id IN (100, 114)
ORDER BY employee_id;
