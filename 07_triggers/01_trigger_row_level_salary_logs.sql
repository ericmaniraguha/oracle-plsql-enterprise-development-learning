/*
ROW-LEVEL trigger: one audit row for EACH employee whose salary changes.
(Compare with 01_triggers_audit_salary_stmt_level.sql: one row per STATEMENT.)

OPTIMIZATIONS / FIXES:
- "AFTER UPDATE OF salary": the trigger now fires only when the UPDATE's SET
  clause includes SALARY. "AFTER UPDATE" fired for every update of any column
  (phone number, email, ...), and evaluated the WHEN clause each time.
- WHEN clause is NULL-safe. "OLD.salary != NEW.salary" is UNKNOWN when either
  side is NULL, so changes from NULL to a value (or back) were never logged.
- Removed the inner "WHEN OTHERS THEN PUT_LINE": if the audit INSERT fails,
  the salary change must fail too. Otherwise salaries change with no audit
  trail, which defeats the purpose of auditing.
- Removed the unused variable v_dummy.
- Added CHANGED_BY so the audit records WHO made the change.
- The demo no longer COMMITs "salary + 500" for EVERY employee (re-running the
  script kept raising all salaries). It updates one department, shows the
  audit rows, then ROLLs BACK.
*/

-- 1. Drop previous audit table if exists (optional cleanup)
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE salary_audit';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN -- -942 = table does not exist
            RAISE;
        END IF;
END;
/

-- 2. Create audit table
CREATE TABLE salary_audit (
    employee_id NUMBER(6),
    old_salary  NUMBER(8,2),
    new_salary  NUMBER(8,2),
    changed_by  VARCHAR2(128) DEFAULT USER,
    change_date DATE          DEFAULT SYSDATE
);

-- 3. Create the row-level trigger
CREATE OR REPLACE TRIGGER log_salary_changes
AFTER UPDATE OF salary ON employees
FOR EACH ROW
WHEN (   OLD.salary <> NEW.salary
      OR (OLD.salary IS NULL AND NEW.salary IS NOT NULL)
      OR (OLD.salary IS NOT NULL AND NEW.salary IS NULL))
BEGIN
    INSERT INTO salary_audit (employee_id, old_salary, new_salary)
    VALUES (:OLD.employee_id, :OLD.salary, :NEW.salary);
    -- changed_by and change_date come from the column DEFAULTs
END;
/

-- 4. Update salaries to trigger the audit (department 60: 5 employees)
UPDATE employees
SET salary = salary + 500
WHERE department_id = 60;

-- 5. Query the audit table to see the logged changes (one row per employee)
SELECT * FROM salary_audit ORDER BY employee_id;

-- 6. Demo only: undo the raise (and its audit rows). Use COMMIT to keep them.
ROLLBACK;
