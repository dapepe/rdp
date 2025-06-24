#!/bin/bash

# Guacamole Custom Branding Setup Script
# This script helps configure custom branding for Guacamole

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
BRANDING_DIR="./branding"
CSS_DIR="$BRANDING_DIR/css"
ASSETS_DIR="$BRANDING_DIR/assets"

# Create branding directories
create_branding_directories() {
    log_header "Creating Branding Directories"
    
    mkdir -p "$BRANDING_DIR"
    mkdir -p "$CSS_DIR"
    mkdir -p "$ASSETS_DIR"
    mkdir -p "$BRANDING_DIR/images"
    mkdir -p "$BRANDING_DIR/fonts"
    
    log_info "Branding directories created successfully"
}

# Setup default logo
setup_default_logo() {
    log_header "Setting up Default Logo"
    
    if [ ! -f "$BRANDING_DIR/logo.png" ]; then
        log_info "Creating placeholder logo..."
        
        # Create a simple SVG logo if ImageMagick is available
        if command -v convert &> /dev/null; then
            convert -size 200x80 xc:transparent -fill '#3498db' -gravity center \
                    -pointsize 24 -font Arial-Bold -annotate +0+0 'Your Logo' \
                    "$BRANDING_DIR/logo.png"
            log_info "Placeholder logo created at $BRANDING_DIR/logo.png"
        else
            log_warn "ImageMagick not found. Please manually add your logo as $BRANDING_DIR/logo.png"
            echo "Logo requirements:"
            echo "- Format: PNG, JPG, or SVG"
            echo "- Recommended size: 200x80 pixels"
            echo "- Transparent background recommended"
        fi
    else
        log_info "Logo already exists at $BRANDING_DIR/logo.png"
    fi
}

# Setup favicon
setup_favicon() {
    log_header "Setting up Favicon"
    
    if [ ! -f "$BRANDING_DIR/favicon.ico" ]; then
        log_info "Creating default favicon..."
        
        if command -v convert &> /dev/null && [ -f "$BRANDING_DIR/logo.png" ]; then
            convert "$BRANDING_DIR/logo.png" -resize 32x32 "$BRANDING_DIR/favicon.ico"
            log_info "Favicon created from logo"
        else
            log_warn "Please manually add your favicon as $BRANDING_DIR/favicon.ico"
            echo "Favicon requirements:"
            echo "- Format: ICO"
            echo "- Size: 32x32 pixels"
        fi
    else
        log_info "Favicon already exists"
    fi
}

# Create color theme variations
create_color_themes() {
    log_header "Creating Color Theme Variations"
    
    # Corporate Blue Theme
    cat > "$CSS_DIR/theme-corporate-blue.css" << 'EOF'
/* Corporate Blue Theme */
:root {
    --primary-color: #1e3a8a;
    --secondary-color: #3b82f6;
    --accent-color: #ef4444;
    --background-color: #f8fafc;
    --text-color: #1e293b;
    --input-border: #cbd5e1;
    --success-color: #059669;
    --warning-color: #d97706;
    --error-color: #dc2626;
}
EOF

    # Dark Theme
    cat > "$CSS_DIR/theme-dark.css" << 'EOF'
/* Dark Theme */
:root {
    --primary-color: #f1f5f9;
    --secondary-color: #3b82f6;
    --accent-color: #ef4444;
    --background-color: #0f172a;
    --text-color: #f1f5f9;
    --input-border: #475569;
    --success-color: #10b981;
    --warning-color: #f59e0b;
    --error-color: #f87171;
}

body {
    background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
}

.login-ui {
    background: #1e293b;
    border: 1px solid #334155;
}
EOF

    # Green Corporate Theme
    cat > "$CSS_DIR/theme-green.css" << 'EOF'
/* Green Corporate Theme */
:root {
    --primary-color: #065f46;
    --secondary-color: #10b981;
    --accent-color: #dc2626;
    --background-color: #f0fdf4;
    --text-color: #064e3b;
    --input-border: #a7f3d0;
    --success-color: #059669;
    --warning-color: #d97706;
    --error-color: #dc2626;
}
EOF

    log_info "Color theme variations created"
}

# Setup custom CSS
setup_custom_css() {
    log_header "Setting up Custom CSS"
    
    if [ ! -f "$CSS_DIR/custom.css" ]; then
        log_info "Custom CSS already exists, keeping existing configuration"
    else
        log_info "Custom CSS template is already available"
    fi
    
    create_color_themes
    
    echo
    echo "Available CSS themes:"
    echo "- custom.css (default custom theme)"
    echo "- theme-corporate-blue.css"
    echo "- theme-dark.css"
    echo "- theme-green.css"
    echo
    echo "To use a theme, update your .env file:"
    echo "CUSTOM_THEME=theme-corporate-blue"
}

# Configure branding properties
configure_branding_properties() {
    log_header "Configuring Branding Properties"
    
    # Get organization information
    echo
    read -p "Enter your organization name [Your Organization]: " org_name
    org_name=${org_name:-"Your Organization"}
    
    read -p "Enter support email [support@yourorganization.com]: " support_email
    support_email=${support_email:-"support@yourorganization.com"}
    
    read -p "Enter custom login message [Welcome to Your Secure Remote Access Portal]: " login_message
    login_message=${login_message:-"Welcome to Your Secure Remote Access Portal"}
    
    read -p "Enter security banner message (optional): " security_banner
    
    # Update .env file
    if [ -f ".env" ]; then
        # Update or add branding configuration
        if grep -q "ORGANIZATION_NAME=" .env; then
            sed -i.bak "s/ORGANIZATION_NAME=.*/ORGANIZATION_NAME=$org_name/" .env
        else
            echo "ORGANIZATION_NAME=$org_name" >> .env
        fi
        
        if grep -q "SUPPORT_EMAIL=" .env; then
            sed -i.bak "s/SUPPORT_EMAIL=.*/SUPPORT_EMAIL=$support_email/" .env
        else
            echo "SUPPORT_EMAIL=$support_email" >> .env
        fi
        
        if grep -q "LOGIN_MESSAGE=" .env; then
            sed -i.bak "s/LOGIN_MESSAGE=.*/LOGIN_MESSAGE=$login_message/" .env
        else
            echo "LOGIN_MESSAGE=$login_message" >> .env
        fi
        
        if [ -n "$security_banner" ]; then
            if grep -q "SECURITY_BANNER=" .env; then
                sed -i.bak "s/SECURITY_BANNER=.*/SECURITY_BANNER=$security_banner/" .env
            else
                echo "SECURITY_BANNER=$security_banner" >> .env
            fi
        fi
        
        log_info "Branding configuration updated in .env file"
    else
        log_warn ".env file not found. Please create it first."
    fi
}

# Create sample background images
create_sample_backgrounds() {
    log_header "Creating Sample Background Images"
    
    if command -v convert &> /dev/null; then
        # Create a subtle pattern background
        convert -size 1920x1080 gradient:'#f8fafc-#e2e8f0' \
                -wave 2x60 "$BRANDING_DIR/background-gradient.jpg"
        
        # Create a geometric pattern
        convert -size 1920x1080 pattern:hexagons -fill '#3b82f6' -opaque black \
                -fill '#f8fafc' -opaque white "$BRANDING_DIR/background-pattern.jpg"
        
        log_info "Sample background images created"
    else
        log_warn "ImageMagick not available. Sample backgrounds not created."
    fi
}

# Test branding configuration
test_branding_config() {
    log_header "Testing Branding Configuration"
    
    # Check required files
    files_to_check=(
        "$BRANDING_DIR/logo.png"
        "$CSS_DIR/custom.css"
        "$BRANDING_DIR/guacamole.properties"
    )
    
    for file in "${files_to_check[@]}"; do
        if [ -f "$file" ]; then
            log_info "✓ $file exists"
        else
            log_warn "⚠ $file not found"
        fi
    done
    
    # Check image dimensions
    if command -v identify &> /dev/null && [ -f "$BRANDING_DIR/logo.png" ]; then
        dimensions=$(identify -format "%wx%h" "$BRANDING_DIR/logo.png")
        log_info "Logo dimensions: $dimensions"
        
        # Warn if logo is too large
        width=$(echo $dimensions | cut -d'x' -f1)
        if [ "$width" -gt 300 ]; then
            log_warn "Logo width ($width px) is quite large. Consider resizing for better performance."
        fi
    fi
}

# Display branding information
display_branding_info() {
    log_header "Custom Branding Setup Complete"
    
    echo
    echo "=========================================="
    echo "Guacamole Custom Branding Configuration"
    echo "=========================================="
    echo
    echo "Branding files location: $BRANDING_DIR"
    echo "Custom CSS location: $CSS_DIR"
    echo
    echo "Customization Options:"
    echo "1. Logo: Replace $BRANDING_DIR/logo.png with your logo"
    echo "2. Favicon: Replace $BRANDING_DIR/favicon.ico with your favicon"
    echo "3. CSS Theme: Edit $CSS_DIR/custom.css or use predefined themes"
    echo "4. Background: Add background images to $BRANDING_DIR/"
    echo "5. Properties: Edit $BRANDING_DIR/guacamole.properties"
    echo
    echo "Environment Variables (.env):"
    echo "- CUSTOM_LOGO_PATH: Path to your logo file"
    echo "- CUSTOM_THEME: CSS theme to use (custom, theme-dark, etc.)"
    echo "- LOGIN_MESSAGE: Custom welcome message"
    echo "- ORGANIZATION_NAME: Your organization name"
    echo "- SUPPORT_EMAIL: Support contact email"
    echo
    echo "Available CSS Themes:"
    echo "- custom (default)"
    echo "- theme-corporate-blue"
    echo "- theme-dark"
    echo "- theme-green"
    echo
    echo "After making changes:"
    echo "1. Restart Guacamole containers"
    echo "2. Clear browser cache"
    echo "3. Test the new branding"
    echo
    echo "Advanced Customization:"
    echo "- Add custom fonts to $BRANDING_DIR/fonts/"
    echo "- Add additional images to $BRANDING_DIR/images/"
    echo "- Create custom CSS animations and effects"
    echo "- Override Guacamole's default styles"
    echo "=========================================="
}

# Main execution
main() {
    echo "=========================================="
    log_header "Guacamole Custom Branding Setup"
    echo "=========================================="
    echo
    
    create_branding_directories
    setup_default_logo
    setup_favicon
    setup_custom_css
    create_sample_backgrounds
    configure_branding_properties
    test_branding_config
    display_branding_info
}

# Run main function
main "$@" 