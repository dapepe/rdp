#!/bin/bash

# RDP Gateway Reload Script
# This script reloads RDP Gateway services after configuration changes

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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RDPGW_DATA_DIR="$PROJECT_DIR/data/rdpgw"
COMPOSE_FILE="$PROJECT_DIR/docker-compose-rdpgw.yaml"

# Check if we're in the right directory
check_environment() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "Docker Compose file not found: $COMPOSE_FILE"
        log_error "Please run this script from the project root directory"
        exit 1
    fi
    
    if [ ! -d "$RDPGW_DATA_DIR" ]; then
        log_warn "RDP Gateway data directory not found: $RDPGW_DATA_DIR"
        log_info "This will be created when services start"
    fi
}

# Validate configuration files
validate_config() {
    log_header "Validating Configuration Files"
    
    local config_dir="$PROJECT_DIR/rdpgw"
    local errors=0
    
    # Check hosts.yaml
    if [ -f "$config_dir/hosts.yaml" ]; then
        log_info "✓ hosts.yaml found"
        
        # Basic YAML syntax check (if yq is available)
        if command -v yq >/dev/null 2>&1; then
            if yq eval '.hosts | length' "$config_dir/hosts.yaml" >/dev/null 2>&1; then
                local host_count=$(yq eval '.hosts | length' "$config_dir/hosts.yaml")
                log_info "  - Found $host_count host(s) configured"
            else
                log_error "  - Invalid YAML syntax in hosts.yaml"
                ((errors++))
            fi
        fi
    else
        log_error "✗ hosts.yaml not found in $config_dir"
        ((errors++))
    fi
    
    # Check users.yaml
    if [ -f "$config_dir/users.yaml" ]; then
        log_info "✓ users.yaml found"
        
        # Basic YAML syntax check (if yq is available)
        if command -v yq >/dev/null 2>&1; then
            if yq eval '.users | length' "$config_dir/users.yaml" >/dev/null 2>&1; then
                local user_count=$(yq eval '.users | length' "$config_dir/users.yaml")
                log_info "  - Found $user_count user(s) configured"
            else
                log_error "  - Invalid YAML syntax in users.yaml"
                ((errors++))
            fi
        fi
    else
        log_error "✗ users.yaml not found in $config_dir"
        ((errors++))
    fi
    
    # Check SSL certificates
    if [ -f "$config_dir/ssl/server.crt" ] && [ -f "$config_dir/ssl/server.key" ]; then
        log_info "✓ SSL certificates found"
        
        # Check certificate expiry
        local expiry_date=$(openssl x509 -in "$config_dir/ssl/server.crt" -noout -enddate 2>/dev/null | cut -d= -f2)
        if [ -n "$expiry_date" ]; then
            log_info "  - Certificate expires: $expiry_date"
        fi
    else
        log_warn "⚠ SSL certificates not found - will be generated"
    fi
    
    if [ $errors -gt 0 ]; then
        log_error "Configuration validation failed with $errors error(s)"
        log_error "Please fix the configuration issues before reloading"
        exit 1
    fi
    
    log_info "Configuration validation passed"
}

# Sync configuration to volume
sync_config() {
    log_header "Syncing Configuration to Volume"
    
    # Ensure the data directory structure exists
    mkdir -p "$RDPGW_DATA_DIR"/{conf,certs,logs,backups}
    
    # Copy configuration files
    local config_dir="$PROJECT_DIR/rdpgw"
    if [ -d "$config_dir" ]; then
        log_info "Copying configuration files..."
        
        # Copy main config files
        if [ -f "$config_dir/hosts.yaml" ]; then
            cp "$config_dir/hosts.yaml" "$RDPGW_DATA_DIR/conf/"
            log_info "  - hosts.yaml copied"
        fi
        
        if [ -f "$config_dir/users.yaml" ]; then
            cp "$config_dir/users.yaml" "$RDPGW_DATA_DIR/conf/"
            log_info "  - users.yaml copied"
        fi
        
        # Copy SSL certificates
        if [ -d "$config_dir/ssl" ]; then
            cp -r "$config_dir/ssl/"* "$RDPGW_DATA_DIR/certs/" 2>/dev/null || true
            log_info "  - SSL certificates copied"
        fi
        
        # Copy nginx configuration
        if [ -d "$config_dir/nginx" ]; then
            mkdir -p "$RDPGW_DATA_DIR/conf/nginx"
            cp -r "$config_dir/nginx/"* "$RDPGW_DATA_DIR/conf/nginx/" 2>/dev/null || true
            log_info "  - Nginx configuration copied"
        fi
        
        # Set proper permissions
        find "$RDPGW_DATA_DIR" -name "*.key" -exec chmod 600 {} \;
        find "$RDPGW_DATA_DIR" -name "*.crt" -exec chmod 644 {} \;
        find "$RDPGW_DATA_DIR" -name "*.yaml" -exec chmod 644 {} \;
        find "$RDPGW_DATA_DIR" -name "*.yml" -exec chmod 644 {} \;
        
        log_info "Configuration sync completed"
    else
        log_error "Source configuration directory not found: $config_dir"
        exit 1
    fi
}

# Create backup before reload
create_backup() {
    log_header "Creating Configuration Backup"
    
    local backup_dir="$RDPGW_DATA_DIR/backups"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$backup_dir/rdpgw_config_$timestamp.tar.gz"
    
    mkdir -p "$backup_dir"
    
    # Create backup of current configuration
    if [ -d "$RDPGW_DATA_DIR/conf" ]; then
        tar -czf "$backup_file" -C "$RDPGW_DATA_DIR" conf/ certs/ 2>/dev/null || true
        if [ -f "$backup_file" ]; then
            log_info "Configuration backup created: $(basename "$backup_file")"
            
            # Keep only last 10 backups
            ls -t "$backup_dir"/rdpgw_config_*.tar.gz 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
        else
            log_warn "Failed to create backup"
        fi
    else
        log_info "No existing configuration to backup"
    fi
}

# Check if services are running
check_services() {
    local running_services=$(docker compose -f "$COMPOSE_FILE" ps --services --filter "status=running" 2>/dev/null || true)
    
    if [ -n "$running_services" ]; then
        log_info "Running RDP Gateway services:"
        echo "$running_services" | while read -r service; do
            log_info "  - $service"
        done
        return 0
    else
        log_warn "No RDP Gateway services are currently running"
        return 1
    fi
}

# Graceful reload of RDP Gateway
reload_services() {
    log_header "Reloading RDP Gateway Services"
    
    if check_services; then
        log_info "Performing graceful reload..."
        
        # Send SIGHUP to rdpgw container to reload configuration
        local rdpgw_container=$(docker compose -f "$COMPOSE_FILE" ps -q rdpgw 2>/dev/null || true)
        
        if [ -n "$rdpgw_container" ]; then
            log_info "Sending reload signal to RDP Gateway..."
            docker exec "$rdpgw_container" kill -HUP 1 2>/dev/null || {
                log_warn "SIGHUP reload failed, performing restart instead"
                docker compose -f "$COMPOSE_FILE" restart rdpgw
            }
            
            # Wait a moment for reload to complete
            sleep 5
            
            # Check if service is still healthy
            if docker compose -f "$COMPOSE_FILE" ps rdpgw | grep -q "Up"; then
                log_info "RDP Gateway reloaded successfully"
            else
                log_error "RDP Gateway failed to reload properly"
                exit 1
            fi
        else
            log_error "RDP Gateway container not found"
            exit 1
        fi
        
        # Reload FreeRDP if it's running
        local freerdp_container=$(docker compose -f "$COMPOSE_FILE" ps -q freerdp-gateway 2>/dev/null || true)
        if [ -n "$freerdp_container" ]; then
            log_info "Restarting FreeRDP Gateway..."
            docker compose -f "$COMPOSE_FILE" restart freerdp-gateway
        fi
        
    else
        log_info "Starting RDP Gateway services..."
        docker compose -f "$COMPOSE_FILE" up -d
        
        # Wait for services to be ready
        log_info "Waiting for services to start..."
        sleep 10
        
        if check_services; then
            log_info "RDP Gateway services started successfully"
        else
            log_error "Failed to start RDP Gateway services"
            exit 1
        fi
    fi
}

# Test configuration after reload
test_config() {
    log_header "Testing Configuration"
    
    # Test RDP Gateway health endpoint
    local rdpgw_container=$(docker compose -f "$COMPOSE_FILE" ps -q rdpgw 2>/dev/null || true)
    
    if [ -n "$rdpgw_container" ]; then
        log_info "Testing RDP Gateway health endpoint..."
        
        # Try health check
        if docker exec "$rdpgw_container" curl -sf "http://localhost:${RDPGW_WEB_PORT:-443}/health" >/dev/null 2>&1; then
            log_info "✓ Health endpoint responding"
        else
            log_warn "⚠ Health endpoint not responding (may still be starting)"
        fi
        
        # Check if configuration files are accessible
        if docker exec "$rdpgw_container" test -f "/srv/rdpgw/conf/hosts.yaml"; then
            log_info "✓ Configuration files accessible"
        else
            log_error "✗ Configuration files not accessible"
            exit 1
        fi
        
        # Display service status
        log_info "Service status:"
        docker compose -f "$COMPOSE_FILE" ps
    else
        log_error "RDP Gateway container not found for testing"
        exit 1
    fi
}

# Display reload summary
display_summary() {
    log_header "Reload Summary"
    
    echo
    echo "=========================================="
    echo "RDP Gateway Reload Complete"
    echo "=========================================="
    echo
    echo "Configuration Location:"
    echo "  - Volume: /srv/rdpgw (inside containers)"
    echo "  - Host: $RDPGW_DATA_DIR"
    echo "  - Source: $PROJECT_DIR/rdpgw"
    echo
    echo "Services Status:"
    docker compose -f "$COMPOSE_FILE" ps 2>/dev/null || echo "  Unable to get service status"
    echo
    echo "Access Points:"
    echo "  - Web Interface: https://your-rdpgw-domain.com"
    echo "  - Native RDP: your-rdpgw-domain.com:3391"
    echo
    echo "Useful Commands:"
    echo "  - View logs: docker compose -f docker-compose-rdpgw.yaml logs -f"
    echo "  - Check status: docker compose -f docker-compose-rdpgw.yaml ps"
    echo "  - Reload again: ./scripts/rdpgw-reload.sh"
    echo "=========================================="
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Reload RDP Gateway services after configuration changes"
    echo
    echo "Options:"
    echo "  --validate-only    Only validate configuration, don't reload"
    echo "  --force           Skip confirmation prompts"
    echo "  --no-backup       Skip creating backup before reload"
    echo "  --help, -h        Show this help message"
    echo
    echo "Examples:"
    echo "  $0                      # Interactive reload with prompts"
    echo "  $0 --force              # Force reload without prompts"
    echo "  $0 --validate-only      # Only validate configuration"
}

# Main execution
main() {
    local validate_only=false
    local force=false
    local no_backup=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --validate-only)
                validate_only=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --no-backup)
                no_backup=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Header
    echo "=========================================="
    log_header "RDP Gateway Configuration Reload"
    echo "=========================================="
    echo
    
    # Check environment
    check_environment
    
    # Validate configuration
    validate_config
    
    if [ "$validate_only" = true ]; then
        log_info "Validation complete. Exiting without reload."
        exit 0
    fi
    
    # Confirmation prompt unless forced
    if [ "$force" != true ]; then
        echo
        read -p "Continue with RDP Gateway reload? (y/N): " confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            log_info "Reload cancelled by user"
            exit 0
        fi
    fi
    
    # Create backup unless skipped
    if [ "$no_backup" != true ]; then
        create_backup
    fi
    
    # Sync configuration
    sync_config
    
    # Reload services
    reload_services
    
    # Test configuration
    test_config
    
    # Display summary
    display_summary
}

# Change to project directory
cd "$PROJECT_DIR"

# Run main function with all arguments
main "$@" 