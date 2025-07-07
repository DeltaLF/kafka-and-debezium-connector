#!/bin/bash
# This script enables ARCHIVELOG mode and supplemental logging as SYS

sqlplus / as sysdba <<-EOF
  SHUTDOWN IMMEDIATE;
  STARTUP MOUNT;
  ALTER DATABASE ARCHIVELOG;
  ALTER DATABASE OPEN;
  -- Ensure the PDB is also open and ready
  ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;
  -- Use the general supplemental logging command that is proven to work
  ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
  -- somehow ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (PRIMARY KEY) COLUMNS; not working
  EXIT;
EOF