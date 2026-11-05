/*
Explicit cursor that updates the rows it reads (10% raise for department 30).

FIXES:
1. ROLLBACK inside the loop undid ALL earlier updates (every employee
   processed so far), then the loop carried on, COMMITted the rest, and
   printed "All updates processed successfully!". Now each row gets its own
   SAVEPOINT, so a failure undoes ONLY that row, and the summary reports
   exactly how many rows succeeded and failed.
2. Added the "/" terminator; without it the block never ran.

OPTIMIZATIONS:
- FOR UPDATE OF salary locks the department-30 rows when the cursor opens,
  so no other session can change them while we work.
- WHERE CURRENT OF c_emp updates the row the cursor is positioned on, using
  its ROWID directly. The old "WHERE employee_id = v_id" had to look the row
  up again through the primary key index.
- If you do NOT need per-row logic, one statement is fastest of all:
      UPDATE employees SET salary = salary * 1.1 WHERE department_id = 30;
*/

SET SERVEROUTPUT ON SIZE 100000;

DECLARE
    CURSOR c_emp IS
        SELECT employee_id, salary
        FROM employees
        WHERE department_id = 30
        FOR UPDATE OF salary;

    -- Demo: this employee's update will fail on purpose (the old code used 207,
    -- an ID that does not exist, so the error path never ran). Set it to NULL
    -- to update everyone.
    c_fail_on_emp CONSTANT employees.employee_id%TYPE := 115;

    v_id       employees.employee_id%TYPE;
    v_salary   employees.salary%TYPE;
    v_updated  PLS_INTEGER := 0;
    v_failed   PLS_INTEGER := 0;
BEGIN
    OPEN c_emp;
    LOOP
        FETCH c_emp INTO v_id, v_salary;
        EXIT WHEN c_emp%NOTFOUND;

        -- Example: Update salary, one row at a time
        BEGIN
            SAVEPOINT before_row;   -- undo point for THIS row only

            UPDATE employees
            SET salary = salary * 1.1
            WHERE CURRENT OF c_emp;

            -- Simulate error
            IF v_id = c_fail_on_emp THEN
                RAISE_APPLICATION_ERROR(-20001, 'Demo rollback on employee ' || v_id);
            END IF;

            v_updated := v_updated + 1;

        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK TO before_row;  -- undoes this employee's update only
                v_failed := v_failed + 1;
                DBMS_OUTPUT.PUT_LINE('Error for employee ' || v_id || ', row rolled back: ' || SQLERRM);
        END;
    END LOOP;
    CLOSE c_emp;

    -- Commit AFTER the loop. A COMMIT inside a FOR UPDATE loop releases the
    -- locks, and the next FETCH fails with ORA-01002 (fetch out of sequence).
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Rows updated: ' || v_updated || ' | Rows failed: ' || v_failed);
END;
/
