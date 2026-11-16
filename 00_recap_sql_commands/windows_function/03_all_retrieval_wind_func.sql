/*
QUESTION 1:
Using window functions, write a query to retrieve the TOP 10 rows
from the employees table based on employee_id ordering.
*/

SELECT *
FROM (
    SELECT
        employee_id,
        first_name,
        last_name,
        ROW_NUMBER() OVER (ORDER BY employee_id) AS rn
    FROM employees
) t
WHERE rn <= 10
ORDER BY rn;

-- Same result without a window function (Oracle 12c+). The optimizer can
-- read the first 10 entries of the primary key index and stop:
-- SELECT employee_id, first_name, last_name
-- FROM employees
-- ORDER BY employee_id
-- FETCH FIRST 10 ROWS ONLY;



/*
QUESTION 2:
Using window functions, write a query to retrieve ONLY the 5th row
from the employees table based on employee_id ordering.
*/

SELECT *
FROM (
    SELECT
        employee_id,
        first_name,
        last_name,
        ROW_NUMBER() OVER (ORDER BY employee_id) AS rn
    FROM employees
) t
WHERE rn = 5;



/*
QUESTION 3:
Using window functions, write a query to retrieve the LAST 2 rows
from the employees table based on employee_id ordering.

OPTIMIZED: number the rows in DESCENDING order and keep rn <= 2.
The old version used COUNT(*) OVER () and "rn > total_rows - 2", which
forces Oracle to number and count EVERY row before filtering. With a
descending ROW_NUMBER the filter is a simple top-N, so Oracle can stop
sorting after 2 rows.
*/

SELECT *
FROM (
    SELECT
        employee_id,
        first_name,
        last_name,
        ROW_NUMBER() OVER (ORDER BY employee_id DESC) AS rn
    FROM employees
) t
WHERE rn <= 2
ORDER BY employee_id;



/*
QUESTION 4:
Using window functions, write a query to retrieve the 5th and 20th rows
from the employees table based on employee_id ordering.
*/

SELECT *
FROM (
    SELECT
        employee_id,
        first_name,
        last_name,
        ROW_NUMBER() OVER (ORDER BY employee_id) AS rn
    FROM employees
) t
WHERE rn IN (5, 20)
ORDER BY rn;
