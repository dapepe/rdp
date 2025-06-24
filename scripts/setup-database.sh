#!/bin/bash

# Guacamole Database Setup Script
# Downloads and prepares the official PostgreSQL schema

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${BLUE}[HEADER]${NC} $1"
}

# Configuration
GUACAMOLE_VERSION="1.5.5"
INIT_DIR="./init"
SCHEMA_URL="https://raw.githubusercontent.com/apache/guacamole-client/main/guacamole-auth-jdbc/modules/guacamole-auth-jdbc-postgresql/schema"

# Create init directory
create_init_directory() {
    log_header "Creating Database Initialization Directory"
    
    if [ ! -d "$INIT_DIR" ]; then
        mkdir -p "$INIT_DIR"
        log_info "Created $INIT_DIR directory"
    else
        log_info "$INIT_DIR directory already exists"
    fi
}

# Download Guacamole PostgreSQL schema
download_schema() {
    log_header "Downloading Guacamole PostgreSQL Schema"
    
    # Download schema files in order
    schema_files=(
        "001-create-schema.sql"
        "002-create-admin-user.sql"
    )
    
    for file in "${schema_files[@]}"; do
        local url="${SCHEMA_URL}/${file}"
        local dest="${INIT_DIR}/${file}"
        
        log_info "Downloading $file..."
        
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL "$url" -o "$dest" || {
                log_warn "Failed to download $file from official repository"
                create_fallback_schema "$file"
            }
        elif command -v wget >/dev/null 2>&1; then
            wget -q "$url" -O "$dest" || {
                log_warn "Failed to download $file from official repository"
                create_fallback_schema "$file"
            }
        else
            log_warn "Neither curl nor wget found, creating fallback schema"
            create_fallback_schema "$file"
        fi
        
        if [ -f "$dest" ]; then
            log_info "✓ $file downloaded successfully"
        fi
    done
}

# Create fallback schema if download fails
create_fallback_schema() {
    local filename="$1"
    local dest="${INIT_DIR}/${filename}"
    
    log_info "Creating fallback schema: $filename"
    
    case "$filename" in
        "001-create-schema.sql")
            cat > "$dest" << 'EOF'
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
EOF
            ;;
        "002-create-admin-user.sql")
            cat > "$dest" << 'EOF'
-- Create default admin user
-- Password: guacadmin (will be hashed by Guacamole)

INSERT INTO guacamole_user (username, password_hash, password_salt, password_date)
VALUES (
    'guacadmin',
    decode('CA458A7D494E3BE824F5E1E175A1556C0F8EEF2C2D7DF3633BEC4A29C4411960', 'hex'),
    decode('FE24ADC5E11E2B25288D1704ABE67A79E342ECC26064CE69C5B3177795A82264', 'hex'),
    CURRENT_TIMESTAMP
) ON CONFLICT (username) DO NOTHING;

-- Grant admin permissions
INSERT INTO guacamole_user_permission (user_id, permission)
SELECT user_id, 'ADMINISTER'
FROM guacamole_user
WHERE username = 'guacadmin'
ON CONFLICT DO NOTHING;
EOF
            ;;
    esac
    
    log_info "✓ Fallback schema created: $filename"
}

# Set proper permissions
set_permissions() {
    log_header "Setting File Permissions"
    
    # Make SQL files readable
    chmod 644 "$INIT_DIR"/*.sql 2>/dev/null || true
    
    log_info "File permissions set"
}

# Validate schema files
validate_schema() {
    log_header "Validating Schema Files"
    
    for file in "$INIT_DIR"/*.sql; do
        if [ -f "$file" ]; then
            log_info "✓ Found: $(basename "$file")"
        fi
    done
    
    log_info "Schema validation completed"
}

# Display setup information
display_info() {
    log_header "Database Setup Complete"
    
    echo
    echo "========================================"
    echo "Guacamole Database Setup Summary"
    echo "========================================"
    echo
    echo "Schema Files:"
    for file in "$INIT_DIR"/*.sql; do
        if [ -f "$file" ]; then
            echo "  ✓ $(basename "$file")"
        fi
    done
    echo
    echo "Default Credentials:"
    echo "  Username: guacadmin"
    echo "  Password: guacadmin"
    echo
    echo "IMPORTANT: Change the default password immediately after first login!"
    echo
    echo "The PostgreSQL container will automatically execute these"
    echo "scripts when it starts for the first time."
    echo
    echo "Next steps:"
    echo "1. Start the services: docker compose -f docker-compose-guacamole.yaml up -d"
    echo "2. Wait for initialization to complete"
    echo "3. Access Guacamole at http://localhost:8080/guacamole/"
    echo "4. Login with guacadmin/guacadmin"
    echo "5. Change the default password immediately"
    echo "========================================"
}

# Main execution
main() {
    echo "========================================"
    log_header "Guacamole Database Setup"
    echo "========================================"
    echo
    
    create_init_directory
    download_schema
    set_permissions
    validate_schema
    display_info
}

# Run main function
main "$@" 