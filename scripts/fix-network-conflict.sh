#!/bin/bash

# Fix Docker Network Conflict Script
# This script resolves network conflicts when setting up Guacamole + RDP Gateway

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

# Check current networks
check_networks() {
    log_header "Checking Current Docker Networks"
    
    echo
    echo "Current Docker networks:"
    docker network ls | head -20
    echo
    
    echo "Networks that might conflict:"
    docker network ls | grep -E "(guac|cloudflared|rdp)" || echo "No relevant networks found"
    echo
}

# Stop all services
stop_services() {
    log_header "Stopping All Services"
    
    # Stop all compose services that might be using the networks
    services=(
        "docker-compose-guacamole.yaml"
        "docker-compose-cloudflare.yaml"
        "docker-compose-rdpgw.yaml"
        # Removed: "docker-compose-cloudflare-rdpgw.yaml" - using unified tunnel
        # Removed: "docker-compose.prod.yaml" - not used in current setup
    )
    
    for service in "${services[@]}"; do
        if [ -f "$service" ]; then
            log_info "Stopping $service..."
            docker compose -f "$service" down 2>/dev/null || true
        fi
    done
    
    log_info "All services stopped"
    sleep 5
}

# Remove conflicting networks
remove_networks() {
    log_header "Removing Conflicting Networks"
    
    # Remove networks that might conflict
    networks_to_remove=(
        "guac-cloudflare_cloudflared"
        "rdp_cloudflared" 
        "cloudflared"
    )
    
    for network in "${networks_to_remove[@]}"; do
        if docker network inspect "$network" >/dev/null 2>&1; then
            log_info "Removing network: $network"
            docker network rm "$network" 2>/dev/null || log_warn "Failed to remove $network (may be in use)"
        else
            log_info "Network $network does not exist"
        fi
    done
}

# Clean up unused networks
cleanup_networks() {
    log_header "Cleaning Up Unused Networks"
    
    log_info "Removing unused Docker networks..."
    docker network prune -f
    log_info "Network cleanup completed"
}

# Display network information
show_network_info() {
    log_header "Network Configuration Information"
    
    echo
    echo "=========================================="
    echo "Docker Network Configuration Guide"
    echo "=========================================="
    echo
    echo "Main Guacamole Network:"
    echo "  Name: guac-cloudflare_cloudflared"
    echo "  Subnet: 172.18.0.0/16"
    echo "  Created by: docker-compose-guacamole.yaml"
    echo
    echo "IP Address Allocation:"
    echo "  172.18.0.2 - Cloudflare tunnel (main)"
    echo "  172.18.0.3 - Guacamole web app"
    echo "  172.18.0.4 - Guacd daemon"
    echo "  172.18.0.5 - PostgreSQL database"
    echo "  172.18.0.6 - RDP Gateway"
    echo "  172.18.0.7 - FreeRDP Gateway"
    echo "  172.18.0.8 - Cloudflare tunnel (RDP)"
    echo "  172.18.0.9 - RDP Gateway proxy"
    echo
    echo "Startup Order:"
    echo "  1. Main Guacamole services (creates network)"
    echo "  2. Cloudflare tunnel for Guacamole"
    echo "  3. RDP Gateway services (uses existing network)"
    echo "  4. Cloudflare tunnel for RDP Gateway"
    echo
    echo "=========================================="
}

# Start services in correct order
start_services() {
    log_header "Starting Services in Correct Order"
    
    echo
    read -p "Start main Guacamole services? (y/n): " start_main
    
    if [ "$start_main" = "y" ] || [ "$start_main" = "Y" ]; then
        log_info "Starting main Guacamole services..."
        docker compose -f docker-compose-guacamole.yaml up -d
        
        log_info "Waiting for Guacamole to initialize..."
        sleep 30
        
        log_info "Starting Cloudflare tunnel for Guacamole..."
        docker compose -f docker-compose-cloudflare.yaml up -d
        
        log_info "Main services started successfully"
        
        echo
        read -p "Start RDP Gateway services? (y/n): " start_rdp
        
        if [ "$start_rdp" = "y" ] || [ "$start_rdp" = "Y" ]; then
            log_info "Starting RDP Gateway services..."
            docker compose -f docker-compose-rdpgw.yaml up -d
            
            log_info "Waiting for RDP Gateway to initialize..."
            sleep 20
            
            log_info "RDP Gateway uses unified Cloudflare tunnel - no separate tunnel needed"
            
            log_info "RDP Gateway services started successfully"
        fi
    else
        log_info "Services not started. Run './setup.sh' when ready."
    fi
}

# Verify final state
verify_setup() {
    log_header "Verifying Network Setup"
    
    echo
    echo "Final network state:"
    docker network ls | grep -E "(guac|cloudflared)" || echo "No Guacamole networks found"
    
    echo
    echo "Running containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -15
    
    if docker network inspect guac-cloudflare_cloudflared >/dev/null 2>&1; then
        echo
        log_info "✓ Network successfully created and configured"
        
        # Show network subnet
        subnet=$(docker network inspect guac-cloudflare_cloudflared --format='{{range .IPAM.Config}}{{.Subnet}}{{end}}')
        echo "Network subnet: $subnet"
    else
        log_warn "Main network not found - this is normal if no services are running"
    fi
}

# Main execution
main() {
    echo "=========================================="
    log_header "Docker Network Conflict Resolution"
    echo "=========================================="
    echo
    
    log_warn "This script will:"
    echo "1. Stop all Guacamole and RDP Gateway services"
    echo "2. Remove conflicting Docker networks"  
    echo "3. Clean up unused networks"
    echo "4. Optionally restart services in correct order"
    echo
    read -p "Continue with network conflict resolution? (y/n): " continue_fix
    
    if [ "$continue_fix" != "y" ] && [ "$continue_fix" != "Y" ]; then
        log_info "Operation cancelled"
        exit 0
    fi
    
    check_networks
    stop_services
    remove_networks
    cleanup_networks
    show_network_info
    start_services
    verify_setup
    
    echo
    log_header "Network Conflict Resolution Complete!"
    echo
    echo "What's Next:"
    echo "- Main services create the shared network automatically"
    echo "- RDP Gateway services will use the existing network" 
    echo "- Always start main services before RDP Gateway"
    echo "- Use './setup.sh' for automated setup"
    echo
    echo "If you encounter issues, check:"
    echo "- Docker daemon is running"
    echo "- No other applications using port 172.18.0.0/16"
    echo "- Sufficient Docker resources available"
}

# Run main function
main "$@"
