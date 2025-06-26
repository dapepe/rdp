#!/bin/bash

# Guacamole Monitoring Script
# This script monitors the health and status of Guacamole and Cloudflare containers

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

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    log_error "Docker is not running"
    exit 1
fi

echo "=========================================="
log_header "Guacamole & Cloudflare Tunnel Monitor"
echo "=========================================="
echo

# Check container status
log_header "Container Status"
echo "-------------------"

# Guacamole containers
if docker compose -f docker-compose-guacamole.yaml ps | grep -q "Up"; then
    log_info "Guacamole containers are running"
    docker compose -f docker-compose-guacamole.yaml ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
else
    log_error "Guacamole containers are not running"
fi

echo

# Cloudflare container
if docker compose -f docker-compose-cloudflare.yaml ps | grep -q "Up"; then
    log_info "Cloudflare tunnel container is running"
    docker compose -f docker-compose-cloudflare.yaml ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
else
    log_error "Cloudflare tunnel container is not running"
fi

echo

# RDP Gateway containers (if available)
if [ -f "docker-compose-rdpgw.yaml" ] && docker compose -f docker-compose-rdpgw.yaml ps | grep -q "Up"; then
    log_info "RDP Gateway containers are running"
    docker compose -f docker-compose-rdpgw.yaml ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
elif [ -f "docker-compose-rdpgw.yaml" ]; then
    log_warn "RDP Gateway containers are not running"
else
    log_info "RDP Gateway not configured"
fi

echo

# RDP Gateway uses unified Cloudflare tunnel
log_info "RDP Gateway tunnel: Unified with main Cloudflare service"

echo

# Check container health
log_header "Container Health"
echo "-------------------"

# Check Guacamole health
if docker compose -f docker-compose-guacamole.yaml exec -T guacamole curl -f http://localhost:8080/guacamole/ >/dev/null 2>&1; then
    log_info "Guacamole web interface is healthy"
else
    log_warn "Guacamole web interface health check failed"
fi

# Check GuacD health
if docker compose -f docker-compose-guacamole.yaml exec -T guacd pgrep guacd >/dev/null 2>&1; then
    log_info "GuacD daemon is healthy"
else
    log_warn "GuacD daemon health check failed"
fi

# Check Cloudflare tunnel health
if docker compose -f docker-compose-cloudflare.yaml exec -T cloudflare cloudflared tunnel info >/dev/null 2>&1; then
    log_info "Cloudflare tunnel is healthy"
else
    log_warn "Cloudflare tunnel health check failed"
fi

echo

# Check resource usage
log_header "Resource Usage"
echo "-----------------"

echo "Memory usage:"
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}" | grep -E "(guacamole|cloudflare|guacd)" || log_warn "No containers found"

echo
echo "CPU usage:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.NetIO}}" | grep -E "(guacamole|cloudflare|guacd)" || log_warn "No containers found"

echo

# Check network connectivity
log_header "Network Connectivity"
echo "----------------------"

# Check if Guacamole is accessible locally
if curl -f http://localhost:8080/guacamole/ >/dev/null 2>&1; then
    log_info "Guacamole is accessible locally (http://localhost:8080)"
else
    log_warn "Guacamole is not accessible locally"
fi

# Check Docker network
if docker network inspect guac-cloudflare_cloudflared >/dev/null 2>&1; then
    log_info "✓ Docker network 'guac-cloudflare_cloudflared' exists"
    
    # Show network details
    subnet=$(docker network inspect guac-cloudflare_cloudflared --format='{{range .IPAM.Config}}{{.Subnet}}{{end}}')
    echo "  Network subnet: $subnet"
    
    # Show connected containers  
    container_count=$(docker network inspect guac-cloudflare_cloudflared --format='{{len .Containers}}')
    echo "  Connected containers: $container_count"
else
    log_error "Docker network 'guac-cloudflare_cloudflared' not found"
    echo "  This may indicate network conflicts or services not started."
    echo "  Run './scripts/fix-network-conflict.sh' to resolve."
fi

# Check for conflicting networks
conflicting_networks=$(docker network ls | grep -E "(rdp.*cloudflared|cloudflared)" | grep -v "guac-cloudflare_cloudflared" | wc -l)
if [ "$conflicting_networks" -gt 0 ]; then
    log_warn "Found potentially conflicting networks:"
    docker network ls | grep -E "(rdp.*cloudflared|cloudflared)" | grep -v "guac-cloudflare_cloudflared" | sed 's/^/  /'
    echo "  Consider running './scripts/fix-network-conflict.sh' to clean up."
else
    log_info "✓ No conflicting networks detected"
fi

echo

# Check logs for errors
log_header "Recent Errors (last 10 lines)"
echo "--------------------------------"

echo "Guacamole logs:"
docker compose -f docker-compose-guacamole.yaml logs --tail=10 guacamole | grep -i error || log_info "No errors found in Guacamole logs"

echo
echo "GuacD logs:"
docker compose -f docker-compose-guacamole.yaml logs --tail=10 guacd | grep -i error || log_info "No errors found in GuacD logs"

echo
echo "Cloudflare tunnel logs:"
docker compose -f docker-compose-cloudflare.yaml logs --tail=10 cloudflare | grep -i error || log_info "No errors found in Cloudflare logs"

echo

# Check volumes
log_header "Volume Status"
echo "---------------"

if docker volume ls | grep -q "guac_config"; then
    log_info "Guacamole config volume exists"
else
    log_error "Guacamole config volume not found"
fi

if docker volume ls | grep -q "cloudflare_config"; then
    log_info "Cloudflare config volume exists"
else
    log_warn "Cloudflare config volume not found"
fi

echo

# Summary
log_header "Summary"
echo "--------"

total_containers=$(docker compose -f docker-compose-guacamole.yaml ps -q | wc -l)
total_containers=$((total_containers + $(docker compose -f docker-compose-cloudflare.yaml ps -q | wc -l)))
running_containers=$(docker compose -f docker-compose-guacamole.yaml ps | grep -c "Up" || echo "0")
running_containers=$((running_containers + $(docker compose -f docker-compose-cloudflare.yaml ps | grep -c "Up" || echo "0")))

if [ "$running_containers" -eq "$total_containers" ]; then
    log_info "All containers are running ($running_containers/$total_containers)"
else
    log_error "Some containers are not running ($running_containers/$total_containers)"
fi

echo
echo "==========================================" 