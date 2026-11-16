
/*
02_create_indexes.sql

-- Indexes:
Indexes are special lookup tables that the database can use to speed up data retrieval.
Think of them like the index in a book: they allow Oracle to quickly find rows in large tables
without scanning the entire table.
We create indexes on columns that are frequently used in WHERE clauses, JOINs, or ORDER BY.

OPTIMIZATION NOTES:
- Every index speeds up reads but slows down INSERT/UPDATE/DELETE, so each one
  must earn its place.
- REMOVED jhist_employee_ix ON job_history (employee_id): the primary key index
  jhist_emp_id_st_date_pk is on (employee_id, start_date). Its leading column is
  already employee_id, so Oracle can use it for "WHERE employee_id = ..." and for
  the foreign key. The extra index only added DML overhead.
- ADDED dept_mgr_ix ON departments (manager_id): departments.manager_id is a
  foreign key to employees. Without an index on it, every DELETE of an employee
  (or update of employee_id) must full-scan DEPARTMENTS and takes a table-level
  lock on it. Rule of thumb: index foreign key columns.
*/

CREATE INDEX emp_department_ix
ON employees (department_id);

CREATE INDEX emp_job_ix
ON employees (job_id);

CREATE INDEX emp_manager_ix
ON employees (manager_id);

CREATE INDEX emp_name_ix
ON employees (last_name, first_name);

CREATE INDEX dept_location_ix
ON departments (location_id);

CREATE INDEX dept_mgr_ix
ON departments (manager_id);

CREATE INDEX jhist_job_ix
ON job_history (job_id);

CREATE INDEX jhist_department_ix
ON job_history (department_id);

CREATE INDEX loc_city_ix
ON locations (city);

CREATE INDEX loc_state_province_ix
ON locations (state_province);

CREATE INDEX loc_country_ix
ON locations (country_id);

-- No COMMIT needed: CREATE INDEX is DDL and Oracle commits DDL automatically.
