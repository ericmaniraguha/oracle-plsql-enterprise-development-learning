/* ============================================================
   TITLE: Introduction to PIPELINED Functions in Oracle PL/SQL

   1. UNDERSTANDING THE CONCEPT
   ----------------------------
   A PIPELINED FUNCTION returns rows ONE AT A TIME (or in batches)
   instead of returning the entire collection at once.

   - A normal PL/SQL function that returns a collection processes ALL
     records first, then returns the complete collection.
   - A pipelined function uses PIPE ROW to send each row to the calling
     SQL statement AS SOON AS IT IS GENERATED.

   This is especially useful for large datasets: Oracle processes and
   consumes rows progressively, which saves memory.

   KEY CHARACTERISTICS
   - Uses the PIPELINED keyword.
   - Uses PIPE ROW() to return individual rows.
   - Returns a COLLECTION type.
   - Can be queried like a database table with SELECT.
   - Processes large datasets without building the whole result
     collection in memory.

   TEACHING TIP
   - Normal function    : prepare ALL records, then return them.
   - Pipelined function : generate a record, send it,
                          generate another, send it, ...
   ============================================================ */


/* ============================================================
   STEP 0: CLEAN START (functions first, then the types)
   ============================================================ */
BEGIN
    FOR o IN (SELECT object_name, object_type FROM user_objects
              WHERE object_name IN ('GET_EMPLOYEES', 'GET_EMPLOYEES_NORMAL',
                                    'GET_HR_EMPLOYEES',
                                    'EMPLOYEE_TABLE', 'EMPLOYEE_OBJ')
              ORDER BY DECODE(object_type, 'FUNCTION', 1, 2),
                       DECODE(object_name, 'EMPLOYEE_TABLE', 1, 2)) LOOP
        EXECUTE IMMEDIATE 'DROP ' || o.object_type || ' '
                          || DBMS_ASSERT.ENQUOTE_NAME(o.object_name);
    END LOOP;
END;
/


/* ============================================================
   2. PRACTICAL EXAMPLE
   ============================================================ */

/* ------------------------------------------------------------
   STEP 1: CREATE AN OBJECT TYPE  (= the structure of ONE row)
   ------------------------------------------------------------ */
CREATE OR REPLACE TYPE employee_obj AS OBJECT (
    employee_id   NUMBER,
    employee_name VARCHAR2(100),
    salary        NUMBER
);
/

/* ------------------------------------------------------------
   STEP 2: CREATE A COLLECTION TYPE  (= many rows)
   ------------------------------------------------------------ */
CREATE OR REPLACE TYPE employee_table AS TABLE OF employee_obj;
/

/* ------------------------------------------------------------
   STEP 3: CREATE THE PIPELINED FUNCTION
   Each PIPE ROW(employee_obj(...)) sends ONE employee record
   to the calling SQL statement immediately.
   ------------------------------------------------------------ */
CREATE OR REPLACE FUNCTION get_employees
RETURN employee_table
PIPELINED
IS
BEGIN
    PIPE ROW (employee_obj(1, 'John',  500000));
    PIPE ROW (employee_obj(2, 'Mary',  600000));
    PIPE ROW (employee_obj(3, 'Peter', 700000));

    RETURN;     -- ends the function (returns no value: rows are already sent)
END get_employees;
/

/* ------------------------------------------------------------
   STEP 4: EXECUTE THE FUNCTION

   Expected output:
   EMPLOYEE_ID  EMPLOYEE_NAME  SALARY
   -----------  -------------  ------
             1  John           500000
             2  Mary           600000
             3  Peter          700000
   ------------------------------------------------------------ */
SELECT *
FROM TABLE(get_employees());

-- Like a table: choose columns, filter, sort, aggregate
SELECT employee_name, salary
FROM TABLE(get_employees())
WHERE salary >= 600000
ORDER BY salary DESC;

SELECT COUNT(*) AS employees, SUM(salary) AS total_salary
FROM TABLE(get_employees());

-- Oracle 18c and later: TABLE( ) may be omitted
-- SELECT * FROM get_employees();


/* ============================================================
   3. HOW DOES IT WORK?

     SELECT * FROM TABLE(get_employees());     <- calling SQL statement
                   |
                   v
            get_employees()                     <- pipelined function
                   |
        PIPE ROW --> John   --+
        PIPE ROW --> Mary   --+--> SQL result set (3 employee records)
        PIPE ROW --> Peter  --+
                   |
                RETURN;                         <- function ends
   ============================================================ */


/* ============================================================
   4. NORMAL vs PIPELINED - SAME RESULT, DIFFERENT DELIVERY

   | Feature        | Normal function             | Pipelined function         |
   |----------------|-----------------------------|----------------------------|
   | Return type    | Scalar or collection        | Collection                 |
   | Returning rows | Returns the full collection | Returns rows progressively |
   | Main keyword   | RETURN <collection>         | PIPELINED + PIPE ROW       |
   | Row delivery   | After ALL processing        | As rows are produced       |
   | Memory         | Holds the full collection   | Can reduce memory usage    |
   ============================================================ */

-- 4.1 NORMAL version: builds the whole collection, then returns it
CREATE OR REPLACE FUNCTION get_employees_normal
RETURN employee_table
IS
    v_list employee_table := employee_table();     -- empty collection
BEGIN
    v_list.EXTEND;  v_list(v_list.LAST) := employee_obj(1, 'John',  500000);
    v_list.EXTEND;  v_list(v_list.LAST) := employee_obj(2, 'Mary',  600000);
    v_list.EXTEND;  v_list(v_list.LAST) := employee_obj(3, 'Peter', 700000);

    RETURN v_list;  -- everything is returned at the end
END get_employees_normal;
/

-- Same output as the pipelined version
SELECT * FROM TABLE(get_employees_normal());

-- 4.2 A normal function CAN be used directly in PL/SQL ...
DECLARE
    v_list employee_table;
BEGIN
    v_list := get_employees_normal();
    DBMS_OUTPUT.PUT_LINE('Normal function returned ' || v_list.COUNT || ' rows');
END;
/

-- ... a PIPELINED function CANNOT (uncomment to see the error PLS-00653):
-- DECLARE
--     v_list employee_table;
-- BEGIN
--     v_list := get_employees();
-- END;
-- /

-- From PL/SQL, read a pipelined function with a query:
BEGIN
    FOR r IN (SELECT * FROM TABLE(get_employees())) LOOP
        DBMS_OUTPUT.PUT_LINE(r.employee_id || ' - ' || r.employee_name
                             || ' - ' || r.salary);
    END LOOP;
END;
/


/* ============================================================
   5. IMPORTANT PL/SQL CONCEPTS

   | Keyword    | Purpose                                      |
   |------------|----------------------------------------------|
   | PIPELINED  | Declares a pipelined table function          |
   | PIPE ROW() | Sends one row to the caller                  |
   | RETURN;    | Ends the function (no value)                 |
   | TABLE()    | Lets SQL query the returned collection       |

   IMPORTANT: a pipelined function cannot be called like an ordinary
   scalar function, and it cannot be assigned to a variable in PL/SQL
   (v := get_employees(); -> PLS-00653). It is queried with the TABLE()
   operator in the FROM clause.
   ============================================================ */


/* ============================================================
   STEP 5: FROM HARD-CODED ROWS TO REAL DATA (HR schema)
   Same types, but the rows now come from the EMPLOYEES table.
   ============================================================ */
CREATE OR REPLACE FUNCTION get_hr_employees (
    p_department_id IN NUMBER DEFAULT NULL       -- NULL = all departments
) RETURN employee_table
PIPELINED
IS
BEGIN
    FOR r IN (
        SELECT employee_id,
               first_name || ' ' || last_name AS employee_name,
               salary
        FROM employees
        WHERE p_department_id IS NULL
           OR department_id = p_department_id
        ORDER BY employee_id
    ) LOOP
        PIPE ROW (employee_obj(r.employee_id, r.employee_name, r.salary));
    END LOOP;
    RETURN;
END get_hr_employees;
/

SELECT * FROM TABLE(get_hr_employees(60));        -- IT department

SELECT * FROM TABLE(get_hr_employees())           -- all employees
WHERE salary > 10000
ORDER BY salary DESC;

-- Confirm which functions are pipelined
SELECT object_name, pipelined
FROM user_procedures
WHERE object_name IN ('GET_EMPLOYEES', 'GET_EMPLOYEES_NORMAL', 'GET_HR_EMPLOYEES');


/* ============================================================
   6. WHEN SHOULD YOU USE PIPELINED FUNCTIONS?
   - Processing millions of records.
   - Transforming large datasets (ETL)      -> see 04_etl_parallel_pipelined_payroll_load.sql
   - Building reusable data-processing logic -> see 01_split_string_pipelined.sql
   - Integrating PL/SQL processing with SQL queries
   - Avoiding materialising an entire collection before returning results

   NEXT LESSONS IN THIS FOLDER
   - 11_pipelined_table_functions.sql            : more examples, BULK COLLECT, NO_DATA_NEEDED
   - 01_split_string_pipelined.sql               : string -> rows
   - 02_calendar_working_days_pipelined.sql      : generate rows (calendar)
   - 03_package_pipelined_dept_summary_org_chart : types in a package
   - 04_etl_parallel_pipelined_payroll_load.sql  : ETL with PARALLEL_ENABLE
   ============================================================ */


/* ============================================================
   CLEAN UP (functions first, then the types)
   ============================================================ */
-- DROP FUNCTION get_hr_employees;
-- DROP FUNCTION get_employees_normal;
-- DROP FUNCTION get_employees;
-- DROP TYPE employee_table;
-- DROP TYPE employee_obj;
