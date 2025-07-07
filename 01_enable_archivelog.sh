#!/bin/bash
# This script enables ARCHIVELOG mode as SYS

sqlplus / as sysdba <<-EOF
  -- Abort any sessions that might prevent a clean shutdown
  ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;
  SHUTDOWN IMMEDIATE;
  STARTUP MOUNT;
  ALTER DATABASE ARCHIVELOG;
  ALTER DATABASE OPEN;
  -- Ensure the PDB is also open and ready
  ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;
  EXIT;
EOF