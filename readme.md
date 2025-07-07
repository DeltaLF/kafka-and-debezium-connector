# Note

Demonstrate how to setup kafka connector and database to start cdc.

1. create data for dbzuser
2. grant permission for dbzuer (for dbz to work, view log premission is requried)
3. enable archivelog mode

# oracle prepare data

make data in FREEPDB1 database

```sql
-- ========= CREATE TABLES =========
-- Creates the main tables for customers, products, and their orders.

CREATE TABLE customers (
id NUMBER(10) NOT NULL PRIMARY KEY,
first_name VARCHAR2(255) NOT NULL,
last_name VARCHAR2(255) NOT NULL,
email VARCHAR2(255) NOT NULL UNIQUE
);

CREATE TABLE products (
id NUMBER(10) NOT NULL PRIMARY KEY,
name VARCHAR2(255) NOT NULL,
description VARCHAR2(1000),
price NUMBER(10, 2) NOT NULL
);

CREATE TABLE orders (
id NUMBER(10) NOT NULL PRIMARY KEY,
order_date DATE NOT NULL,
customer_id NUMBER(10) NOT NULL,
CONSTRAINT fk_orders_customers FOREIGN KEY (customer_id) REFERENCES customers(id)
);

-- ========= ENABLE SUPPLEMENTAL LOGGING (CRUCIAL FOR DEBEZIUM) =========
-- This tells Oracle to write the necessary information to the transaction logs
-- for Debezium's LogMiner to capture the changes.

ALTER TABLE customers ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER TABLE products ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER TABLE orders ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- ========= INSERT SAMPLE DATA =========
-- Inserts some rows so you have initial data to work with.

-- Create customers
INSERT INTO customers VALUES (101, 'John', 'Doe', 'johndoe@example.com');
INSERT INTO customers VALUES (102, 'Jane', 'Smith', 'janesmith@example.com');

-- Create products
INSERT INTO products VALUES (201, 'Laptop', 'A powerful work laptop', 1200.50);
INSERT INTO products VALUES (202, 'Mouse', 'An ergonomic wireless mouse', 45.99);
INSERT INTO products VALUES (203, 'Keyboard', 'A mechanical keyboard with RGB', 110.00);

-- Create an order for John Doe
INSERT INTO orders VALUES (1001, SYSDATE, 101);

COMMIT;
```

grant permission for dbzuser
(log in sys with role sysdba)

```sql
-- Grant general session and view creation permissions
GRANT CREATE SESSION TO dbzuser;
GRANT CREATE TABLE TO dbzuser;
GRANT CREATE SEQUENCE to dbzuser;
GRANT CREATE VIEW to dbzuser;
ALTER USER dbzuser QUOTA UNLIMITED ON users;

-- Grant required SELECT privileges on system views
GRANT SELECT ON V_$DATABASE to dbzuser;
GRANT SELECT ON V_$ARCHIVED_LOG to dbzuser;
GRANT SELECT ON V_$LOGMNR_CONTENTS to dbzuser;
GRANT SELECT ON V_$LOG to dbzuser;
GRANT SELECT ON V_$LOGFILE to dbzuser;
GRANT SELECT ON V_$INSTANCE to dbzuser;

-- Grant LogMiner-specific role
GRANT SELECT_CATALOG_ROLE TO dbzuser;
GRANT EXECUTE_CATALOG_ROLE TO dbzuser;
GRANT LOGMINING TO dbzuser;

-- Grant access to specific tables for reading redo logs
GRANT SELECT on v_$transportable_platform to dbzuser;

-- Grant access to the specific tables you want to capture
-- (This is optional if you want the user to own the tables, but good practice otherwise)
GRANT SELECT ON  DBZUSER.customers to dbzuser;
```

enable archive log mode

```shell
docker exec -it <your_oracle_container_name> bash
sqlplus / as sysdba
SQL> SHUTDOWN IMMEDIATE;
SQL> STARTUP MOUNT;
SQL> ALTER DATABASE ARCHIVELOG;
SQL> ALTER DATABASE OPEN;
SQL> exit;
```

For dbz to work, it requires a cdb user
login with SYS to CDB:
input FREE in the SID

```sql
-- First, drop the old local user from within the PDB
ALTER SESSION SET CONTAINER = FREEPDB1;
DROP USER dbzuser CASCADE;

-- Switch back to the root to create the new common user
ALTER SESSION SET CONTAINER = CDB$ROOT;

-- Create the common user (name must start with C##)
CREATE USER C##dbzuser IDENTIFIED BY dbz;

-- Grant permissions, applying them to all containers
GRANT CREATE SESSION, SET CONTAINER, LOGMINING TO C##dbzuser CONTAINER=ALL;
GRANT SELECT ON V_$DATABASE TO C##dbzuser CONTAINER=ALL;
GRANT SELECT ON V_$ARCHIVED_LOG TO C##dbzuser CONTAINER=ALL;
GRANT SELECT ON V_$LOGMNR_CONTENTS TO C##dbzuser CONTAINER=ALL;
GRANT SELECT ON V_$LOG TO C##dbzuser CONTAINER=ALL;
GRANT SELECT ON V_$LOGFILE TO C##dbzuser CONTAINER=ALL;
GRANT SELECT ON V_$INSTANCE TO C##dbzuser CONTAINER=ALL;
GRANT SELECT on V_$TRANSPORTABLE_PLATFORM to C##dbzuser CONTAINER=ALL;
GRANT SELECT_CATALOG_ROLE TO C##dbzuser CONTAINER=ALL;
GRANT EXECUTE_CATALOG_ROLE TO C##dbzuser CONTAINER=ALL;

-- Switch back into the PDB to grant table access and quota
ALTER SESSION SET CONTAINER = FREEPDB1;
GRANT CREATE TABLE, CREATE VIEW, CREATE SEQUENCE TO C##dbzuser;
ALTER USER C##dbzuser QUOTA UNLIMITED ON users;
```

with C##DBZUSER created
now login C##DBZUSER to FREEPDB1

```sql
-- Drop tables first to ensure the script can be run multiple times
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

CREATE TABLE products (
  id NUMBER(10) NOT NULL PRIMARY KEY,
  name VARCHAR2(255) NOT NULL,
  description VARCHAR2(1000),
  price NUMBER(10, 2) NOT NULL
);

CREATE TABLE orders (
  id NUMBER(10) NOT NULL PRIMARY KEY,
  order_date DATE NOT NULL,
  customer_id NUMBER(10) NOT NULL,
  CONSTRAINT fk_orders_customers FOREIGN KEY (customer_id) REFERENCES customers(id)
);

-- ========= ENABLE SUPPLEMENTAL LOGGING (CRUCIAL FOR DEBEZIUM) =========
ALTER TABLE customers ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER TABLE products ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER TABLE orders ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- ========= INSERT SAMPLE DATA =========
INSERT INTO customers VALUES (101, 'John', 'Doe', 'johndoe@example.com');
INSERT INTO customers VALUES (102, 'Jane', 'Smith', 'janesmith@example.com');
INSERT INTO products VALUES (201, 'Laptop', 'A powerful work laptop', 1200.50);
INSERT INTO products VALUES (202, 'Mouse', 'An ergonomic wireless mouse', 45.99);
INSERT INTO products VALUES (203, 'Keyboard', 'A mechanical keyboard with RGB', 110.00);
INSERT INTO orders VALUES (1001, SYSDATE, 101);

COMMIT;
```

# connector

```js
curl localhost:8083/connectors
curl -i localhost:8083/connectors/{connectorName}/status
curl -i -X DELETE localhost:8083/connectors/oracle-customers-connector

{
"name": "oracle-customers-connector",
"config": {
"connector.class": "io.debezium.connector.oracle.OracleConnector",
// "database.server.name": "oracleserver1",
"topic.prefix":"oracleserver1",
"database.hostname": "oracle",
"database.port": "1521",
"database.user": "dbzuser",
"database.password": "dbz",
"database.dbname": "FREEPDB1",
"database.pdb.name": "FREEPDB1",
"table.include.list": "DBZUSER.CUSTOMERS",
// "database.history.kafka.bootstrap.servers": "kafka:9092",
// "database.history.kafka.topic": "dbhistory.oracleserver1",
"schema.history.internal.kafka.bootstrap.servers": "kafka:9093",
"schema.history.internal.kafka.topic": "dbhistory.oracleserver1",
"log.mining.strategy": "online_catalog",
"snapshot.mode": "initial"
}
}
```

# kafka

```sh
docker exec -it dbz_oracle-kafka-1 /kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
```
