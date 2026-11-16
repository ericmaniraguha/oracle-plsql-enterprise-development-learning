/*

Write a PL/SQL procedure to delete a record from the ALLOWANCES table by ID.
Use implicit cursor attributes (SQL%FOUND, SQL%ROWCOUNT, SQL%ISOPEN) to display the result,
and include exception handling with rollback.

FIXES:
- SQL%ROWCOUNT is copied into a variable IMMEDIATELY after the DELETE.
  Implicit cursor attributes describe the MOST RECENT SQL statement, so
  reading them later (after other SQL runs) gives the wrong answer.
- Removed "WHEN OTHERS THEN ROLLBACK; PUT_LINE": a single DELETE is atomic
  (if it fails, Oracle undoes it automatically), the bare ROLLBACK also
  undid the CALLER's unrelated work, and the error was swallowed.
- The procedure does not commit; the caller decides.
- The test uses ID 21. ALLOWANCES IDs start at 21 (see 03_populate_tables.sql),
  so the old example ID 101 never existed.

*/


SET SERVEROUTPUT ON SIZE 100000;

CREATE OR REPLACE PROCEDURE delete_allowance(p_allowance_id IN allowances.allowance_id%TYPE) AS
    v_rows_deleted PLS_INTEGER;
BEGIN
    -- Attempt to delete a row (uses the primary key index)
    DELETE FROM ALLOWANCES
    WHERE ALLOWANCE_ID = p_allowance_id;

    v_rows_deleted := SQL%ROWCOUNT;   -- capture right away

    -- Check result
    IF SQL%FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Allowance with ID ' || p_allowance_id || ' deleted successfully.');
        DBMS_OUTPUT.PUT_LINE('Rows deleted: ' || v_rows_deleted);
    ELSE
        DBMS_OUTPUT.PUT_LINE('No allowance found with ID ' || p_allowance_id);
    END IF;

    -- Check cursor status
    -- SQL%ISOPEN is ALWAYS FALSE: Oracle closes the implicit cursor
    -- automatically as soon as the statement finishes.
    IF SQL%ISOPEN THEN
        DBMS_OUTPUT.PUT_LINE('Cursor is open.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Implicit cursor is closed.');
    END IF;
END;
/

--Test my procedure

BEGIN
    -- Call the procedure with an example ID
    delete_allowance(21);   -- exists
    delete_allowance(101);  -- does not exist
    ROLLBACK;               -- demo only: undo the delete (use COMMIT to keep it)
END;
/
