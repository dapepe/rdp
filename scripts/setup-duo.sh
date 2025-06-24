#!/bin/bash

# DUO Security 2FA Setup Script for Apache Guacamole
# This script downloads and configures the DUO extension

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
DUO_EXTENSION_URL="https://archive.apache.org/dist/guacamole/${GUACAMOLE_VERSION}/binary/guacamole-auth-duo-${GUACAMOLE_VERSION}.jar"
EXTENSIONS_DIR="./extensions"
LIB_DIR="./lib"

# Create directories
create_directories() {
    log_header "Creating DUO Extension Directories"
    
    mkdir -p "$EXTENSIONS_DIR"
    mkdir -p "$LIB_DIR"
    mkdir -p "./branding"
    mkdir -p "./branding/css"
    
    log_info "Directories created successfully"
}

# Download DUO extension
download_duo_extension() {
    log_header "Downloading DUO Security Extension"
    
    if [ -f "$EXTENSIONS_DIR/guacamole-auth-duo-${GUACAMOLE_VERSION}.jar" ]; then
        log_info "DUO extension already exists"
        return
    fi
    
    log_info "Downloading DUO extension from Apache archive..."
    curl -L -o "$EXTENSIONS_DIR/guacamole-auth-duo-${GUACAMOLE_VERSION}.jar" "$DUO_EXTENSION_URL"
    
    if [ $? -eq 0 ]; then
        log_info "DUO extension downloaded successfully"
    else
        log_error "Failed to download DUO extension"
        exit 1
    fi
}

# Setup DUO configuration
setup_duo_config() {
    log_header "Setting up DUO Configuration"
    
    # Check if DUO configuration already exists
    if [ -f "./extensions/duo-auth.properties" ]; then
        log_info "DUO configuration already exists"
    else
        log_warn "DUO configuration not found. Please ensure duo-auth.properties is created."
    fi
    
    # Check environment variables
    if [ -f ".env" ]; then
        source .env
        
        if [ -z "$DUO_INTEGRATION_KEY" ] || [ "$DUO_INTEGRATION_KEY" = "your_duo_integration_key_here" ]; then
            log_warn "DUO_INTEGRATION_KEY not configured in .env file"
        fi
        
        if [ -z "$DUO_SECRET_KEY" ] || [ "$DUO_SECRET_KEY" = "your_duo_secret_key_here" ]; then
            log_warn "DUO_SECRET_KEY not configured in .env file"
        fi
        
        if [ -z "$DUO_API_HOSTNAME" ] || [ "$DUO_API_HOSTNAME" = "your_duo_api_hostname_here" ]; then
            log_warn "DUO_API_HOSTNAME not configured in .env file"
        fi
        
        if [ -z "$DUO_APPLICATION_KEY" ] || [ "$DUO_APPLICATION_KEY" = "your_duo_application_key_here" ]; then
            log_warn "DUO_APPLICATION_KEY not configured in .env file"
        fi
    else
        log_warn ".env file not found. Please configure DUO environment variables."
    fi
}

# Test DUO configuration
test_duo_config() {
    log_header "Testing DUO Configuration"
    
    if [ -f ".env" ]; then
        source .env
        
        if [ -n "$DUO_API_HOSTNAME" ] && [ "$DUO_API_HOSTNAME" != "your_duo_api_hostname_here" ]; then
            log_info "Testing DUO API connectivity..."
            
            # Test DUO API endpoint accessibility
            if curl -s --connect-timeout 10 "https://$DUO_API_HOSTNAME/auth/v2/check" > /dev/null; then
                log_info "DUO API endpoint is accessible"
            else
                log_warn "DUO API endpoint may not be accessible or configured correctly"
            fi
        else
            log_warn "DUO_API_HOSTNAME not configured, skipping connectivity test"
        fi
    fi
}

# Setup permissions
setup_permissions() {
    log_header "Setting up Permissions"
    
    # Ensure correct permissions for extension files
    chmod 644 "$EXTENSIONS_DIR"/*.jar 2>/dev/null || true
    chmod 644 "$EXTENSIONS_DIR"/*.properties 2>/dev/null || true
    
    log_info "Permissions configured"
}

# Display setup information
display_setup_info() {
    log_header "DUO Setup Information"
    
    echo
    echo "=========================================="
    echo "DUO Security 2FA Extension Setup"
    echo "=========================================="
    echo
    echo "Extension installed: $EXTENSIONS_DIR/guacamole-auth-duo-${GUACAMOLE_VERSION}.jar"
    echo "Configuration file: $EXTENSIONS_DIR/duo-auth.properties"
    echo
    echo "To complete DUO setup:"
    echo "1. Sign up for DUO Security account at https://duo.com"
    echo "2. Create a new Web SDK application in DUO Admin Panel"
    echo "3. Copy the Integration Key, Secret Key, and API Hostname"
    echo "4. Generate an Application Key (40+ character random string)"
    echo "5. Update your .env file with DUO credentials:"
    echo "   - DUO_INTEGRATION_KEY=your_integration_key"
    echo "   - DUO_SECRET_KEY=your_secret_key"
    echo "   - DUO_API_HOSTNAME=api-xxxxxxxx.duosecurity.com"
    echo "   - DUO_APPLICATION_KEY=your_application_key"
    echo "6. Restart Guacamole containers"
    echo
    echo "DUO Configuration Options:"
    echo "- Edit extensions/duo-auth.properties for advanced settings"
    echo "- Configure user groups, IP whitelists, and enrollment options"
    echo "- Customize DUO messages and timeout settings"
    echo
    echo "Troubleshooting:"
    echo "- Check Guacamole logs: docker compose logs guacamole"
    echo "- Verify DUO API connectivity"
    echo "- Ensure users are enrolled in DUO"
    echo "=========================================="
}

# Generate DUO application key
generate_application_key() {
    log_header "Generating DUO Application Key"
    
    # Generate a secure 40-character application key
    APP_KEY=$(openssl rand -hex 20)
    
    echo
    echo "Generated DUO Application Key: $APP_KEY"
    echo
    echo "Add this to your .env file:"
    echo "DUO_APPLICATION_KEY=$APP_KEY"
    echo
    
    # Optionally update .env file
    if [ -f ".env" ]; then
        read -p "Would you like to automatically update your .env file? (y/n): " update_env
        
        if [ "$update_env" = "y" ] || [ "$update_env" = "Y" ]; then
            if grep -q "DUO_APPLICATION_KEY=" .env; then
                sed -i.bak "s/DUO_APPLICATION_KEY=.*/DUO_APPLICATION_KEY=$APP_KEY/" .env
                log_info "Updated DUO_APPLICATION_KEY in .env file"
            else
                echo "DUO_APPLICATION_KEY=$APP_KEY" >> .env
                log_info "Added DUO_APPLICATION_KEY to .env file"
            fi
        fi
    fi
}

# Main execution
main() {
    echo "=========================================="
    log_header "DUO Security 2FA Extension Setup"
    echo "=========================================="
    echo
    
    create_directories
    download_duo_extension
    setup_duo_config
    setup_permissions
    generate_application_key
    test_duo_config
    display_setup_info
}

# Run main function
main "$@" 