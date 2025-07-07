-- Connect to the PDB as the newly created application user.
CONNECT C##dbzuser/dbz@FREEPDB1

-- Drop tables first to ensure the script can be run multiple times safely.
BEGIN EXECUTE IMMEDIATE 'DROP TABLE orders'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE products'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE customers'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF; END;
/

-- ========= CREATE TABLES =========
CREATE TABLE customers (
  id NUMBER(10) NOT NULL PRIMARY KEY,
  first_name VARCHAR2(255) NOT NULL,
  last_name VARCHAR2(255) NOT NULL,
  email VARCHAR2(255) NOT NULL UNIQUE
);
/

-- ========= ENABLE TABLE-LEVEL SUPPLEMENTAL LOGGING =========
ALTER TABLE customers ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
/

-- ========= INSERT SAMPLE DATA =========
INSERT INTO customers (id, first_name, last_name, email) VALUES (101, 'Sally', 'Thomas', 'sally.thomas@acme.com');
/
INSERT INTO customers (id, first_name, last_name, email) VALUES (102, 'George', 'Bailey', 'gbailey@foobar.com');
/

COMMIT;
/