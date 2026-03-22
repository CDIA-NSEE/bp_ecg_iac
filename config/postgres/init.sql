-- PostgreSQL initialisation script
-- Runs once when the data directory is first created.
-- Creates the Nessie metadata database alongside the Airflow database.

SELECT 'CREATE DATABASE nessie'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'nessie')
\gexec
