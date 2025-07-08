#!/bin/bash

# Reset Guacamole Admin Password Script
# This script resets the guacadmin password back to default

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "=============================================="
log_info "Guacamole Admin Password Reset"
echo "=============================================="
echo

# Check if Guacamole container is running
if ! docker compose -f docker-compose-guacamole.yaml ps | grep -q "Up"; then
    log_error "Guacamole container is not running"
    echo "Please start Guacamole first:"
    echo "  docker compose -f docker-compose-guacamole.yaml up -d"
    exit 1
fi

log_info "Guacamole container is running"

# Execute SQL commands to reset password
log_info "Resetting guacadmin password to default..."

# The default password hash for 'guacadmin'
# This matches what's in the init script
docker compose -f docker-compose-guacamole.yaml exec -T guacamole psql -U guacamole_user -d guacamole_db << 'EOF'
-- Reset guacadmin password to 'guacadmin'
UPDATE guacamole_user 
SET 
    password_hash = decode('CA458A7D494E3BE824F5E1E175A1556C0F8EEF2C2D7DF3633BEC4A29C4411960', 'hex'),
    password_salt = decode('FE24ADC5E11E2B25288D1704ABE67A79E342ECC26064CE69C5B3177795A82264', 'hex'),
    password_date = CURRENT_TIMESTAMP
WHERE username = 'guacadmin';

-- Ensure admin permissions
INSERT INTO guacamole_user_permission (user_id, permission)
SELECT user_id, 'ADMINISTER'
FROM guacamole_user
WHERE username = 'guacadmin'
ON CONFLICT DO NOTHING;

-- Verify the update
SELECT username, password_date FROM guacamole_user WHERE username = 'guacadmin';
EOF

if [ $? -eq 0 ]; then
    log_info "Password reset successful!"
    echo
    log_info "Default login credentials:"
    echo "  Username: guacadmin"
    echo "  Password: guacadmin"
    echo
    log_warn "Important: Change this password immediately after logging in"
    echo
    log_info "Access Guacamole at:"
    echo "  Local: http://localhost:8080/guacamole/"
    echo "  External: http://$(hostname -I | awk '{print $1}'):8080/guacamole/"
    echo
else
    log_error "Failed to reset password"
    echo
    log_info "Alternative method - Restart with fresh database:"
    echo "1. Stop services: docker compose -f docker-compose-guacamole.yaml down"
    echo "2. Remove volume: docker volume rm guac_config"
    echo "3. Start services: docker compose -f docker-compose-guacamole.yaml up -d"
    echo "4. Wait for initialization (2-3 minutes)"
fi

echo "==============================================" 