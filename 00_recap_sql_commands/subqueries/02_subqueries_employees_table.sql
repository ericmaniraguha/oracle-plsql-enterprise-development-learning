-- ============================================
-- SUBQUERY EXERCISES
-- ============================================

-- EX1:
-- Find employees who earn more than the average salary.

-- EX2:
-- Find employees who work in the same department as 'Bruce'.

-- EX3:
-- Find employees whose salary is higher than the salary of 'Alice'.

-- EX4:
-- Find employees working in departments with more than 1 employee.

-- EX5:
-- Find the employee(s) with the highest salary.

-- EX6:
-- Find employees who are NOT assigned to any department
-- (use subquery instead of direct NULL check).

-- EX7:
-- Find departments that have no employees.

-- EX8:
-- Find employees whose salary is above the average salary of their department
-- (correlated subquery).


-- ============================================
-- ANSWERS
-- ============================================

-- ANS1 (Single-row subquery)
SELECT first_name, salary
FROM employees
WHERE salary > (
    SELECT AVG(salary)
    FROM employees
);


-- ANS2
-- FIXED: use IN, not "=". first_name is not unique; if two employees are
-- called Bruce, "=" fails with ORA-01427 (single-row subquery returns more
-- than one row). IN works for one or many matches.
SELECT first_name, department_id
FROM employees
WHERE department_id IN (
    SELECT department_id
    FROM employees
    WHERE first_name = 'Bruce'
);


-- ANS3
-- FIXED: MAX() always returns exactly one row, so this cannot raise
-- ORA-01427 when several employees share the name.
-- Note: the HR seed data has no 'Alice' (MAX returns NULL, so no rows).
-- Try 'Lex' to see results.
SELECT first_name, salary
FROM employees
WHERE salary > (
    SELECT MAX(salary)
    FROM employees
    WHERE first_name = 'Alice'
);


-- ANS4 (GROUP BY + subquery)
SELECT first_name, department_id
FROM employees
WHERE department_id IN (
    SELECT department_id
    FROM employees
    GROUP BY department_id
    HAVING COUNT(*) > 1
);


-- ANS5 (MAX)
SELECT first_name, salary
FROM employees
WHERE salary = (
    SELECT MAX(salary)
    FROM employees
);


-- ANS6 (NOT EXISTS)
-- FIXED: the old version used "department_id NOT IN (SELECT ...)" and
-- returned NO rows. For an employee whose department_id is NULL,
-- "NULL NOT IN (...)" evaluates to UNKNOWN, never TRUE, so exactly the
-- employees we are looking for were filtered out.
-- NOT EXISTS has no NULL trap, and Oracle runs it as an efficient anti-join.
SELECT e.first_name
FROM employees e
WHERE NOT EXISTS (
    SELECT 1
    FROM departments d
    WHERE d.department_id = e.department_id
);


-- ANS7 (NOT EXISTS)
-- OPTIMIZED: NOT EXISTS needs no "IS NOT NULL" guard and is the safer
-- default for anti-joins. It uses the emp_department_ix index.
SELECT d.department_name
FROM departments d
WHERE NOT EXISTS (
    SELECT 1
    FROM employees e
    WHERE e.department_id = d.department_id
);


-- ANS8 (CORRELATED SUBQUERY)
SELECT e.first_name, e.salary, e.department_id
FROM employees e
WHERE e.salary > (
    SELECT AVG(salary)
    FROM employees
    WHERE department_id = e.department_id
);

-- ANS8 (OPTIMIZED: analytic function, one pass over EMPLOYEES)
-- The correlated subquery may re-compute the average for every outer row.
-- AVG() OVER (PARTITION BY ...) computes every department average in the
-- same single scan of the table.
SELECT first_name, salary, department_id
FROM (
    SELECT first_name, salary, department_id,
           AVG(salary) OVER (PARTITION BY department_id) AS dept_avg
    FROM employees
)
WHERE salary > dept_avg;
