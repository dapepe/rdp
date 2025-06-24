#!/bin/bash

# Guacamole Backup Script
# This script backs up Guacamole configuration and data

set -e

# Configuration
BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="guacamole_backup_${DATE}.tar.gz"

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

# Create backup directory if it doesn't exist
if [ ! -d "$BACKUP_DIR" ]; then
    log_info "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
fi

# Check if containers are running
if ! docker compose -f docker-compose-guacamole.yaml ps | grep -q "Up"; then
    log_warn "Guacamole containers are not running. Starting them for backup..."
    docker compose -f docker-compose-guacamole.yaml up -d
    sleep 30  # Wait for containers to be ready
fi

# Create backup
log_info "Creating backup: $BACKUP_NAME"

# Backup Guacamole configuration volume
docker run --rm \
    -v guac_config:/data \
    -v "$(pwd)/$BACKUP_DIR:/backup" \
    alpine tar czf "/backup/$BACKUP_NAME" -C /data .

# Backup Cloudflare configuration if exists
if docker volume ls | grep -q "cloudflare_config"; then
    log_info "Backing up Cloudflare configuration..."
    docker run --rm \
        -v cloudflare_config:/data \
        -v "$(pwd)/$BACKUP_DIR:/backup" \
        alpine tar czf "/backup/cloudflare_backup_${DATE}.tar.gz" -C /data .
fi

# Create backup manifest
cat > "$BACKUP_DIR/backup_manifest_${DATE}.txt" << EOF
Backup created: $(date)
Guacamole version: $(docker compose -f docker-compose-guacamole.yaml exec guacamole cat /opt/guacamole/version 2>/dev/null || echo "Unknown")
Cloudflare version: $(docker compose -f docker-compose-cloudflare.yaml exec cloudflare cloudflared version 2>/dev/null || echo "Unknown")
Backup files:
- $BACKUP_NAME
- cloudflare_backup_${DATE}.tar.gz (if exists)
EOF

# Cleanup old backups (keep last 7 days)
log_info "Cleaning up old backups (keeping last 7 days)..."
find "$BACKUP_DIR" -name "guacamole_backup_*.tar.gz" -mtime +7 -delete
find "$BACKUP_DIR" -name "cloudflare_backup_*.tar.gz" -mtime +7 -delete
find "$BACKUP_DIR" -name "backup_manifest_*.txt" -mtime +7 -delete

log_info "Backup completed successfully!"
log_info "Backup location: $BACKUP_DIR/$BACKUP_NAME" 