#!/bin/bash

# RDP Gateway Setup Script
# This script configures RDP Gateway with Cloudflare tunnel integration

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
RDPGW_DIR="./rdpgw"

# Create RDP Gateway directories
create_rdpgw_directories() {
    log_header "Creating RDP Gateway Directories"
    
    mkdir -p "$RDPGW_DIR"
    mkdir -p "$RDPGW_DIR/nginx"
    mkdir -p "$RDPGW_DIR/ssl"
    mkdir -p "$RDPGW_DIR/cloudflare"
    mkdir -p "$RDPGW_DIR/certs"
    
    log_info "RDP Gateway directories created successfully"
}

# Process Nginx configuration template
process_nginx_template() {
    log_header "Processing Nginx Configuration Template"
    
    if [ -f "$RDPGW_DIR/nginx/rdpgw.conf.template" ]; then
        log_info "Processing nginx configuration template..."
        
        # Load environment variables from .env file
        if [ -f ".env" ]; then
            set -a
            source .env
            set +a
        fi
        
        # Set default values if not set
        export RDPGW_PORT=${RDPGW_PORT:-3391}
        export RDPGW_WEB_PORT=${RDPGW_WEB_PORT:-443}
        export RDPGW_DOMAIN=${RDPGW_DOMAIN:-rdpgw.yourorganization.com}
        
        # Process template and create nginx configuration
        envsubst '${RDPGW_PORT},${RDPGW_WEB_PORT},${RDPGW_DOMAIN}' \
            < "$RDPGW_DIR/nginx/rdpgw.conf.template" \
            > "$RDPGW_DIR/nginx/default.conf"
        
        log_info "Nginx configuration generated from template"
    else
        log_warn "Nginx template not found, using static configuration"
    fi
}

# Generate SSL certificates
generate_ssl_certificates() {
    log_header "Generating SSL Certificates"
    
    if [ ! -f "$RDPGW_DIR/ssl/server.crt" ]; then
        log_info "Generating self-signed SSL certificate..."
        
        # Generate private key
        openssl genrsa -out "$RDPGW_DIR/ssl/server.key" 2048
        
        # Generate certificate signing request
        openssl req -new -key "$RDPGW_DIR/ssl/server.key" -out "$RDPGW_DIR/ssl/server.csr" -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=rdpgw.yourorganization.com"
        
        # Generate self-signed certificate
        openssl x509 -req -days 365 -in "$RDPGW_DIR/ssl/server.csr" -signkey "$RDPGW_DIR/ssl/server.key" -out "$RDPGW_DIR/ssl/server.crt"
        
        # Copy certificates to certs directory
        cp "$RDPGW_DIR/ssl/server.crt" "$RDPGW_DIR/certs/"
        cp "$RDPGW_DIR/ssl/server.key" "$RDPGW_DIR/certs/"
        
        # Set proper permissions
        chmod 600 "$RDPGW_DIR/ssl/server.key" "$RDPGW_DIR/certs/server.key"
        chmod 644 "$RDPGW_DIR/ssl/server.crt" "$RDPGW_DIR/certs/server.crt"
        
        log_info "SSL certificates generated successfully"
        log_warn "Using self-signed certificates. Consider using Let's Encrypt or proper CA certificates for production."
    else
        log_info "SSL certificates already exist"
    fi
}

# Setup user authentication
setup_user_authentication() {
    log_header "Setting up User Authentication"
    
    if [ ! -f "$RDPGW_DIR/users.yaml" ]; then
        log_info "Users configuration already exists"
    else
        log_info "Users configuration template is available"
    fi
    
    # Generate password hashes for default users
    echo
    echo "Default user accounts will be created with the following credentials:"
    echo "Username: admin"
    echo "Password: Please set a secure password"
    echo
    
    read -s -p "Enter password for admin user: " admin_password
    echo
    
    if command -v htpasswd &> /dev/null; then
        admin_hash=$(htpasswd -bnBC 10 "" "$admin_password" | tr -d ':\n' | sed 's/^[^$]*\$//')
        
        # Update users.yaml with the generated hash
        if [ -f "$RDPGW_DIR/users.yaml" ]; then
            sed -i.bak "s/\$2a\$10\$example_hash_replace_with_actual_hash/$admin_hash/" "$RDPGW_DIR/users.yaml"
            log_info "Admin password hash updated in users.yaml"
        fi
    else
        log_warn "htpasswd not found. Please manually update password hashes in users.yaml"
        log_info "You can generate bcrypt hashes using: htpasswd -bnBC 10 '' 'password'"
    fi
}

# Configure environment variables
configure_environment() {
    log_header "Configuring Environment Variables"
    
    # RDP Gateway specific environment variables
    if [ -f ".env" ]; then
        # Add RDP Gateway configuration to .env if not present
        if ! grep -q "RDPGW_" .env; then
            cat >> .env << EOF

# RDP Gateway Configuration (uses unified Cloudflare tunnel)
RDPGW_AUTH_BACKEND=local
RDPGW_LOG_LEVEL=info
RDPGW_IDLE_TIMEOUT=1800
RDPGW_SESSION_TIMEOUT=28800

EOF
            log_info "RDP Gateway configuration added to .env file"
        else
            log_info "RDP Gateway configuration already exists in .env file"
        fi
    else
        log_warn ".env file not found. Please create it first using the main setup script."
    fi
}

# Setup Cloudflare tunnel for RDP Gateway
setup_cloudflare_tunnel() {
    log_header "Cloudflare Tunnel Configuration for RDP Gateway"
    
    echo
    echo "RDP Gateway will use the existing unified Cloudflare tunnel."
    echo
    echo "To configure in your Cloudflare dashboard:"
    echo "1. Add a route to your existing tunnel:"
    echo "   - Subdomain: rdpgw"
    echo "   - Domain: your domain"
    echo "   - Service: rdp://172.18.0.5:3391"
    echo
    echo "2. Your RDP Gateway will be accessible at:"
    echo "   - Native RDP clients: rdpgw.yourdomain.com:3391"
    echo "   - Web interface: https://rdpgw.yourdomain.com"
    echo
    
    log_info "RDP Gateway will use the unified tunnel configuration"
}

# Configure hosts and permissions
configure_hosts() {
    log_header "Configuring Hosts and Permissions"
    
    if [ -f "$RDPGW_DIR/hosts.yaml" ]; then
        log_info "Hosts configuration template is available"
        echo
        echo "Please edit $RDPGW_DIR/hosts.yaml to configure:"
        echo "- Target servers and their IP addresses"
        echo "- Custom RDP ports (as recommended in the EdTech IRL article)"
        echo "- User permissions and access controls"
        echo "- Security settings and protocols"
        echo
        echo "Example configuration for secure RDP port (from EdTech IRL):"
        echo "- name: 'secure-server'"
        echo "  address: '192.168.1.200'"
        echo "  port: 13450  # Custom RDP port"
        echo
    else
        log_warn "Hosts configuration template not found"
    fi
}

# Test RDP Gateway configuration
test_rdpgw_config() {
    log_header "Testing RDP Gateway Configuration"
    
    # Check required files
    files_to_check=(
        "$RDPGW_DIR/hosts.yaml"
        "$RDPGW_DIR/users.yaml"
        "$RDPGW_DIR/ssl/server.crt"
        "$RDPGW_DIR/ssl/server.key"
        "$RDPGW_DIR/nginx/default.conf"
    )
    
    for file in "${files_to_check[@]}"; do
        if [ -f "$file" ]; then
            log_info "✓ $file exists"
        else
            log_warn "⚠ $file not found"
        fi
    done
    
    # Check SSL certificate validity
    if [ -f "$RDPGW_DIR/ssl/server.crt" ]; then
        expiry_date=$(openssl x509 -in "$RDPGW_DIR/ssl/server.crt" -noout -enddate | cut -d= -f2)
        log_info "SSL certificate expires: $expiry_date"
    fi
}

# Start RDP Gateway services
start_rdpgw_services() {
    log_header "Starting RDP Gateway Services"
    
    echo
    read -p "Would you like to start RDP Gateway services now? (y/n): " start_services
    
    if [ "$start_services" = "y" ] || [ "$start_services" = "Y" ]; then
        log_info "Starting RDP Gateway..."
        docker compose -f docker-compose-rdpgw.yaml up -d
        
        log_info "RDP Gateway will use the existing unified Cloudflare tunnel"
        
        sleep 10
        
        # Check if services are running
        if docker compose -f docker-compose-rdpgw.yaml ps | grep -q "Up"; then
            log_info "RDP Gateway services started successfully"
            log_info "Configure your Cloudflare tunnel to route rdpgw.yourdomain.com to rdp://172.18.0.5:3391"
        else
            log_error "Failed to start RDP Gateway services"
        fi
    else
        log_info "Services not started. You can start them later with:"
        echo "docker compose -f docker-compose-rdpgw.yaml up -d"
        log_info "Remember to add the RDP Gateway route to your existing Cloudflare tunnel"
    fi
}

# Display setup information
display_setup_info() {
    log_header "RDP Gateway Setup Complete"
    
    echo
    echo "=========================================="
    echo "RDP Gateway Configuration Summary"
    echo "=========================================="
    echo
    echo "Services:"
    echo "- RDP Gateway: Provides secure RDP access"
    echo "- Nginx Proxy: Handles HTTPS and protocol routing"
    echo "- Cloudflare Tunnel: Secure external access"
    echo
    echo "Configuration Files:"
    echo "- Hosts: $RDPGW_DIR/hosts.yaml"
    echo "- Users: $RDPGW_DIR/users.yaml"
    echo "- Nginx: $RDPGW_DIR/nginx/default.conf"
    echo "- SSL Certs: $RDPGW_DIR/ssl/"
    echo
    echo "Access Methods:"
    echo "1. Web Interface: https://rdpgw.yourorganization.com"
    echo "2. Native RDP Client: Configure gateway as rdpgw.yourorganization.com:3391"
    echo "3. Windows RDP: Use /g:rdpgw.yourorganization.com parameter"
    echo
    echo "Security Features:"
    echo "- DUO 2FA integration (if configured)"
    echo "- Role-based access control"
    echo "- Session logging and monitoring"
    echo "- Custom RDP ports (as recommended by EdTech IRL)"
    echo "- Cloudflare Zero Trust policies"
    echo
    echo "Next Steps:"
    echo "1. Configure your target servers with custom RDP ports"
    echo "2. Update hosts.yaml with your server details"
    echo "3. Create user accounts in users.yaml"
    echo "4. Configure Cloudflare Zero Trust policies"
    echo "5. Test connections from native RDP clients"
    echo
    echo "PowerShell script to change RDP port (from EdTech IRL):"
    echo "\$portvalue = 13450"
    echo "Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server\\WinStations\\RDP-Tcp' -name 'PortNumber' -Value \$portvalue"
    echo "New-NetFirewallRule -DisplayName 'RDPPORTLatest-TCP-In' -Profile 'Public' -Direction Inbound -Action Allow -Protocol TCP -LocalPort \$portvalue"
    echo
    echo "Management Commands:"
    echo "- Monitor: ./scripts/monitor-rdpgw.sh"
    echo "- Logs: docker compose -f docker-compose-rdpgw.yaml logs"
    echo "- Stop: docker compose -f docker-compose-rdpgw.yaml down"
    echo "=========================================="
}

# Main execution
main() {
    echo "=========================================="
    log_header "RDP Gateway Setup with Cloudflare"
    echo "=========================================="
    echo
    
    create_rdpgw_directories
    process_nginx_template
    generate_ssl_certificates
    setup_user_authentication
    configure_environment
    setup_cloudflare_tunnel
    configure_hosts
    test_rdpgw_config
    start_rdpgw_services
    display_setup_info
}

# Run main function
main "$@" 