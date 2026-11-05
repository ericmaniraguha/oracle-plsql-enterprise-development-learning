/*
Question:
Create a package named simple_package that stores a company name
inside a public variable called company_name.

Then write a PL/SQL block to display the value of company_name
from the package.
*/

CREATE OR REPLACE PACKAGE simple_package IS
    -- Public variable: any session can read AND change it.
    -- If the value must never change, declare it as a constant instead:
    --     company_name CONSTANT VARCHAR2(50) := 'ABC Ltd';
    company_name VARCHAR2(50) := 'ABC Ltd';
END simple_package;
/

SET SERVEROUTPUT ON;

BEGIN
    DBMS_OUTPUT.PUT_LINE(simple_package.company_name);
END;
/