/*
Transform your function to use **bulk collection**, which fetches all rows at once into a collection and then processes them.
This is usually **faster** than fetching row by row.

FIXES (the old script did not compile):
1. CREATE TYPE statements need a "/" on their own line, just like PL/SQL
   blocks. Without it the next statement was swallowed into the type definition.
2. A collection of OBJECTS cannot be filled from plain columns:
       SELECT first_name || ..., salary, salary * 12 BULK COLLECT INTO emp_salaries
   fails (ORA-00947 not enough values / PLS-00642). Each row must be built
   with the object constructor:
       SELECT emp_salary_obj(full_name, salary, salary * 12) BULK COLLECT INTO ...
3. BULK COLLECT never raises NO_DATA_FOUND (it returns an empty collection),
   so that handler was dead code. The "WHEN OTHERS: print and return an empty
   table" handler hid real errors, so it is gone too.
4. The test asked for department 3, which does not exist; it now uses 90.
5. "CREATE OR REPLACE TYPE emp_salary_obj" fails with ORA-02303 on a re-run,
   because emp_salary_table depends on it. FORCE allows the replacement.
*/

/*
1. Create a SQL Object and Collection Types
First, define an object type for each employee's salary info and a nested table type to hold all employees:
*/
-- Object type to store employee salary info
CREATE OR REPLACE TYPE emp_salary_obj FORCE AS OBJECT (
    full_name       VARCHAR2(100),
    monthly_salary  NUMBER,
    annual_salary   NUMBER
);
/

-- Nested table type to hold multiple employee salary objects
CREATE OR REPLACE TYPE emp_salary_table AS TABLE OF emp_salary_obj;
/

/*
 Function Using Bulk Collect
 */


CREATE OR REPLACE FUNCTION get_annual_salaries_bulk(p_dept_id IN employees.department_id%TYPE)
RETURN emp_salary_table
IS
    -- Collection to store all employees
    emp_salaries emp_salary_table;

BEGIN
    -- Bulk collect all rows from employees table.
    -- emp_salary_obj(...) builds one object per row.
    SELECT emp_salary_obj(
               first_name || ' ' || last_name,
               salary,
               salary * 12
           )
    BULK COLLECT INTO emp_salaries
    FROM employees
    WHERE department_id = p_dept_id
    ORDER BY last_name, first_name;

    -- Return the collection (empty, not NULL, when no rows match)
    RETURN emp_salaries;
END;
/

/*
* `BULK COLLECT INTO` fetches all rows at once into the `emp_salaries` collection.
* No explicit cursor loop is needed.
* Returns a nested table of employee salary objects.
*/


/*
3. Displaying the Results
*/
SET SERVEROUTPUT ON;

DECLARE
    v_emp_salaries emp_salary_table;
BEGIN
    -- Get all salaries for department 90
    v_emp_salaries := get_annual_salaries_bulk(90);

    -- Loop through the collection
    FOR i IN 1 .. v_emp_salaries.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE(
            'Name: ' || v_emp_salaries(i).full_name ||
            ', Monthly Salary: ' || v_emp_salaries(i).monthly_salary ||
            ', Annual Salary: ' || v_emp_salaries(i).annual_salary
        );
    END LOOP;
END;
/

/*
4. Bonus: because the types are SQL types, the returned collection can be
   queried like a table with TABLE():
*/
SELECT full_name, monthly_salary, annual_salary
FROM TABLE(get_annual_salaries_bulk(90));

-- This approach **uses bulk collection**, avoids row-by-row fetching, and is much more efficient for large datasets.
-- For very large results, a PIPELINED function (PIPE ROW) streams rows to the
-- caller instead of building the whole collection in memory first.
