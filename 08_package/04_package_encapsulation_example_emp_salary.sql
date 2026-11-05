/*
Question:
Create a package that demonstrates encapsulation using an employees table.

The package should:
1. Have a public procedure to display an employee salary
2. Have a public function to calculate annual salary
3. Have a private function to calculate bonus
4. Show that the private function cannot be called outside the package

IMPROVEMENTS:
- The same "SELECT salary ... WHERE employee_id = ..." was written twice
  (in show_salary and annual_salary). It now lives in ONE private function,
  get_salary. Encapsulation also means "don't repeat yourself": the query can
  change in one place.
- FIXED: the tests used employee IDs 1 and 25, which do not exist (HR IDs run
  from 100 to 206). Worse, when a function called from SQL raises
  NO_DATA_FOUND, Oracle returns NULL instead of an error, so
  "SELECT employee_pkg.annual_salary(25) FROM dual" silently showed NULL.
  get_salary now converts NO_DATA_FOUND into a clear ORA-20001 error.
- Parameters use employees.employee_id%TYPE.
*/

--====================================================
-- Package Specification
--====================================================
CREATE OR REPLACE PACKAGE employee_pkg IS

                /*Public Store Procedure
                A procedure that takes an employee ID
                It will display or process the employee's salary
                It does NOT return a value
                */
    PROCEDURE show_salary(p_employee_id IN employees.employee_id%TYPE);

                /* Public Function
                A function that takes an employee ID
                It returns a NUMBER (annual salary)
                The logic is defined in the package body
                */
    FUNCTION annual_salary(p_employee_id IN employees.employee_id%TYPE) RETURN NUMBER;
-- END of specification
END employee_pkg;
/
--====================================================
-- Package Body
--====================================================
CREATE OR REPLACE PACKAGE BODY employee_pkg IS

    -- Private function: the ONE place that reads an employee's salary
    FUNCTION get_salary(p_employee_id IN employees.employee_id%TYPE)
    RETURN employees.salary%TYPE IS
        v_salary employees.salary%TYPE;
    BEGIN
        SELECT salary
        INTO v_salary
        FROM employees
        WHERE employee_id = p_employee_id;

        RETURN v_salary;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Employee ID ' || p_employee_id || ' does not exist.');
    END get_salary;

    -- Private function
    FUNCTION calculate_bonus(p_salary IN NUMBER) RETURN NUMBER IS
    BEGIN
        RETURN p_salary * 0.10;
    END calculate_bonus;

    -- Public procedure
    PROCEDURE show_salary(p_employee_id IN employees.employee_id%TYPE) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('Salary: ' || get_salary(p_employee_id));
    END show_salary;

    -- Public function
    FUNCTION annual_salary(p_employee_id IN employees.employee_id%TYPE) RETURN NUMBER IS
        v_salary employees.salary%TYPE := get_salary(p_employee_id);
    BEGIN
        RETURN (v_salary * 12) + calculate_bonus(v_salary);
    END annual_salary;

END employee_pkg;
/

SET SERVEROUTPUT ON;

-- Call the public procedure
BEGIN
    employee_pkg.show_salary(100);
END;
/

-- Call the public function
SELECT employee_pkg.annual_salary(101) AS total_salary
FROM dual;

-- This will cause an error because calculate_bonus
-- is private inside the package body
SELECT employee_pkg.calculate_bonus(50000)
FROM dual;


/*Simple analogy

Think of it like a mobile app:

Specification = App buttons (what you can click)
Package body = Code behind the buttons (how it works)
*/
