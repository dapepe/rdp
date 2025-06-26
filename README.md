# Apache Guacamole with Cloudflare Tunnel & RDP Gateway

This repository provides a comprehensive, production-ready setup for secure remote access using Apache Guacamole, RDP Gateway, and Cloudflare Tunnels with enterprise-grade features including DUO 2FA and custom branding.

## Overview

**Apache Guacamole** is a clientless remote desktop gateway that supports VNC, RDP, and SSH protocols through a web browser. **RDP Gateway** provides native RDP client access for users who prefer traditional RDP connections. Both solutions use **Cloudflare Tunnels** to securely expose services to the internet without opening firewall ports.

### Key Features

- 🌐 **Web-based Remote Access** (Guacamole) - Access any system through your browser
- 🖥️ **Native RDP Gateway** - Use standard RDP clients (Windows, macOS, Linux)
- 🔐 **DUO Security 2FA** - Enterprise two-factor authentication
- 🎨 **Custom Branding** - Professional themes and organization branding
- ☁️ **Cloudflare Integration** - Zero Trust security and tunneled access
- 📊 **Comprehensive Monitoring** - Health checks, logging, and session management
- 🔧 **Production Ready** - Resource limits, backups, and automated setup

## Prerequisites

- Docker and Docker Compose installed
- A Cloudflare account with Zero Trust enabled
- Domain name configured in Cloudflare (for tunnel endpoints)
- OpenSSL (for certificate generation)
- (Optional) DUO Security account for 2FA
- (Optional) ImageMagick (for custom branding assets)

### Supported Architectures

- **AMD64/x86_64**: Intel/AMD processors (most desktop/server systems)
- **ARM64/aarch64**: Apple Silicon Macs, Raspberry Pi 4/5, AWS Graviton
- **ARM32**: Raspberry Pi 3 and older (limited support)

The setup script automatically detects your architecture and uses the appropriate Docker images:
- **AMD64 systems**: Uses official `guacamole/guacamole` and `guacamole/guacd` images
- **ARM64 systems**: Uses community `abesnier/guacamole` and `abesnier/guacd` images with ARM64 support

## Architecture

```
Internet → Cloudflare Tunnels → [Guacamole Web UI | RDP Gateway] → Target Systems
                                         ↓
                              [DUO 2FA | Custom Branding | Zero Trust]
```

### Components

- **Guacamole Web UI**: Browser-based remote desktop access (port 8080)
- **RDP Gateway**: Native RDP client support (port 3391) 
- **Nginx Proxy**: SSL termination and protocol routing (port 443)
- **PostgreSQL**: Database backend for user management and sessions
- **Cloudflare Tunnels**: Secure external access without port forwarding
- **DUO 2FA**: Optional two-factor authentication layer
- **Custom Network**: Isolated Docker bridge network (172.18.0.0/16)

## Network Configuration

### Docker Network Architecture

All services operate within an isolated Docker bridge network to ensure security and proper communication:

```
Docker Network: rdp_cloudflared (172.18.0.0/16)
├── 172.18.0.2 → Cloudflare Tunnel (cloudflare)
├── 172.18.0.3 → Guacamole Web Interface (guacamole)
└── 172.18.0.5 → RDP Gateway (rdpgw)
```

### Service Details

| Service | Container Name | Internal IP | Internal Port | External Port | Protocol |
|---------|---------------|-------------|---------------|---------------|----------|
| **Cloudflare Tunnel** | `cloudflare` | `172.18.0.2` | N/A | N/A | HTTP/HTTPS Proxy |
| **Guacamole Web** | `guacamole` | `172.18.0.3` | `8080` | `127.0.0.1:8080` | HTTP |
| **RDP Gateway** | `rdpgw` | `172.18.0.5` | `3391` | `0.0.0.0:3391` | RDP/HTTP |

### Port Mappings

#### Guacamole Web Interface
- **Internal**: `172.18.0.3:8080`
- **External**: `127.0.0.1:8080` (localhost only for security)
- **Cloudflare**: `https://guac.yourcompany.com/guacamole`

#### RDP Gateway (Optional)
- **Internal**: `172.18.0.5:3391` (RDP protocol)
- **External**: `0.0.0.0:3391` (all interfaces)
- **Web Interface**: `172.18.0.5:8080` (management)
- **Cloudflare**: `https://rdpgw.yourcompany.com`

### Access Methods

#### 1. External Access (Recommended)
- **Guacamole**: `https://guac.yourcompany.com/guacamole`
- **RDP Gateway**: `rdp://rdpgw.yourcompany.com:3391`

#### 2. Local Access (Testing/Development)
- **Guacamole**: `http://localhost:8080/guacamole`
- **RDP Gateway**: `rdp://localhost:3391`

### Security Features

1. **Network Isolation**: All services communicate through isolated Docker network
2. **Localhost Binding**: Guacamole bound to localhost only (`127.0.0.1:8080`)
3. **Cloudflare Protection**: All external traffic routed through Cloudflare Zero Trust
4. **No Direct Internet Exposure**: No services directly exposed to the internet
5. **Tunnel Authentication**: Cloudflare handles authentication and access control

### Firewall Configuration

No firewall rules required on the host system:
- ✅ **Cloudflare Tunnel**: Outbound HTTPS connections only
- ✅ **Guacamole**: Localhost binding prevents external access
- ✅ **RDP Gateway**: Optional, can be disabled if not needed
- ✅ **No Inbound Rules**: All access via Cloudflare tunnels

### Network Troubleshooting

#### Check Network Status
```bash
# View Docker networks
docker network ls

# Inspect the network
docker network inspect rdp_cloudflared

# Check service IPs
docker inspect $(docker ps -q) | grep -E "(NetworkMode|IPAddress)"

# Test internal connectivity
docker exec -it guac-cloudflare-guacamole-1 ping 172.18.0.2
```

#### Common Network Issues
- **Service not accessible**: Verify correct IP addresses and ports
- **Network conflicts**: Run `./scripts/fix-network-conflict.sh`
- **Tunnel not working**: Check Cloudflare dashboard for tunnel status
- **Connection refused**: Ensure services are healthy with `docker ps`

## Setup Instructions

### 1. Create Cloudflare Tunnel

1. **Log into Cloudflare Dashboard**
   - Visit [https://dash.cloudflare.com](https://dash.cloudflare.com)
   - Select your domain (must be managed by Cloudflare)

2. **Navigate to Zero Trust**
   - Go to **Zero Trust** → **Access** → **Tunnels**
   - Click **Create a tunnel**

3. **Create the Tunnel**
   - Choose **Cloudflared** as the connector
   - Give your tunnel a descriptive name (e.g., "guacamole-rdp-gateway")
   - Click **Save tunnel**

4. **Configure Tunnel Endpoints** (in one tunnel)
   
   **Add both routes to the same tunnel:**
   
   - **Route 1 - Guacamole Web Interface**:
     - **Subdomain**: `guac` (or your preference)
     - **Domain**: Your domain (e.g., `yourcompany.com`)
     - **Service**: `http://172.18.0.3:8080`
     - **Path**: `/guacamole` (optional, for path-based routing)
   
   - **Route 2 - RDP Gateway** (optional):
     - **Subdomain**: `rdpgw`
     - **Domain**: Your domain
     - **Service**: `rdp://172.18.0.5:3391`
   
   **Result**: One tunnel, multiple routes to different internal services.

5. **Copy the Tunnel Token**
   - After saving, copy the tunnel token that appears
   - This token will be used for both services (unified configuration)
   - Keep this token secure as it provides access to your services

### Example Tunnel Configuration

Your final access points will be:
- **Guacamole**: `https://guac.yourcompany.com/guacamole` (web interface)
- **RDP Gateway**: `rdpgw.yourcompany.com:3391` (RDP protocol for native clients)

### 2. Automated Setup (Recommended)

The setup script will automatically configure everything, including the tunnel token:

```bash
# Run the interactive setup script
./setup.sh
```

The script will:
1. Detect your system architecture (AMD64/ARM64)
2. Create the `.env` file with secure passwords
3. Prompt for your Cloudflare tunnel token
4. Configure both Guacamole and RDP Gateway to use the same tunnel
5. Start all services in the correct order
6. **Display detailed network configuration** including:
   - Service IP addresses and ports
   - Access URLs (local and Cloudflare)
   - Default credentials
   - Security recommendations

### 3. Manual Environment Configuration (Optional)

If you prefer manual setup, copy the example environment file:

```bash
cp env.example .env
```

Edit the `.env` file and set your tunnel token:

```bash
# Single tunnel token routes to both Guacamole and RDP Gateway
CLOUDFLARE_TUNNEL_TOKEN=your_actual_tunnel_token_here
```

**Important**: One tunnel handles both services by routing to different internal IPs:
- Guacamole: `http://172.18.0.3:8080`
- RDP Gateway: `rdp://172.18.0.5:3391`

### 4. Alternative Manual Setup

**If using the automated setup above, skip this section.**

**Manual Docker Compose Setup**:
```bash
# Ensure .env file is configured with tunnel token first
# Then start services in correct order:

# 1. Start Guacamole (creates shared network)
docker compose -f docker-compose-guacamole.yaml up -d

# 2. Start unified Cloudflare tunnel (routes to both services)
docker compose -f docker-compose-cloudflare.yaml up -d

# 3. Optional: Start RDP Gateway (uses existing network and tunnel)
docker compose -f docker-compose-rdpgw.yaml up -d
```

**Important**: Start services in this exact order to avoid network conflicts.

### 5. Verify Services

Check if containers are running:
```bash
docker container ps
```

You should see output similar to:
```
CONTAINER ID   IMAGE                                    COMMAND                  CREATED         STATUS                     PORTS                    NAMES
462e74a50462   cloudflare/cloudflared:2024.11.0        "cloudflared tunnel …"   13 seconds ago  Up 12 seconds                                      guac-cloudflare-cloudflare-1
df9decd3f3c9   abesnier/guacamole:1.5.5-pg15           "/opt/guacamole/bin/…"   About a minute  Up About a minute (healthy) 127.0.0.1:8080->8080/tcp  guac-cloudflare-guacamole-1
a1b2c3d4e5f6   abesnier/guacd:1.5.5                    "/bin/sh -c '/usr/lo…"   About a minute  Up About a minute (healthy) 4822/tcp               guac-cloudflare-guacd-1
```

**Note**: The image names will be `guacamole/guacamole:1.5.5` and `guacamole/guacd:1.5.5` on AMD64 systems, and `abesnier/guacamole:1.5.5-pg15` and `abesnier/guacd:1.5.5` on ARM64 systems like Raspberry Pi.

### 6. Initial Access & Security

#### Guacamole Web Access
1. Access Guacamole at `http://localhost:8080` (or your tunnel URL)
2. **CRITICAL**: Change the default credentials immediately:
   - **Username**: `guacadmin`
   - **Password**: `guacadmin`

#### RDP Gateway Access
- **Web Interface**: `https://rdpgw.yourorganization.com`
- **Native RDP**: Configure gateway as `rdpgw.yourorganization.com:3391`

## Configuration Details

### Guacamole Container
- **Image**: 
  - AMD64: `guacamole/guacamole:1.5.5`
  - ARM64: `abesnier/guacamole:1.5.5-pg15` (Raspberry Pi)
- **Port**: 8080 (bound to localhost only for security)
- **Database**: PostgreSQL 15 (integrated with persistent storage)
- **Persistence**: Configuration stored in Docker volume `guac_config`
- **Network**: Custom bridge network with static IP `172.18.0.3`

### Cloudflare Tunnel Container
- **Image**: `cloudflare/cloudflared:2024.11.0`
- **Command**: `tunnel run`
- **Network**: Custom bridge network with static IP `172.18.0.2`
- **Restart Policy**: `unless-stopped`

## Security Considerations

### 1. Change Default Credentials
**CRITICAL**: Change the default Guacamole admin credentials immediately after first login.

### 2. Use Cloudflare Access Policies
Configure Zero Trust policies in Cloudflare to:
- Require authentication before accessing Guacamole
- Restrict access to specific email domains
- Enable multi-factor authentication
- Set up device posture checks

### 3. Network Security
- The setup uses a custom Docker network for isolation
- Guacamole is only accessible through the Cloudflare tunnel
- Port is bound to localhost only (`127.0.0.1:8080:8080`) for security

### 4. Regular Updates
- Keep Docker images updated
- Monitor for security patches
- Update tunnel token if compromised

## Adding Remote Connections

1. Log into Guacamole as admin
2. Navigate to **Settings** → **Connections**
3. Click **New Connection**
4. Configure connection details:
   - **Name**: Descriptive name for the connection
   - **Protocol**: RDP, VNC, or SSH
   - **Hostname**: IP address or hostname of target system
   - **Port**: Protocol port (3389 for RDP, 22 for SSH, 5900 for VNC)
   - **Username/Password**: Target system credentials

## Adding Users

1. Navigate to **Settings** → **Users**
2. Click **New User**
3. Set username and password
4. Assign permissions and connections

## DUO Security 2FA Integration

### Setting up DUO 2FA

1. **Create DUO Account**:
   - Sign up at [https://duo.com](https://duo.com)
   - Create a Web SDK application in DUO Admin Panel

2. **Configure DUO Extension**:
   ```bash
   ./scripts/setup-duo.sh
   ```

3. **Update Environment Variables**:
   Edit your `.env` file and add the DUO configuration:
   ```bash
   # DUO Security 2FA Configuration
   DUO_INTEGRATION_KEY=your_integration_key
   DUO_SECRET_KEY=your_secret_key
   DUO_API_HOSTNAME=api-xxxxxxxx.duosecurity.com
   DUO_APPLICATION_KEY=your_40_char_application_key
   DUO_ENROLLMENT_URL=https://api-xxxxxxxx.duosecurity.com/frame/web/v1/auth
   ```

4. **Restart Services**:
   ```bash
   docker compose -f docker-compose-guacamole.yaml restart
   ```

### DUO Configuration Options

- **User Group Enforcement**: Require 2FA for specific groups only
- **IP Whitelisting**: Skip 2FA for trusted IP ranges
- **Device Memory**: Remember trusted devices for specified duration
- **Fail Mode**: Configure behavior when DUO service is unavailable

Edit `extensions/duo-auth.properties` for advanced configuration.

## Custom Branding and Theming

### Setting up Custom Branding

1. **Run Branding Setup**:
   ```bash
   ./scripts/setup-branding.sh
   ```

2. **Replace Logo**:
   - Add your logo as `branding/logo.png`
   - Recommended size: 200x80 pixels
   - Supported formats: PNG, JPG, SVG

3. **Customize Theme**:
   - Edit `branding/css/custom.css` for custom styling
   - Use predefined themes: `theme-dark`, `theme-corporate-blue`, `theme-green`

4. **Configure Messages**:
   Edit your `.env` file and add the branding configuration:
   ```bash
   # Custom Branding Configuration
   LOGIN_MESSAGE=Welcome to Your Secure Remote Access Portal
   ORGANIZATION_NAME=Your Organization
   SUPPORT_EMAIL=support@yourorganization.com
   CUSTOM_THEME=theme-dark
   ```

### Available Themes

- **Custom** (`custom`): Default customizable theme
- **Corporate Blue** (`theme-corporate-blue`): Professional blue theme
- **Dark** (`theme-dark`): Dark mode theme
- **Green** (`theme-green`): Green corporate theme

### Branding Components

- **Logo**: Custom organization logo
- **Favicon**: Custom browser icon
- **CSS Themes**: Complete visual customization
- **Login Messages**: Custom welcome and instruction text
- **Background Images**: Custom background graphics
- **Color Schemes**: Customizable color palettes

## RDP Gateway Integration

### Overview

RDP Gateway provides native RDP client access through Cloudflare tunnels, complementing Guacamole's web-based access. This allows users to connect using standard Windows RDP clients while maintaining the security benefits of Cloudflare Zero Trust.

### Setting up RDP Gateway

1. **Run RDP Gateway Setup**:
   ```bash
   ./scripts/setup-rdpgw.sh
   ```

2. **Configure Target Servers**:
   - Use custom RDP ports for enhanced security (as recommended in the [EdTech IRL article](https://www.edtechirl.com/p/apache-guacamole-how-to-set-up-and))
   - Update `rdpgw/hosts.yaml` with server details
   - Configure user permissions and access controls

3. **PowerShell Script for Custom RDP Ports**:
   ```powershell
   # Change RDP port to 13450 (example from EdTech IRL)
   $portvalue = 13450
   Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "PortNumber" -Value $portvalue
   New-NetFirewallRule -DisplayName 'RDPPORTLatest-TCP-In' -Profile 'Public' -Direction Inbound -Action Allow -Protocol TCP -LocalPort $portvalue
   New-NetFirewallRule -DisplayName 'RDPPORTLatest-UDP-In' -Profile 'Public' -Direction Inbound -Action Allow -Protocol UDP -LocalPort $portvalue
   ```

4. **Environment Configuration**:
   Edit your `.env` file and add the RDP Gateway configuration:
   ```bash
   # RDP Gateway Configuration
   RDPGW_TUNNEL_TOKEN=your_rdpgw_tunnel_token
   RDPGW_DOMAIN=rdpgw.yourorganization.com
   RDPGW_AUTH_BACKEND=local
   
   # Port Configuration (optional - defaults shown)
   RDPGW_PORT=3391                  # RDP Gateway protocol port
   RDPGW_WEB_PORT=443              # Web interface port
   RDPGW_PROXY_HTTPS_PORT=8443     # Proxy HTTPS port
   RDPGW_PROXY_HTTP_PORT=8080      # Proxy HTTP port
   FREERDP_PORT=3392               # FreeRDP service port
   
   # DUO 2FA Configuration (if using)
   DUO_ENROLLMENT_URL=https://api-xxxxxxxx.duosecurity.com/frame/web/v1/auth
   ```

### RDP Gateway Features

- **Native RDP Client Support**: Use standard Windows RDP, macOS Remote Desktop, or Linux rdesktop
- **Web Interface**: Browser-based management and connection interface
- **Role-Based Access Control**: Granular permissions per user and group
- **Session Management**: Monitor and control active sessions
- **DUO 2FA Integration**: Optional two-factor authentication
- **Custom Port Support**: Enhanced security through non-standard ports
- **SSL/TLS Encryption**: All connections encrypted in transit

### Access Methods

#### 1. Native RDP Client (Windows)
```cmd
mstsc /v:target-server /g:rdpgw.yourorganization.com
```

#### 2. Web Interface
Access the management interface at: `https://rdpgw.yourorganization.com`

#### 3. PowerShell RDP Connection
```powershell
cmdkey /generic:rdpgw.yourorganization.com /user:username /pass:password
mstsc /v:target-server /g:rdpgw.yourorganization.com
```

### Configuration Files

- **Hosts Configuration**: `rdpgw/hosts.yaml` - Define target servers and permissions
- **User Management**: `rdpgw/users.yaml` - User accounts and access control
- **Nginx Proxy**: `rdpgw/nginx/default.conf` - HTTP/HTTPS routing and security
- **SSL Certificates**: `rdpgw/ssl/` - TLS certificates for secure connections

### Volume Structure

RDP Gateway uses a dedicated volume structure for better organization and management:

```
data/rdpgw/                          # Main RDP Gateway data volume
├── conf/                            # Configuration files (auto-synced)
│   ├── hosts.yaml                   # Target server definitions
│   ├── users.yaml                   # User accounts and permissions
│   └── nginx/                       # Nginx proxy configuration
├── certs/                           # SSL/TLS certificates
├── logs/                            # Application logs
├── backups/                         # Automatic configuration backups
└── config/                          # Additional configuration data
```

**Configuration Workflow:**
1. Edit files in `rdpgw/` directory (source files)
2. Run `./scripts/rdpgw-reload.sh` to sync and reload
3. Services automatically read from `/srv/rdpgw/` (inside containers)

### Security Best Practices

1. **Custom RDP Ports**: Use non-standard ports (13450, 13451, etc.) as recommended by [EdTech IRL](https://www.edtechirl.com/p/apache-guacamole-how-to-set-up-and)
2. **Network Level Authentication**: Enable NLA on all target servers
3. **Strong Passwords**: Enforce complex password policies
4. **Session Timeouts**: Configure appropriate idle and session timeouts
5. **Audit Logging**: Enable comprehensive session and connection logging
6. **IP Restrictions**: Use Cloudflare Zero Trust policies for IP-based access control

### Integration with Existing Setup

RDP Gateway seamlessly integrates with your existing Guacamole and Cloudflare setup:

- **Shared Network**: Uses the same Docker network as Guacamole
- **Common Authentication**: Can integrate with DUO 2FA configuration
- **Unified Monitoring**: Logs and metrics in the same location
- **Cloudflare Tunnels**: Separate tunnel for RDP Gateway traffic

### Use Cases

- **IT Administration**: Native RDP access for system administrators
- **Power Users**: Users who prefer native RDP clients over web interfaces
- **Legacy Applications**: Applications that require native RDP functionality
- **Performance**: Reduced latency compared to web-based solutions
- **Offline Capability**: Some RDP features work better with native clients

### Management Commands

```bash
# Start RDP Gateway
docker compose -f docker-compose-rdpgw.yaml up -d
docker compose -f docker-compose-cloudflare-rdpgw.yaml up -d

# Reload configuration after changes
./scripts/rdpgw-reload.sh

# Monitor services
docker compose -f docker-compose-rdpgw.yaml ps
docker compose -f docker-compose-rdpgw.yaml logs

# Stop services
docker compose -f docker-compose-rdpgw.yaml down
docker compose -f docker-compose-cloudflare-rdpgw.yaml down
```

### Configuration Management

After making changes to RDP Gateway configuration files:

```bash
# Validate configuration only
./scripts/rdpgw-reload.sh --validate-only

# Force reload without prompts
./scripts/rdpgw-reload.sh --force

# Reload with backup (default)
./scripts/rdpgw-reload.sh

# Skip backup creation
./scripts/rdpgw-reload.sh --no-backup
```

## Monitoring and Troubleshooting

### Check Tunnel Status
- Visit Cloudflare dashboard: **Zero Trust** → **Access** → **Tunnels**
- Verify tunnel shows as "Active"
- Check connection logs for any issues

### Container Logs
```bash
# Check Guacamole logs
docker compose -f docker-compose-guacamole.yaml logs guacamole

# Check Cloudflare tunnel logs
docker compose -f docker-compose-cloudflare.yaml logs cloudflare
```

### Common Issues

1. **Tunnel not connecting**: Verify tunnel token is correct
2. **Guacamole not accessible**: Check if containers are healthy
3. **Connection timeouts**: Verify target systems are reachable from the Docker network

### Health Checks
```bash
# Check container health
docker container ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Test Guacamole connectivity
curl -I http://localhost:8080/guacamole/
```

## Backup and Recovery

### Backup Configuration
```bash
# Backup Guacamole configuration
docker run --rm -v guac_config:/data -v $(pwd):/backup alpine tar czf /backup/guacamole-config-backup.tar.gz -C /data .
```

### Restore Configuration
```bash
# Restore from backup
docker run --rm -v guac_config:/data -v $(pwd):/backup alpine tar xzf /backup/guacamole-config-backup.tar.gz -C /data
```

## Performance Optimization

1. **Resource Limits**: Add memory and CPU limits to containers
2. **Database Optimization**: Consider external PostgreSQL for production
3. **Caching**: Enable Guacamole's connection caching
4. **Monitoring**: Set up container monitoring with Prometheus/Grafana

## 🛑 Stopping and Removing Services

### Stop All Services
```bash
# Stop main Guacamole and Cloudflare services
docker compose -f docker-compose-guacamole.yaml down
docker compose -f docker-compose-cloudflare.yaml down

# Stop RDP Gateway services (if installed)
docker compose -f docker-compose-rdpgw.yaml down
docker compose -f docker-compose-cloudflare-rdpgw.yaml down

# Stop production services (if using)
docker compose -f docker-compose.prod.yaml down
```

### Complete Removal (Uninstall)
```bash
# Run the uninstall script (recommended)
./scripts/uninstall.sh

# Or manually remove everything:
docker compose -f docker-compose-guacamole.yaml down -v --remove-orphans
docker compose -f docker-compose-cloudflare.yaml down -v --remove-orphans
docker compose -f docker-compose-rdpgw.yaml down -v --remove-orphans
docker compose -f docker-compose-cloudflare-rdpgw.yaml down -v --remove-orphans
docker compose -f docker-compose.prod.yaml down -v --remove-orphans

# Remove Docker images (architecture-specific)
docker image rm guacamole/guacamole:1.5.5 2>/dev/null || true          # AMD64
docker image rm guacamole/guacd:1.5.5 2>/dev/null || true              # AMD64
docker image rm abesnier/guacamole:1.5.5-pg15 2>/dev/null || true      # ARM64
docker image rm abesnier/guacd:1.5.5 2>/dev/null || true               # ARM64
docker image rm cloudflare/cloudflared:2024.11.0
docker image rm nginx:alpine
docker image rm postgres:15-alpine

# Remove Docker networks
docker network rm guac-cloudflare_cloudflared

# Remove unused volumes and containers
docker system prune -af --volumes
```

### Partial Removal Options
```bash
# Remove only RDP Gateway
./scripts/uninstall.sh --rdpgw-only

# Remove only custom branding
./scripts/uninstall.sh --branding-only

# Keep data volumes (preserve configuration)
./scripts/uninstall.sh --keep-data

# Interactive mode (choose what to remove)
./scripts/uninstall.sh --interactive
```

## Available Setup Scripts

| Script | Purpose | Features |
|--------|---------|----------|
| `./setup.sh` | Main setup script | Complete automated installation |
| `./scripts/setup-duo.sh` | DUO 2FA setup | Download extension, configure authentication |
| `./scripts/setup-branding.sh` | Custom branding | Logo, themes, CSS customization |
| `./scripts/setup-rdpgw.sh` | RDP Gateway | Native RDP client support |
| `./scripts/rdpgw-reload.sh` | RDP Gateway reload | Reload configuration after changes |
| `./scripts/backup.sh` | Backup system | Automated configuration backup |
| `./scripts/restore.sh` | Restore system | Restore from backups |
| `./scripts/monitor.sh` | System monitoring | Health checks and status |
| `./scripts/uninstall.sh` | Uninstall system | Complete or partial removal |
| `./scripts/setup-database.sh` | Database setup | Download and setup PostgreSQL schema |
| `./scripts/fix-network-conflict.sh` | Network troubleshooting | Resolve Docker network conflicts |

## Production Recommendations

### Security Hardening
1. **Change Default Passwords**: Immediately change all default credentials
2. **Enable DUO 2FA**: Implement two-factor authentication
3. **Custom RDP Ports**: Use non-standard ports (13450+) as per [EdTech IRL recommendations](https://www.edtechirl.com/p/apache-guacamole-how-to-set-up-and)
4. **Cloudflare Zero Trust**: Configure access policies and device requirements
5. **Regular Updates**: Keep all components updated

### Performance & Reliability
1. **External Database**: Deploy PostgreSQL separately for better performance
2. **SSL/TLS Certificates**: Use proper CA certificates instead of self-signed
3. **Resource Monitoring**: Set up alerts for container health and resource usage
4. **Backup Strategy**: Implement automated daily backups
5. **High Availability**: Consider multiple tunnel endpoints and load balancing

### Monitoring & Maintenance
1. **Log Aggregation**: Centralize logs from all components
2. **Health Checks**: Monitor service health and connectivity
3. **Performance Metrics**: Track response times and resource usage
4. **Security Auditing**: Regular security assessments and penetration testing

## Troubleshooting

### Network Issues

#### Docker Network Conflicts
**Error**: `failed to create network cloudflared: Error response from daemon: invalid pool request: Pool overlaps with other one on this address space`

**Solution**:
```bash
# Automated fix
./scripts/fix-network-conflict.sh

# Manual fix
docker compose down  # Stop all services
docker network prune -f  # Clean up networks
docker compose -f docker-compose-guacamole.yaml up -d  # Start main services first
```

#### Service Startup Order
**Important**: Always start services in this order:
1. **Main Guacamole services** (creates the shared network)
2. **Cloudflare tunnel for Guacamole**  
3. **RDP Gateway services** (uses existing network)
4. **Cloudflare tunnel for RDP Gateway**

**Correct startup**:
```bash
# Method 1: Use setup script (recommended)
./setup.sh

# Method 2: Manual startup
docker compose -f docker-compose-guacamole.yaml up -d
sleep 30
docker compose -f docker-compose-cloudflare.yaml up -d
docker compose -f docker-compose-rdpgw.yaml up -d
docker compose -f docker-compose-cloudflare-rdpgw.yaml up -d
```

### Common Issues

| Issue | Solution |
|-------|----------|
| Network conflict error | Run `./scripts/fix-network-conflict.sh` to resolve |
| Container won't start | Check Docker logs: `docker compose logs [service]` |
| Can't access Guacamole | Verify port 8080 is accessible and tunnel is active |
| RDP Gateway connection fails | Check target server RDP port and firewall settings |
| DUO 2FA not working | Verify API credentials and connectivity to DUO service |
| SSL certificate errors | Regenerate certificates or use proper CA certificates |
| "Pool overlaps" error | Stop services, run network cleanup, restart in order |

### Diagnostic Commands

```bash
# Check all service status
./scripts/monitor.sh

# Fix network conflicts
./scripts/fix-network-conflict.sh

# View logs for specific service
docker compose -f docker-compose-guacamole.yaml logs guacamole
docker compose -f docker-compose-rdpgw.yaml logs rdpgw

# Test connectivity
curl -f http://localhost:8080/guacamole/
curl -f https://rdpgw.yourorganization.com/health

# Check Cloudflare tunnel status
docker compose -f docker-compose-cloudflare.yaml logs cloudflare

# Check Docker networks
docker network ls
docker network inspect guac-cloudflare_cloudflared
```

## File Structure

```
guac-cloudflare/
├── docker-compose-guacamole.yaml    # Guacamole web service
├── docker-compose-cloudflare.yaml   # Cloudflare tunnel for Guacamole
├── docker-compose-rdpgw.yaml        # RDP Gateway service
├── docker-compose-cloudflare-rdpgw.yaml # Cloudflare tunnel for RDP Gateway
├── docker-compose.prod.yaml         # Production configuration
├── setup.sh                         # Main setup script
├── env.example                      # Environment variables template
├── scripts/                         # Automation scripts
│   ├── setup-duo.sh                # DUO 2FA configuration
│   ├── setup-branding.sh           # Custom branding setup
│   ├── setup-rdpgw.sh             # RDP Gateway setup
│   ├── rdpgw-reload.sh             # RDP Gateway configuration reload
│   ├── backup.sh                   # Backup automation
│   ├── restore.sh                  # Restore automation
│   └── monitor.sh                  # System monitoring
├── branding/                        # Custom branding assets
│   ├── css/                        # Custom themes
│   ├── logo.png                    # Organization logo
│   └── guacamole.properties        # Branding configuration
├── rdpgw/                          # RDP Gateway source configuration
│   ├── hosts.yaml                  # Target server definitions (edit these)
│   ├── users.yaml                  # User management (edit these)
│   ├── nginx/                      # Proxy configuration
│   └── ssl/                        # SSL certificates
├── data/                           # Volume data (auto-managed)
│   └── rdpgw/                      # RDP Gateway volume data
│       ├── conf/                   # Synced configuration files
│       ├── certs/                  # SSL certificates
│       ├── logs/                   # Application logs
│       └── backups/                # Automatic backups
├── extensions/                      # Guacamole extensions (DUO, etc.)
├── logs/                           # Application logs
└── backups/                        # Automated backups
```

## Support & Documentation

### Official Documentation
- **Guacamole**: [Apache Guacamole User Guide](https://guacamole.apache.org/doc/gug/)
- **Cloudflare Tunnels**: [Cloudflare Zero Trust Documentation](https://developers.cloudflare.com/cloudflare-one/)
- **DUO Security**: [DUO Web SDK Documentation](https://duo.com/docs/duoweb)

### Community Resources
- **EdTech IRL Article**: [Apache Guacamole with Cloudflare Setup Guide](https://www.edtechirl.com/p/apache-guacamole-how-to-set-up-and)
- **Docker Documentation**: [Docker Compose Reference](https://docs.docker.com/compose/)

### Getting Help
1. Check the troubleshooting section above
2. Review service logs for error messages
3. Verify configuration files against examples
4. Test connectivity between components
5. Check Cloudflare tunnel status in dashboard

## License

This configuration is provided as-is under the MIT License for educational and commercial use. Please review individual component licenses:
- Apache Guacamole: Apache License 2.0
- Cloudflare Tunnels: Cloudflare Terms of Service
- Docker Images: Various licenses per image