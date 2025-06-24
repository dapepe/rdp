#!/bin/bash

# Guacamole Restore Script
# This script restores Guacamole configuration and data from backup

set -e

# Configuration
BACKUP_DIR="./backups"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    log_error "Backup directory not found: $BACKUP_DIR"
    exit 1
fi

# List available backups
log_info "Available backups:"
ls -la "$BACKUP_DIR"/*.tar.gz 2>/dev/null || {
    log_error "No backup files found in $BACKUP_DIR"
    exit 1
}

# Get backup file from user
echo
echo "Available backup files:"
ls -1 "$BACKUP_DIR"/*.tar.gz | nl
echo
read -p "Enter the number of the backup to restore: " backup_number

# Validate input
backup_files=($(ls -1 "$BACKUP_DIR"/*.tar.gz))
if ! [[ "$backup_number" =~ ^[0-9]+$ ]] || [ "$backup_number" -lt 1 ] || [ "$backup_number" -gt "${#backup_files[@]}" ]; then
    log_error "Invalid backup number"
    exit 1
fi

selected_backup="${backup_files[$((backup_number-1))]}"
log_info "Selected backup: $selected_backup"

# Confirm restoration
echo
log_warn "WARNING: This will overwrite current Guacamole configuration!"
read -p "Are you sure you want to proceed? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    log_info "Restoration cancelled"
    exit 0
fi

# Stop containers
log_info "Stopping containers..."
docker compose -f docker-compose-guacamole.yaml down
docker compose -f docker-compose-cloudflare.yaml down

# Restore Guacamole configuration
log_info "Restoring Guacamole configuration..."
docker run --rm \
    -v guac_config:/data \
    -v "$(pwd)/$BACKUP_DIR:/backup" \
    alpine sh -c "rm -rf /data/* && tar xzf /backup/$(basename "$selected_backup") -C /data"

# Restore Cloudflare configuration if backup exists
cloudflare_backup="${selected_backup/guacamole_backup/cloudflare_backup}"
if [ -f "$cloudflare_backup" ]; then
    log_info "Restoring Cloudflare configuration..."
    docker run --rm \
        -v cloudflare_config:/data \
        -v "$(pwd)/$BACKUP_DIR:/backup" \
        alpine sh -c "rm -rf /data/* && tar xzf /backup/$(basename "$cloudflare_backup") -C /data"
fi

# Start containers
log_info "Starting containers..."
docker compose -f docker-compose-guacamole.yaml up -d
docker compose -f docker-compose-cloudflare.yaml up -d

# Wait for containers to be ready
log_info "Waiting for containers to be ready..."
sleep 30

# Verify restoration
if docker compose -f docker-compose-guacamole.yaml ps | grep -q "Up"; then
    log_info "Restoration completed successfully!"
    log_info "Guacamole should be accessible at http://localhost:8080"
else
    log_error "Restoration failed - containers are not running"
    exit 1
fi 