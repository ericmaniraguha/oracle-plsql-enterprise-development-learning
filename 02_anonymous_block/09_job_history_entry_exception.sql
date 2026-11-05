-- ========================================================
-- Exercise 9: Job History Entry with Exception Handling
-- ========================================================
DECLARE
    v_emp_id employees.employee_id%TYPE := 101; -- example employee
    v_start_date DATE := DATE '2026-01-01';     -- ANSI date literal: no format mask needed
    v_end_date DATE := DATE '2026-03-31';
    v_job_id jobs.job_id%TYPE := 'IT_PROG';
    v_dept_id departments.department_id%TYPE := 60;

    -- User-defined exception
    e_invalid_dates EXCEPTION;

    -- FIXED: an INSERT never raises NO_DATA_FOUND. A missing employee, job, or
    -- department raises ORA-02291 (parent key not found). PRAGMA EXCEPTION_INIT
    -- gives that error a name so we can handle it explicitly.
    e_parent_not_found EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_parent_not_found, -2291);
BEGIN
    -- Validate dates
    -- FIXED: was "<". The table's CHECK constraint is end_date > start_date,
    -- so equal dates are invalid too.
    IF v_end_date <= v_start_date THEN
        RAISE e_invalid_dates;
    END IF;

    -- Insert job history record
    INSERT INTO job_history(employee_id, start_date, end_date, job_id, department_id)
    VALUES(v_emp_id, v_start_date, v_end_date, v_job_id, v_dept_id);

    DBMS_OUTPUT.PUT_LINE('Job history inserted for employee ID ' || v_emp_id);
    COMMIT;

EXCEPTION
    -- User-defined exception handler
    WHEN e_invalid_dates THEN
        DBMS_OUTPUT.PUT_LINE('Error: End date must be later than start date.');

    -- Predefined exceptions
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE('Error: Duplicate job history entry for this employee.');
    WHEN e_parent_not_found THEN
        DBMS_OUTPUT.PUT_LINE('Error: Employee, job, or department does not exist.');

    -- Report, then re-raise: never hide an unexpected error.
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Unexpected error: ' || SQLERRM);
        RAISE;
END;
/
-- ========================================================
