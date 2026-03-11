-- Create additional databases for the stack
CREATE DATABASE mlflow_db;
CREATE DATABASE agents_db;

-- Initialize agents_db with useful extensions
\c agents_db
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
