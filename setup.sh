#!/bin/bash

# Guacamole + Cloudflare Tunnel Setup Script
# This script automates the complete setup process

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

# Check prerequisites
check_prerequisites() {
    log_header "Checking Prerequisites"
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if Docker Compose is installed
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        log_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    log_info "All prerequisites are met"
}

# Create necessary directories
create_directories() {
    log_header "Creating Directories"
    
    mkdir -p logs
    mkdir -p backups
    mkdir -p config
    mkdir -p init
    mkdir -p extensions
    mkdir -p branding
    mkdir -p branding/css
    mkdir -p lib
    
    log_info "Directories created successfully"
}

# Detect architecture and set appropriate images
detect_architecture() {
    log_header "Detecting System Architecture"
    
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64)
            log_info "Detected AMD64/x86_64 architecture"
            GUACAMOLE_IMAGE="guacamole/guacamole:1.5.5"
            GUACD_IMAGE="guacamole/guacd:1.5.5"
            ;;
        aarch64|arm64)
            log_info "Detected ARM64 architecture (Raspberry Pi)"
            GUACAMOLE_IMAGE="abesnier/guacamole:1.5.5-pg15"
            GUACD_IMAGE="guacamole/guacd:1.5.5"
            ;;
        armv7l|armv6l)
            log_warn "Detected 32-bit ARM architecture - using ARM64 images (may not work)"
            GUACAMOLE_IMAGE="abesnier/guacamole:1.5.5-pg15"
            GUACD_IMAGE="guacamole/guacd:1.5.5"
            ;;
        *)
            log_warn "Unknown architecture: $ARCH - defaulting to ARM64 images"
            GUACAMOLE_IMAGE="abesnier/guacamole:1.5.5-pg15"
            GUACD_IMAGE="guacamole/guacd:1.5.5"
            ;;
    esac
    
    log_info "Using Guacamole image: $GUACAMOLE_IMAGE"
    log_info "Using GuacD image: $GUACD_IMAGE"
}

# Setup environment file
setup_environment() {
    log_header "Setting up Environment Configuration"
    
    if [ ! -f .env ]; then
        log_info "Creating .env file from template..."
        cp env.example .env
        
        # Set architecture-specific images
        sed -i.bak "s|^GUACAMOLE_IMAGE=.*|GUACAMOLE_IMAGE=$GUACAMOLE_IMAGE|" .env
        sed -i.bak "s|^GUACD_IMAGE=.*|GUACD_IMAGE=$GUACD_IMAGE|" .env
        
        # Generate secure passwords
        POSTGRES_PASSWORD=$(openssl rand -base64 32)
        sed -i.bak "s/guacamole_password/$POSTGRES_PASSWORD/" .env
        
        log_info "Environment file created with secure passwords and correct images"
        log_warn "Please edit .env file and add your Cloudflare tunnel token"
    else
        log_info ".env file already exists"
        
        # Update images if they're using defaults
        if grep -q "abesnier/guacamole:1.5.5-pg15" .env && [ "$GUACAMOLE_IMAGE" != "abesnier/guacamole:1.5.5-pg15" ]; then
            log_info "Updating images for your architecture..."
            sed -i.bak "s|^GUACAMOLE_IMAGE=.*|GUACAMOLE_IMAGE=$GUACAMOLE_IMAGE|" .env
            sed -i.bak "s|^GUACD_IMAGE=.*|GUACD_IMAGE=$GUACD_IMAGE|" .env
        elif grep -q "guacamole/guacamole:1.5.5" .env && [ "$GUACAMOLE_IMAGE" != "guacamole/guacamole:1.5.5" ]; then
            log_info "Updating images for your architecture..."
            sed -i.bak "s|^GUACAMOLE_IMAGE=.*|GUACAMOLE_IMAGE=$GUACAMOLE_IMAGE|" .env
            sed -i.bak "s|^GUACD_IMAGE=.*|GUACD_IMAGE=$GUACD_IMAGE|" .env
        fi
    fi
}

# Setup database schema
setup_database() {
    log_header "Setting up Database Schema"
    
    if [ -f "./scripts/setup-database.sh" ]; then
        log_info "Running database setup..."
        chmod +x ./scripts/setup-database.sh
        ./scripts/setup-database.sh
    else
        log_warn "Database setup script not found, using fallback initialization"
        mkdir -p init
    fi
}

# Get Cloudflare tunnel token
get_tunnel_token() {
    log_header "Cloudflare Tunnel Configuration"
    
    # Check if tunnel token is already configured
    if [ -f ".env" ]; then
        current_token=$(grep "^CLOUDFLARE_TUNNEL_TOKEN=" .env 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'")
        
        if [ -n "$current_token" ] && [ "$current_token" != "your_tunnel_token_here" ]; then
            log_info "Cloudflare tunnel token already configured in .env file"
            log_info "Token: ${current_token:0:20}..." # Show only first 20 characters for security
            echo
            read -p "Would you like to update the tunnel token? (y/n): " update_token
            
            if [ "$update_token" != "y" ] && [ "$update_token" != "Y" ]; then
                log_info "Keeping existing tunnel token"
                return 0
            fi
        fi
    fi
    
    echo
    echo "To get your Cloudflare tunnel token:"
    echo "1. Go to https://dash.cloudflare.com"
    echo "2. Navigate to Zero Trust → Access → Tunnels"
    echo "3. Create a new tunnel or select existing one"
    echo "4. Copy the tunnel token"
    echo
    
    read -p "Enter your Cloudflare tunnel token: " tunnel_token
    
    if [ -n "$tunnel_token" ]; then
        # Update or set the tunnel token
        if grep -q "^CLOUDFLARE_TUNNEL_TOKEN=" .env 2>/dev/null; then
            # Replace existing token
            sed -i.bak "s/^CLOUDFLARE_TUNNEL_TOKEN=.*/CLOUDFLARE_TUNNEL_TOKEN=$tunnel_token/" .env
        else
            # Add new token
            echo "CLOUDFLARE_TUNNEL_TOKEN=$tunnel_token" >> .env
        fi
        log_info "Tunnel token configured successfully"
    else
        log_warn "No tunnel token provided. Please edit .env file manually."
    fi
}

# Handle network conflicts
handle_network_conflicts() {
    log_header "Checking for Network Conflicts"
    
    # Check if there are any conflicting networks
    conflicting_networks=$(docker network ls | grep -E "(guac-cloudflare_cloudflared|rdp.*cloudflared)" | wc -l)
    
    if [ "$conflicting_networks" -gt 0 ]; then
        log_warn "Found potentially conflicting Docker networks"
        echo
        echo "Existing networks:"
        docker network ls | grep -E "(guac|cloudflared|rdp)" || echo "None found"
        echo
        read -p "Would you like to clean up conflicting networks? (y/n): " cleanup_networks
        
        if [ "$cleanup_networks" = "y" ] || [ "$cleanup_networks" = "Y" ]; then
            log_info "Stopping any running services..."
            docker compose -f docker-compose-guacamole.yaml down 2>/dev/null || true
            docker compose -f docker-compose-cloudflare.yaml down 2>/dev/null || true
            docker compose -f docker-compose-rdpgw.yaml down 2>/dev/null || true
            docker compose -f docker-compose-cloudflare-rdpgw.yaml down 2>/dev/null || true
            
            log_info "Removing conflicting networks..."
            docker network rm guac-cloudflare_cloudflared 2>/dev/null || true
            docker network rm rdp_cloudflared 2>/dev/null || true
            
            log_info "Cleaning up unused networks..."
            docker network prune -f
            
            log_info "Network conflicts resolved"
        else
            log_warn "Proceeding with existing networks - this may cause conflicts"
        fi
    else
        log_info "No network conflicts detected"
    fi
}

# Start services
start_services() {
    log_header "Starting Services"
    
    # Load environment variables
    if [ -f .env ]; then
        export $(cat .env | grep -v '^#' | xargs)
    fi
    
    log_info "Starting Guacamole services..."
    docker compose -f docker-compose-guacamole.yaml up -d
    
    log_info "Waiting for Guacamole to be ready..."
    sleep 30
    
    log_info "Starting Cloudflare tunnel..."
    docker compose -f docker-compose-cloudflare.yaml up -d
    
    log_info "Services started successfully"
}

# Verify setup
verify_setup() {
    log_header "Verifying Setup"
    
    # Wait for services to be ready
    sleep 30
    
    # Check if containers are running
    if docker compose -f docker-compose-guacamole.yaml ps | grep -q "Up"; then
        log_info "Guacamole containers are running"
    else
        log_error "Guacamole containers are not running"
        return 1
    fi
    
    if docker compose -f docker-compose-cloudflare.yaml ps | grep -q "Up"; then
        log_info "Cloudflare tunnel is running"
    else
        log_error "Cloudflare tunnel is not running"
        return 1
    fi
    
    # Check if Guacamole is accessible
    if curl -f http://localhost:8080/guacamole/ &> /dev/null; then
        log_info "Guacamole is accessible at http://localhost:8080"
    else
        log_warn "Guacamole is not accessible locally (this is normal if port mapping is disabled)"
    fi
    
    log_info "Setup verification completed"
}

# Setup optional features
setup_optional_features() {
    log_header "Optional Features Setup"
    
    echo
    echo "Would you like to configure optional features?"
    echo
    read -p "Setup DUO Security 2FA? (y/n): " setup_duo
    read -p "Setup custom branding? (y/n): " setup_branding
    read -p "Setup RDP Gateway for native RDP clients? (y/n): " setup_rdpgw
    
    if [ "$setup_duo" = "y" ] || [ "$setup_duo" = "Y" ]; then
        log_info "Setting up DUO Security 2FA..."
        if [ -f "./scripts/setup-duo.sh" ]; then
            chmod +x ./scripts/setup-duo.sh
            ./scripts/setup-duo.sh
        else
            log_warn "DUO setup script not found"
        fi
    fi
    
    if [ "$setup_branding" = "y" ] || [ "$setup_branding" = "Y" ]; then
        log_info "Setting up custom branding..."
        if [ -f "./scripts/setup-branding.sh" ]; then
            chmod +x ./scripts/setup-branding.sh
            ./scripts/setup-branding.sh
        else
            log_warn "Branding setup script not found"
        fi
    fi
    
    if [ "$setup_rdpgw" = "y" ] || [ "$setup_rdpgw" = "Y" ]; then
        log_info "Setting up RDP Gateway..."
        if [ -f "./scripts/setup-rdpgw.sh" ]; then
            chmod +x ./scripts/setup-rdpgw.sh
            ./scripts/setup-rdpgw.sh
        else
            log_warn "RDP Gateway setup script not found"
        fi
    fi
}

# Display final information
display_final_info() {
    log_header "Setup Complete!"
    
    echo
    echo "=========================================="
    echo "Guacamole + Cloudflare Tunnel Setup Complete"
    echo "=========================================="
    echo
    echo "Next Steps:"
    echo "1. Access Guacamole at http://localhost:8080"
    echo "2. Login with default credentials:"
    echo "   Username: guacadmin"
    echo "   Password: guacadmin"
    echo "3. CHANGE THE DEFAULT PASSWORD IMMEDIATELY!"
    echo "4. Configure your Cloudflare tunnel in the dashboard"
    echo "5. Add remote connections in Guacamole"
    echo
    echo "Optional Features:"
    echo "- Setup DUO 2FA: ./scripts/setup-duo.sh"
    echo "- Setup custom branding: ./scripts/setup-branding.sh"
    echo "- Setup RDP Gateway: ./scripts/setup-rdpgw.sh"
    echo
    echo "Useful Commands:"
    echo "- Check status: ./scripts/monitor.sh"
    echo "- Create backup: ./scripts/backup.sh"
    echo "- View logs: docker compose -f docker-compose-guacamole.yaml logs"
    echo "- Stop services: docker compose -f docker-compose-guacamole.yaml down"
    echo
    echo "For production deployment, use:"
    echo "docker compose -f docker-compose.prod.yaml up -d"
    echo
    echo "Documentation: README.md"
    echo "=========================================="
}

# Main execution
main() {
    echo "=========================================="
    log_header "Guacamole + Cloudflare Tunnel Setup"
    echo "=========================================="
    echo
    
    check_prerequisites
    create_directories
    detect_architecture
    setup_environment
    setup_database
    get_tunnel_token
    handle_network_conflicts
    start_services
    verify_setup
    setup_optional_features
    display_final_info
}

# Run main function
main "$@" 