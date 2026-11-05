/*
 Function to check either a text input is a palindrome or not

 OPTIMIZED:
 - The old version built a reversed copy of the whole string, one character
   at a time, and then compared the two strings. This version compares the
   first and last characters, moving inwards, and stops at the FIRST
   mismatch. It only walks half the string and builds no new string.
 - FIXED: the reversed copy was VARCHAR2(40), so any input longer than 40
   characters raised ORA-06502 (character string buffer too small).
 - FIXED: a NULL or empty input made the loop bounds NULL; it now simply
   returns 'Not a palindrome'.
 - DETERMINISTIC: same input always gives the same answer.
*/

CREATE OR REPLACE FUNCTION is_palindrome( p_str IN VARCHAR2)
RETURN VARCHAR2
DETERMINISTIC
IS
    v_len PLS_INTEGER := LENGTH(p_str);
BEGIN
    IF p_str IS NULL THEN
        RETURN 'Not a palindrome';
    END IF;

    FOR i IN 1 .. TRUNC(v_len / 2) LOOP
        IF SUBSTR(p_str, i, 1) != SUBSTR(p_str, v_len - i + 1, 1) THEN
            RETURN 'Not a palindrome';   -- stop at the first mismatch
        END IF;
    END LOOP;

    RETURN 'Yes it is a palindrome';
END;
/

/*
 Call or testing the function
*/
SET SERVEROUTPUT ON

BEGIN
    DBMS_OUTPUT.PUT_LINE(is_palindrome('umuvumu'));   -- Yes
    DBMS_OUTPUT.PUT_LINE(is_palindrome('kigali'));    -- Not
    DBMS_OUTPUT.PUT_LINE(is_palindrome(RPAD('a', 60, 'a')));  -- 60 chars: failed before, Yes now
END;
/
