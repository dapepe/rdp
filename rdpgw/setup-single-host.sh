#!/bin/bash

# RDP Gateway - Single Windows Host Setup Script
# This script helps you configure RDPGW for a single Windows host

set -e

echo "🖥️  RDP Gateway - Single Windows Host Setup"
echo "==========================================="
echo

# Get Windows host details
read -p "Enter your Windows host IP address: " WINDOWS_IP
read -p "Enter your Windows host username: " WINDOWS_USERNAME
read -s -p "Enter your Windows host password: " WINDOWS_PASSWORD
echo
read -p "Enter RDP port (default 3389): " RDP_PORT
RDP_PORT=${RDP_PORT:-3389}

# Get RDP Gateway user details
echo
echo "Now let's set up the RDP Gateway user account:"
read -p "Enter RDP Gateway username: " RDP_USER
read -s -p "Enter RDP Gateway password: " RDP_PASSWORD
echo
read -p "Enter user's full name: " FULL_NAME
read -p "Enter user's email: " USER_EMAIL

# Generate password hash for RDP Gateway user
echo
echo "🔐 Generating password hash..."
if command -v htpasswd >/dev/null 2>&1; then
    PASSWORD_HASH=$(htpasswd -bnBC 10 "" "$RDP_PASSWORD" | tr -d ':\n' | sed 's/^[^$]*//')
    echo "Password hash generated successfully"
else
    echo "❌ htpasswd not found. Please install apache2-utils (Ubuntu/Debian) or httpd-tools (CentOS/RHEL)"
    echo "Or use this online tool: https://www.web2generators.com/apache-tools/htpasswd-generator"
    echo "Use bcrypt encryption with cost 10"
    exit 1
fi

# Create hosts.yaml configuration
echo
echo "📝 Creating hosts.yaml configuration..."
cat > hosts.yaml << EOF
# RDP Gateway Hosts Configuration - Single Windows Host
# Generated on $(date)

hosts:
  - name: "windows-host"
    address: "$WINDOWS_IP"
    port: $RDP_PORT
    description: "Windows Host - $WINDOWS_IP"
    allowed_users:
      - "$RDP_USER"
    allowed_groups:
      - "remote-users"
    target_credentials:
      username: "$WINDOWS_USERNAME"
      # Password stored separately for security

settings:
  default_port: 3389
  connection_timeout: 30
  max_connections_per_user: 2
  log_connections: true
  require_encryption: true
  require_nla: true
  idle_timeout: 1800
  session_timeout: 14400
  enable_clipboard: true
  enable_file_transfer: true
  enable_audio: true
  enable_printing: true
  allowed_protocols:
    - "rdp"
    - "tls"
    - "nla"

host_groups:
  windows_hosts:
    - "windows-host"
EOF

# Create users.yaml configuration
echo "📝 Creating users.yaml configuration..."
cat > users.yaml << EOF
# RDP Gateway Users Configuration - Single User
# Generated on $(date)

users:
  - username: "$RDP_USER"
    password_hash: "$PASSWORD_HASH"
    full_name: "$FULL_NAME"
    email: "$USER_EMAIL"
    groups:
      - "remote-users"
    permissions:
      - "connect_assigned"
    enabled: true
    mfa_required: false
    max_concurrent_sessions: 2
    allowed_hosts:
      - "windows-host"

groups:
  remote-users:
    description: "Remote Access Users"
    permissions:
      - "connect_assigned"
      - "view_own_sessions"
    default_session_timeout: 14400

auth_settings:
  password_policy:
    min_length: 8
    require_uppercase: true
    require_lowercase: true
    require_numbers: true
    require_special_chars: false
  session_settings:
    default_timeout: 14400
    max_timeout: 28800
    idle_timeout: 1800
  mfa_settings:
    default_required: false
    remember_device_days: 30
  lockout_policy:
    max_failed_attempts: 5
    lockout_duration_minutes: 15
    reset_time_minutes: 60

audit_settings:
  log_successful_logins: true
  log_failed_logins: true
  log_session_activities: false
  retention_days: 30
EOF

# Store Windows credentials securely (optional)
echo
echo "🔑 Creating secure credentials file..."
cat > windows-credentials.txt << EOF
# Windows Host Credentials
# Keep this file secure and restrict access (chmod 600)

Host: $WINDOWS_IP:$RDP_PORT
Username: $WINDOWS_USERNAME
Password: $WINDOWS_PASSWORD

# RDP Gateway Access:
# Web Interface: https://your-rdpgw-domain.com
# Native RDP: your-rdpgw-domain.com:3391

# Connection command example:
# mstsc /v:$WINDOWS_IP /g:your-rdpgw-domain.com:3391
EOF

chmod 600 windows-credentials.txt

echo
echo "✅ Configuration completed successfully!"
echo
echo "📋 Summary:"
echo "  - Windows Host: $WINDOWS_IP:$RDP_PORT"
echo "  - Windows User: $WINDOWS_USERNAME"
echo "  - RDP Gateway User: $RDP_USER"
echo "  - Configuration files created: hosts.yaml, users.yaml"
echo "  - Credentials saved in: windows-credentials.txt (secure)"
echo
echo "🚀 Next steps:"
echo "  1. Review the generated configuration files"
echo "  2. Start the RDP Gateway services:"
echo "     docker compose -f docker-compose-rdpgw.yaml up -d"
echo "  3. Start the Cloudflare tunnel:"
echo "     docker compose -f docker-compose-cloudflare-rdpgw.yaml up -d"
echo "  4. Test the connection through your tunnel URL"
echo
echo "🔗 Connection methods:"
echo "  - Web Interface: https://your-rdpgw-domain.com"
echo "  - Native RDP Client: your-rdpgw-domain.com:3391"
echo "  - Windows RDP command: mstsc /v:$WINDOWS_IP /g:your-rdpgw-domain.com:3391"
echo 