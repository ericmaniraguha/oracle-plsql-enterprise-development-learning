/* ============================================================
   PRACTICAL QUESTION: DATABASE LOGIN RESTRICTION TRIGGER

   Create an Oracle PL/SQL database-level logon trigger to restrict
   database access based on the following working schedule:

   - Monday-Thursday : 08:00 AM - 05:00 PM
   - Friday          : 08:00 AM - 12:00 PM
   - Saturday/Sunday : no login allowed
   - Exceptions      : SYS, SYSTEM and DBA_ADMIN can log in at any time

   Tasks:
   1. Create the trigger TRG_RESTRICT_LOGIN_HOURS.
   2. Use SYS_CONTEXT to identify the user attempting to log in.
   3. Use RAISE_APPLICATION_ERROR to display a message when login is denied.
   4. Write a query to check whether the trigger is enabled.
   Test: try logging in during permitted and restricted hours.
   ============================================================ */

/* ============================================================
   READ BEFORE RUNNING
   - Run as SYSTEM (or a user with ADMINISTER DATABASE TRIGGER).
   - Users who HAVE the ADMINISTER DATABASE TRIGGER privilege (e.g. the
     DBA role) are NEVER blocked by an error in a logon trigger: Oracle
     logs them in anyway. So test with an ORDINARY user (Step 4).
   - Times come from SYSDATE = the clock of the DATABASE SERVER.
   - "Until 05:00 PM" means up to 16:59; from 17:00 login is refused
     (same for 12:00 on Friday).
   - Days are read with NLS_DATE_LANGUAGE=ENGLISH so 'MON', 'TUE', ...
     work whatever the session language is.
   - Emergency switch (as SYS/SYSTEM):
         ALTER TRIGGER trg_restrict_login_hours DISABLE;
   ============================================================ */


/* ============================================================
   STEP 1: HELPER FUNCTION - THE SCHEDULE RULE
   Putting the rule in a function lets us TEST it for any date/time
   (Step 5) without waiting for Saturday or changing the server clock.
   Returns 'Y' (allowed) or 'N' (denied).
   ============================================================ */
CREATE OR REPLACE FUNCTION fn_is_login_allowed (
    p_username IN VARCHAR2,
    p_when     IN DATE DEFAULT SYSDATE
) RETURN VARCHAR2
IS
    v_day  VARCHAR2(3);
    v_time NUMBER;          -- HH24MI as a number, e.g. 08:30 -> 830
BEGIN
    -- Exceptions: these accounts may log in at any time
    IF UPPER(p_username) IN ('SYS', 'SYSTEM', 'DBA_ADMIN') THEN
        RETURN 'Y';
    END IF;

    v_day  := TO_CHAR(p_when, 'DY', 'NLS_DATE_LANGUAGE=ENGLISH');
    v_time := TO_NUMBER(TO_CHAR(p_when, 'HH24MI'));

    CASE
        WHEN v_day IN ('MON', 'TUE', 'WED', 'THU') THEN
            IF v_time >= 800 AND v_time < 1700 THEN RETURN 'Y'; END IF;
        WHEN v_day = 'FRI' THEN
            IF v_time >= 800 AND v_time < 1200 THEN RETURN 'Y'; END IF;
        ELSE
            NULL;           -- SAT, SUN: never allowed
    END CASE;

    RETURN 'N';
END fn_is_login_allowed;
/


/* ============================================================
   STEP 2 (TASKS 1, 2, 3): THE LOGON TRIGGER
   ============================================================ */
CREATE OR REPLACE TRIGGER trg_restrict_login_hours
AFTER LOGON ON DATABASE
DECLARE
    -- Task 2: identify the user who is logging in
    v_user VARCHAR2(128) := SYS_CONTEXT('USERENV', 'SESSION_USER');
BEGIN
    IF fn_is_login_allowed(v_user) = 'N' THEN
        -- Task 3: refuse the login with a clear message
        RAISE_APPLICATION_ERROR(
            -20001,
            'Login denied for user ' || v_user
            || '. Allowed hours: Mon-Thu 08:00-17:00, Fri 08:00-12:00, '
            || 'no access on weekends. Server time now: '
            || TO_CHAR(SYSDATE, 'Dy DD-Mon-YYYY HH24:MI', 'NLS_DATE_LANGUAGE=ENGLISH')
        );
    END IF;
END trg_restrict_login_hours;
/


/* ============================================================
   STEP 3 (TASK 4): IS THE TRIGGER CREATED AND ENABLED?
   ============================================================ */
SELECT trigger_name,
       trigger_type,        -- AFTER EVENT
       triggering_event,    -- LOGON
       base_object_type,    -- DATABASE
       status               -- ENABLED / DISABLED
FROM user_triggers
WHERE trigger_name = 'TRG_RESTRICT_LOGIN_HOURS';

-- As a DBA, from any schema:
SELECT owner, trigger_name, triggering_event, status
FROM dba_triggers
WHERE trigger_name = 'TRG_RESTRICT_LOGIN_HOURS';

-- Make sure the function is VALID too (an invalid function blocks logins)
SELECT object_name, object_type, status
FROM user_objects
WHERE object_name IN ('FN_IS_LOGIN_ALLOWED', 'TRG_RESTRICT_LOGIN_HOURS');


/* ============================================================
   STEP 4: TEST WITH A REAL LOGIN (ordinary user)
   ============================================================ */
-- As SYSTEM (in a PDB such as XEPDB1 / FREEPDB1):
-- CREATE USER test_hours IDENTIFIED BY Test123;
-- GRANT CREATE SESSION TO test_hours;

-- Then, from a command prompt:
--     sqlplus test_hours/Test123@localhost:1521/XEPDB1
--
-- During permitted hours  (e.g. Tuesday 10:00)  -> "Connected."
-- During restricted hours (e.g. Friday 14:00 or Saturday) ->
--     ORA-04088: error during execution of trigger 'SYSTEM.TRG_RESTRICT_LOGIN_HOURS'
--     ORA-20001: Login denied for user TEST_HOURS. Allowed hours: ...
--
-- SYSTEM can always log in (exception list), at any hour.
--
-- Tip for class: to see a denial right now, temporarily change the
-- rule (e.g. 'v_time < 1700' -> 'v_time < 0001'), test, then restore it.


/* ============================================================
   STEP 5: TEST THE RULE FOR ANY DATE/TIME (no login needed)
   16-Nov-2026 = Monday, 20-Nov-2026 = Friday,
   21-Nov-2026 = Saturday, 22-Nov-2026 = Sunday
   ============================================================ */
WITH test_cases (username, test_time, expected) AS (
    SELECT 'TEST_HOURS', TO_DATE('16-11-2026 07:59', 'DD-MM-YYYY HH24:MI'), 'N' FROM dual UNION ALL
    SELECT 'TEST_HOURS', TO_DATE('16-11-2026 08:00', 'DD-MM-YYYY HH24:MI'), 'Y' FROM dual UNION ALL
    SELECT 'TEST_HOURS', TO_DATE('16-11-2026 16:59', 'DD-MM-YYYY HH24:MI'), 'Y' FROM dual UNION ALL
    SELECT 'TEST_HOURS', TO_DATE('16-11-2026 17:00', 'DD-MM-YYYY HH24:MI'), 'N' FROM dual UNION ALL
    SELECT 'TEST_HOURS', TO_DATE('20-11-2026 11:59', 'DD-MM-YYYY HH24:MI'), 'Y' FROM dual UNION ALL
    SELECT 'TEST_HOURS', TO_DATE('20-11-2026 12:00', 'DD-MM-YYYY HH24:MI'), 'N' FROM dual UNION ALL
    SELECT 'TEST_HOURS', TO_DATE('21-11-2026 10:00', 'DD-MM-YYYY HH24:MI'), 'N' FROM dual UNION ALL
    SELECT 'TEST_HOURS', TO_DATE('22-11-2026 10:00', 'DD-MM-YYYY HH24:MI'), 'N' FROM dual UNION ALL
    SELECT 'SYSTEM',     TO_DATE('21-11-2026 23:00', 'DD-MM-YYYY HH24:MI'), 'Y' FROM dual UNION ALL
    SELECT 'DBA_ADMIN',  TO_DATE('22-11-2026 03:00', 'DD-MM-YYYY HH24:MI'), 'Y' FROM dual
)
SELECT username,
       TO_CHAR(test_time, 'Dy DD-Mon-YYYY HH24:MI', 'NLS_DATE_LANGUAGE=ENGLISH') AS test_time,
       fn_is_login_allowed(username, test_time) AS allowed,
       expected,
       CASE WHEN fn_is_login_allowed(username, test_time) = expected
            THEN 'PASS' ELSE 'FAIL' END AS result
FROM test_cases;


/* ============================================================
   STEP 6: CLEAN UP (trigger FIRST, then the function)
   Dropping the function while the trigger exists would make the
   trigger invalid and block every ordinary user's login.
   ============================================================ */
-- DROP TRIGGER trg_restrict_login_hours;
-- DROP FUNCTION fn_is_login_allowed;
-- DROP USER test_hours;
