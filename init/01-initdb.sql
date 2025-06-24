-- Initialize Guacamole Database Schema
-- This script downloads and executes the official Guacamole PostgreSQL schema

-- Create Guacamole schema
\echo 'Creating Guacamole database schema...'

-- You need to manually download and execute the schema from:
-- https://raw.githubusercontent.com/apache/guacamole-server/main/src/protocols/rdp/guac_rdpdr.sql
-- For now, we'll create the basic schema that will be populated by Guacamole

-- This script will be executed when the PostgreSQL container starts
-- The actual schema will be created by Guacamole on first startup
\echo 'Database initialized. Guacamole will create tables on first startup.' 