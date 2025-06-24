-- Guacamole PostgreSQL Schema
-- This is a minimal schema that will be extended by Guacamole

-- Create user table
CREATE TABLE IF NOT EXISTS guacamole_user (
    user_id           SERIAL       NOT NULL,
    username          VARCHAR(128) NOT NULL,
    password_hash     BYTEA        NOT NULL,
    password_salt     BYTEA,
    password_date     TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    disabled          BOOLEAN      NOT NULL DEFAULT FALSE,
    expired           BOOLEAN      NOT NULL DEFAULT FALSE,
    access_window_start    TIME,
    access_window_end      TIME,
    valid_from        DATE,
    valid_until       DATE,
    timezone          VARCHAR(64),
    full_name         VARCHAR(256),
    email_address     VARCHAR(256),
    organization      VARCHAR(256),
    organizational_role VARCHAR(256),
    
    PRIMARY KEY (user_id),
    UNIQUE (username)
);

-- Create connection table
CREATE TABLE IF NOT EXISTS guacamole_connection (
    connection_id   SERIAL       NOT NULL,
    connection_name VARCHAR(128) NOT NULL,
    parent_id       INTEGER,
    protocol        VARCHAR(32)  NOT NULL,
    
    PRIMARY KEY (connection_id),
    UNIQUE (connection_name, parent_id),
    
    FOREIGN KEY (parent_id)
        REFERENCES guacamole_connection (connection_id)
        ON DELETE CASCADE
);

-- Create parameter table
CREATE TABLE IF NOT EXISTS guacamole_connection_parameter (
    connection_id   INTEGER       NOT NULL,
    parameter_name  VARCHAR(128)  NOT NULL,
    parameter_value VARCHAR(4096) NOT NULL,
    
    PRIMARY KEY (connection_id, parameter_name),
    
    FOREIGN KEY (connection_id)
        REFERENCES guacamole_connection (connection_id)
        ON DELETE CASCADE
);

-- Create permission tables
CREATE TABLE IF NOT EXISTS guacamole_user_permission (
    user_id    INTEGER NOT NULL,
    permission VARCHAR(32) NOT NULL,
    
    PRIMARY KEY (user_id, permission),
    
    FOREIGN KEY (user_id)
        REFERENCES guacamole_user (user_id)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS guacamole_connection_permission (
    user_id       INTEGER NOT NULL,
    connection_id INTEGER NOT NULL,
    permission    VARCHAR(32) NOT NULL,
    
    PRIMARY KEY (user_id, connection_id, permission),
    
    FOREIGN KEY (user_id)
        REFERENCES guacamole_user (user_id)
        ON DELETE CASCADE,
        
    FOREIGN KEY (connection_id)
        REFERENCES guacamole_connection (connection_id)
        ON DELETE CASCADE
);

-- Additional tables will be created by Guacamole on startup
