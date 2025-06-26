#!/bin/bash

# Guacamole Cloudflare Uninstall Script
# This script removes all components of the Guacamole + Cloudflare setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_cyan() {
    echo -e "${CYAN}$1${NC}"
}

# Script options
REMOVE_GUACAMOLE=true
REMOVE_RDPGW=true
REMOVE_BRANDING=true
REMOVE_DUO=true
REMOVE_VOLUMES=true
REMOVE_IMAGES=true
REMOVE_NETWORKS=true
KEEP_DATA=false
INTERACTIVE=false
FORCE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --guacamole-only)
            REMOVE_RDPGW=false
            REMOVE_BRANDING=false
            shift
            ;;
        --rdpgw-only)
            REMOVE_GUACAMOLE=false
            REMOVE_BRANDING=false
            REMOVE_DUO=false
            shift
            ;;
        --branding-only)
            REMOVE_GUACAMOLE=false
            REMOVE_RDPGW=false
            REMOVE_DUO=false
            REMOVE_VOLUMES=false
            REMOVE_IMAGES=false
            REMOVE_NETWORKS=false
            shift
            ;;
        --keep-data)
            KEEP_DATA=true
            REMOVE_VOLUMES=false
            shift
            ;;
        --keep-images)
            REMOVE_IMAGES=false
            shift
            ;;
        --interactive)
            INTERACTIVE=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --help)
            echo "Guacamole Cloudflare Uninstall Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --guacamole-only    Remove only Guacamole components"
            echo "  --rdpgw-only        Remove only RDP Gateway components"
            echo "  --branding-only     Remove only custom branding"
            echo "  --keep-data         Keep configuration data (volumes)"
            echo "  --keep-images       Keep Docker images"
            echo "  --interactive       Interactive mode (choose what to remove)"
            echo "  --force             Skip confirmation prompts"
            echo "  --help              Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                          # Remove everything"
            echo "  $0 --keep-data             # Remove services but keep data"
            echo "  $0 --rdpgw-only            # Remove only RDP Gateway"
            echo "  $0 --interactive           # Interactive removal"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Interactive mode
interactive_mode() {
    log_header "Interactive Uninstall Mode"
    echo
    
    read -p "Remove Guacamole services? (y/n): " choice
    [[ $choice == [Yy]* ]] && REMOVE_GUACAMOLE=true || REMOVE_GUACAMOLE=false
    
    read -p "Remove RDP Gateway services? (y/n): " choice
    [[ $choice == [Yy]* ]] && REMOVE_RDPGW=true || REMOVE_RDPGW=false
    
    read -p "Remove custom branding? (y/n): " choice
    [[ $choice == [Yy]* ]] && REMOVE_BRANDING=true || REMOVE_BRANDING=false
    
    read -p "Remove DUO extensions? (y/n): " choice
    [[ $choice == [Yy]* ]] && REMOVE_DUO=true || REMOVE_DUO=false
    
    read -p "Remove Docker volumes (configuration data)? (y/n): " choice
    [[ $choice == [Yy]* ]] && REMOVE_VOLUMES=true || REMOVE_VOLUMES=false
    
    read -p "Remove Docker images? (y/n): " choice
    [[ $choice == [Yy]* ]] && REMOVE_IMAGES=true || REMOVE_IMAGES=false
    
    read -p "Remove Docker networks? (y/n): " choice
    [[ $choice == [Yy]* ]] && REMOVE_NETWORKS=true || REMOVE_NETWORKS=false
    
    echo
}

# Show what will be removed
show_removal_plan() {
    log_header "Removal Plan"
    echo
    
    if [ "$REMOVE_GUACAMOLE" = true ]; then
        log_cyan "✓ Guacamole services will be removed"
        echo "  - Guacamole web interface"
        echo "  - Guacd daemon"
        echo "  - Cloudflare tunnel for Guacamole"
    else
        echo "✗ Guacamole services will be kept"
    fi
    
    if [ "$REMOVE_RDPGW" = true ]; then
        log_cyan "✓ RDP Gateway services will be removed"
        echo "  - RDP Gateway server"
        echo "  - RDP Gateway proxy"
        echo "  - Cloudflare tunnel for RDP Gateway"
        echo "  - FreeRDP service"
    else
        echo "✗ RDP Gateway services will be kept"
    fi
    
    if [ "$REMOVE_BRANDING" = true ]; then
        log_cyan "✓ Custom branding will be removed"
        echo "  - Custom logos and themes"
        echo "  - Branding configuration files"
    else
        echo "✗ Custom branding will be kept"
    fi
    
    if [ "$REMOVE_DUO" = true ]; then
        log_cyan "✓ DUO extensions will be removed"
        echo "  - DUO authentication extension"
        echo "  - DUO configuration files"
    else
        echo "✗ DUO extensions will be kept"
    fi
    
    if [ "$REMOVE_VOLUMES" = true ]; then
        log_cyan "✓ Docker volumes will be removed"
        echo "  - Configuration data"
        echo "  - Database data"
    else
        echo "✗ Docker volumes will be kept"
    fi
    
    if [ "$REMOVE_IMAGES" = true ]; then
        log_cyan "✓ Docker images will be removed"
        echo "  - Guacamole images"
        echo "  - Cloudflare images"
        echo "  - Nginx images"
    else
        echo "✗ Docker images will be kept"
    fi
    
    if [ "$REMOVE_NETWORKS" = true ]; then
        log_cyan "✓ Docker networks will be removed"
    else
        echo "✗ Docker networks will be kept"
    fi
    
    echo
}

# Confirmation prompt
confirm_removal() {
    if [ "$FORCE" = false ]; then
        echo
        log_warn "This action cannot be undone!"
        echo
        read -p "Are you sure you want to proceed? (yes/no): " confirmation
        
        if [ "$confirmation" != "yes" ]; then
            log_info "Uninstall cancelled"
            exit 0
        fi
    fi
}

# Stop and remove Guacamole services
remove_guacamole() {
    log_header "Removing Guacamole Services"
    
    # Stop services with volume removal if requested
    volume_flag=""
    if [ "$REMOVE_VOLUMES" = true ]; then
        volume_flag="-v"
    fi
    
    # Stop Guacamole services
    if [ -f "docker-compose-guacamole.yaml" ]; then
        log_info "Stopping Guacamole services..."
        docker compose -f docker-compose-guacamole.yaml down $volume_flag --remove-orphans 2>/dev/null || true
        log_info "Guacamole services stopped and removed"
    else
        log_warn "docker-compose-guacamole.yaml not found"
    fi
    
    # Stop Cloudflare tunnel for Guacamole
    if [ -f "docker-compose-cloudflare.yaml" ]; then
        log_info "Stopping Cloudflare tunnel for Guacamole..."
        docker compose -f docker-compose-cloudflare.yaml down $volume_flag --remove-orphans 2>/dev/null || true
        log_info "Cloudflare tunnel stopped and removed"
    else
        log_warn "docker-compose-cloudflare.yaml not found"
    fi
    
    # Stop production services if they exist
    if [ -f "docker-compose.prod.yaml" ]; then
        log_info "Stopping production services..."
        docker compose -f docker-compose.prod.yaml down $volume_flag --remove-orphans 2>/dev/null || true
        log_info "Production services stopped and removed"
    fi
    
    # Force remove any remaining containers that might have been created
    log_info "Checking for any remaining Guacamole containers..."
    remaining_containers=$(docker ps -a --format "{{.Names}}" | grep -E "(guac|postgres|cloudflare)" 2>/dev/null || true)
    if [ -n "$remaining_containers" ]; then
        log_info "Found remaining containers, removing them..."
        echo "$remaining_containers" | while IFS= read -r container; do
            if [ -n "$container" ]; then
                log_info "Removing container: $container"
                docker rm -f "$container" 2>/dev/null || log_warn "Failed to remove container: $container"
            fi
        done
    fi
}

# Stop and remove RDP Gateway services
remove_rdpgw() {
    log_header "Removing RDP Gateway Services"
    
    # Stop services with volume removal if requested
    volume_flag=""
    if [ "$REMOVE_VOLUMES" = true ]; then
        volume_flag="-v"
    fi
    
    # Stop RDP Gateway services
    if [ -f "docker-compose-rdpgw.yaml" ]; then
        log_info "Stopping RDP Gateway services..."
        docker compose -f docker-compose-rdpgw.yaml down $volume_flag --remove-orphans 2>/dev/null || true
        log_info "RDP Gateway services stopped and removed"
    else
        log_warn "docker-compose-rdpgw.yaml not found"
    fi
    
    # RDP Gateway uses the unified Cloudflare tunnel - no separate tunnel to stop
    log_info "RDP Gateway uses unified Cloudflare tunnel (no separate tunnel file)"
    
    # Force remove any remaining RDP Gateway containers
    log_info "Checking for any remaining RDP Gateway containers..."
    rdp_containers=$(docker ps -a --format "{{.Names}}" | grep -E "(rdp|nginx|freerdp)" 2>/dev/null || true)
    if [ -n "$rdp_containers" ]; then
        log_info "Found remaining RDP Gateway containers, removing them..."
        echo "$rdp_containers" | while IFS= read -r container; do
            if [ -n "$container" ]; then
                log_info "Removing container: $container"
                docker rm -f "$container" 2>/dev/null || log_warn "Failed to remove container: $container"
            fi
        done
    fi
    
    # Remove RDP Gateway configuration files
    if [ -d "rdpgw" ]; then
        log_info "Removing RDP Gateway configuration files..."
        rm -rf rdpgw/
        log_info "RDP Gateway configuration removed"
    fi
}

# Remove custom branding
remove_branding() {
    log_header "Removing Custom Branding"
    
    if [ -d "branding" ]; then
        log_info "Removing branding directory..."
        rm -rf branding/
        log_info "Custom branding removed"
    else
        log_warn "Branding directory not found"
    fi
}

# Remove DUO extensions
remove_duo() {
    log_header "Removing DUO Extensions"
    
    if [ -d "extensions" ]; then
        log_info "Removing DUO extensions..."
        rm -rf extensions/
        log_info "DUO extensions removed"
    else
        log_warn "Extensions directory not found"
    fi
}

# Remove Docker images
remove_images() {
    log_header "Removing Docker Images"
    
    # List of images to remove
    images=(
        "guacamole/guacamole:1.5.5"
        "guacamole/guacd:1.5.5"
        "abesnier/guacamole:1.5.5-pg15"
        "abesnier/guacd:1.5.5"
        "cloudflare/cloudflared:2024.11.0"
        "nginx:alpine"
        "postgres:15-alpine"
        "bolkedebruin/rdpgw:latest"
        "freerdp/freerdp:latest"
    )
    
    for image in "${images[@]}"; do
        if docker image inspect "$image" >/dev/null 2>&1; then
            log_info "Removing image: $image"
            docker image rm "$image" 2>/dev/null || log_warn "Failed to remove image: $image"
        else
            log_warn "Image not found: $image"
        fi
    done
    
    log_info "Docker images removal completed"
}

# Remove Docker networks
remove_networks() {
    log_header "Removing Docker Networks"
    
    # Get all networks created by our compose projects
    log_info "Finding networks created by Guacamole and RDP Gateway projects..."
    
    # Networks that might be created by different compose files
    potential_networks=(
        "rdp_cloudflared"                       # Main network (current)
        "guac-cloudflare_cloudflared"           # Legacy network name
        "cloudflared"                           # Generic cloudflared network
        "guac-cloudflare_default"               # Default network for main project
        "rdp_default"                           # Default network for RDP project
    )
    
    # Also find any networks with our project patterns
    additional_networks=$(docker network ls --format "{{.Name}}" | grep -E "(guac|rdp|cloudflared)" 2>/dev/null || true)
    
    # Combine all potential networks
    all_networks=(${potential_networks[@]})
    if [ -n "$additional_networks" ]; then
        while IFS= read -r network; do
            all_networks+=("$network")
        done <<< "$additional_networks"
    fi
    
    # Remove duplicates and sort
    unique_networks=($(printf "%s\n" "${all_networks[@]}" | sort -u))
    
    for network in "${unique_networks[@]}"; do
        if [ -n "$network" ] && docker network inspect "$network" >/dev/null 2>&1; then
            log_info "Removing network: $network"
            docker network rm "$network" 2>/dev/null || log_warn "Failed to remove network: $network"
        fi
    done
    
    log_info "Docker networks removal completed"
}

# Remove Docker volumes
remove_volumes() {
    log_header "Removing Docker Volumes"
    
    if [ "$REMOVE_VOLUMES" != true ]; then
        log_info "Volume removal disabled, skipping..."
        return 0
    fi
    
    # Get all volumes created by our compose projects
    log_info "Finding volumes created by Guacamole and RDP Gateway projects..."
    
    # Volumes that might be created by different compose files
    potential_volumes=(
        "guac_config"                           # Guacamole configuration volume
        "postgres_data"                         # PostgreSQL data volume
        "cloudflare_config"                     # Cloudflare tunnel configuration
        "rdpgw_config"                          # RDP Gateway configuration
        "rdpgw_certs"                           # RDP Gateway certificates
        "freerdp_config"                        # FreeRDP configuration
        "cloudflare_rdpgw_config"              # Cloudflare RDP Gateway config
        "guac-cloudflare_guac_config"          # Project-prefixed volumes
        "guac-cloudflare_postgres_data"
        "guac-cloudflare_cloudflare_config"
        "rdp_guac_config"                      # RDP project volumes
        "rdp_postgres_data"
        "rdp_rdpgw_config"
        "rdp_rdpgw_certs"
        "rdp_freerdp_config"
        "rdp_cloudflare_rdpgw_config"
    )
    
    # Also find any volumes with our project patterns
    additional_volumes=$(docker volume ls --format "{{.Name}}" | grep -E "(guac|rdp|cloudflare)" 2>/dev/null || true)
    
    # Combine all potential volumes
    all_volumes=(${potential_volumes[@]})
    if [ -n "$additional_volumes" ]; then
        while IFS= read -r volume; do
            all_volumes+=("$volume")
        done <<< "$additional_volumes"
    fi
    
    # Remove duplicates and sort
    unique_volumes=($(printf "%s\n" "${all_volumes[@]}" | sort -u))
    
    for volume in "${unique_volumes[@]}"; do
        if [ -n "$volume" ] && docker volume inspect "$volume" >/dev/null 2>&1; then
            log_info "Removing volume: $volume"
            docker volume rm "$volume" 2>/dev/null || log_warn "Failed to remove volume: $volume"
        fi
    done
    
    log_info "Docker volumes removal completed"
}

# Remove additional files
remove_additional_files() {
    log_header "Removing Additional Files"
    
    # Remove log files
    if [ -d "logs" ]; then
        log_info "Removing log files..."
        rm -rf logs/
    fi
    
    # Remove backup files
    if [ -d "backups" ]; then
        read -p "Remove backup files? (y/n): " choice
        if [[ $choice == [Yy]* ]]; then
            log_info "Removing backup files..."
            rm -rf backups/
        else
            log_info "Keeping backup files"
        fi
    fi
    
    # Remove .env file (ask for confirmation)
    if [ -f ".env" ]; then
        if [ "$FORCE" = false ]; then
            read -p "Remove .env configuration file? (y/n): " choice
            if [[ $choice == [Yy]* ]]; then
                log_info "Removing .env file..."
                rm -f .env
            else
                log_info "Keeping .env file"
            fi
        fi
    fi
}

# Clean up Docker system
cleanup_docker() {
    log_header "Cleaning Up Docker System"
    
    # Force stop any remaining containers that might be related to our projects
    log_info "Checking for any remaining project containers..."
    all_containers=$(docker ps -a --format "{{.Names}}" | grep -E "(guac|rdp|postgres|cloudflare|nginx)" 2>/dev/null || true)
    
    if [ -n "$all_containers" ]; then
        log_warn "Found additional containers that may be related to the project:"
        echo "$all_containers" | while IFS= read -r container; do
            if [ -n "$container" ]; then
                log_info "Force stopping and removing: $container"
                docker stop "$container" 2>/dev/null || true
                docker rm "$container" 2>/dev/null || true
            fi
        done
    fi
    
    # Clean up any orphaned volumes
    log_info "Removing orphaned volumes..."
    orphaned_volumes=$(docker volume ls --format "{{.Name}}" | grep -E "(guac|rdp|cloudflare)" 2>/dev/null || true)
    if [ -n "$orphaned_volumes" ]; then
        echo "$orphaned_volumes" | while IFS= read -r volume; do
            if [ -n "$volume" ]; then
                log_info "Removing orphaned volume: $volume"
                docker volume rm "$volume" 2>/dev/null || true
            fi
        done
    fi
    
    # Prune system if requested
    if [ "$FORCE" = false ]; then
        read -p "Run Docker system cleanup (removes unused containers, networks, images)? (y/n): " choice
        if [[ $choice == [Yy]* ]]; then
            log_info "Running Docker system cleanup..."
            docker system prune -af --volumes 2>/dev/null || log_warn "Docker cleanup failed"
            log_info "Docker cleanup completed"
        else
            log_info "Skipping Docker cleanup"
        fi
    else
        log_info "Running Docker system cleanup in force mode..."
        docker system prune -af --volumes 2>/dev/null || log_warn "Docker cleanup failed"
    fi
}

# Display removal summary
display_summary() {
    log_header "Uninstall Summary"
    echo
    echo "========================================"
    echo "Guacamole Cloudflare Uninstall Complete"
    echo "========================================"
    echo
    
    if [ "$REMOVE_GUACAMOLE" = true ]; then
        echo "✓ Guacamole services removed"
    fi
    
    if [ "$REMOVE_RDPGW" = true ]; then
        echo "✓ RDP Gateway services removed"
    fi
    
    if [ "$REMOVE_BRANDING" = true ]; then
        echo "✓ Custom branding removed"
    fi
    
    if [ "$REMOVE_DUO" = true ]; then
        echo "✓ DUO extensions removed"
    fi
    
    if [ "$REMOVE_VOLUMES" = true ]; then
        echo "✓ Docker volumes removed"
    else
        echo "ℹ Docker volumes preserved"
    fi
    
    if [ "$REMOVE_IMAGES" = true ]; then
        echo "✓ Docker images removed"
    else
        echo "ℹ Docker images preserved"
    fi
    
    if [ "$REMOVE_NETWORKS" = true ]; then
        echo "✓ Docker networks removed"
    else
        echo "ℹ Docker networks preserved"
    fi
    
    echo
    echo "Files and directories that may remain:"
    echo "- Docker Compose files (for reference)"
    echo "- Setup scripts (for future use)"
    echo "- README.md (documentation)"
    
    if [ "$KEEP_DATA" = true ]; then
        echo "- .env file (configuration preserved)"
        echo "- Docker volumes (data preserved)"
    fi
    
    echo
    echo "To completely remove all traces:"
    echo "- Delete the entire project directory"
    echo "- Run: docker system prune -af --volumes"
    echo
    echo "Thank you for using Guacamole Cloudflare setup!"
    echo "========================================"
}

# Main execution
main() {
    echo "========================================"
    log_header "Guacamole Cloudflare Uninstall"
    echo "========================================"
    echo
    
    # Interactive mode
    if [ "$INTERACTIVE" = true ]; then
        interactive_mode
    fi
    
    # Show removal plan
    show_removal_plan
    
    # Confirmation
    confirm_removal
    
    echo
    log_header "Starting Uninstall Process"
    echo
    
    # Execute removals based on options
    if [ "$REMOVE_GUACAMOLE" = true ]; then
        remove_guacamole
    fi
    
    if [ "$REMOVE_RDPGW" = true ]; then
        remove_rdpgw
    fi
    
    if [ "$REMOVE_BRANDING" = true ]; then
        remove_branding
    fi
    
    if [ "$REMOVE_DUO" = true ]; then
        remove_duo
    fi
    
    if [ "$REMOVE_IMAGES" = true ]; then
        remove_images
    fi
    
    if [ "$REMOVE_NETWORKS" = true ]; then
        remove_networks
    fi
    
    # Remove volumes (called separately since it has its own logic)
    remove_volumes
    
    # Additional cleanup
    remove_additional_files
    cleanup_docker
    
    # Summary
    display_summary
}

# Run main function
main "$@" 