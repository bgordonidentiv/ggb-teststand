#!/bin/bash

###############################################################################
# GGB Teststand Setup Script
# 
# This script automates the setup of the GGB teststand environment including:
# - Prerequisites verification
# - STM32 Cube Programmer download and setup
# - Hardware detection
# - Power supply auto-configuration
# - Docker image building
# - Environment configuration
#
# Usage: ./setup.sh [OPTIONS]
# Options:
#   --skip-download    Skip STM32 Programmer download
#   --skip-build       Skip Docker image building
#   --check-only       Only check prerequisites and hardware
#   --help             Show this help message
###############################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/setup.log"
STM32_PROGRAMMER_VERSION="2-18-0"
STM32_PROGRAMMER_DIR="stm32_flash_cli/en.stm32cubeprg-lin-${STM32_PROGRAMMER_VERSION}"
STM32_PROGRAMMER_URL="https://www.st.com/content/st_com/en/products/development-tools/software-development-tools/stm32-software-development-tools/stm32-programmers/stm32cubeprog.html"
HARDWARE_CONFIG_FILE="$SCRIPT_DIR/hardware_config.json"
BACKUP_DIR="$SCRIPT_DIR/.setup_backups"

# Flags
SKIP_DOWNLOAD=false
SKIP_BUILD=false
CHECK_ONLY=false

###############################################################################
# Helper Functions
###############################################################################

log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

log_success() {
    log "${GREEN}✓ $1${NC}"
}

log_error() {
    log "${RED}✗ $1${NC}"
}

log_warning() {
    log "${YELLOW}⚠ $1${NC}"
}

log_info() {
    log "${BLUE}ℹ $1${NC}"
}

print_header() {
    log ""
    log "═══════════════════════════════════════════════════════════════"
    log "  $1"
    log "═══════════════════════════════════════════════════════════════"
}

show_help() {
    cat << EOF
GGB Teststand Setup Script

Usage: ./setup.sh [OPTIONS]

Options:
  --skip-download    Skip STM32 Programmer download
  --skip-build       Skip Docker image building
  --check-only       Only check prerequisites and hardware
  --help             Show this help message

Examples:
  ./setup.sh                    # Full setup
  ./setup.sh --check-only       # Check system only
  ./setup.sh --skip-download    # Skip programmer download

EOF
    exit 0
}

###############################################################################
# Parse Arguments
###############################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-download)
                SKIP_DOWNLOAD=true
                shift
                ;;
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --check-only)
                CHECK_ONLY=true
                shift
                ;;
            --help)
                show_help
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                ;;
        esac
    done
}

###############################################################################
# Prerequisites Check
###############################################################################

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local all_ok=true
    
    # Check Docker
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
        log_success "Docker found: $docker_version"
    else
        log_error "Docker not found. Please install Docker Engine 20.10+"
        all_ok=false
    fi
    
    # Check Docker Compose
    if docker compose version &> /dev/null; then
        local compose_version=$(docker compose version | awk '{print $4}' | tr -d 'v')
        log_success "Docker Compose found: $compose_version"
    elif command -v docker-compose &> /dev/null; then
        local compose_version=$(docker-compose --version | awk '{print $3}' | tr -d ',')
        log_success "Docker Compose found: $compose_version"
    else
        log_error "Docker Compose not found. Please install Docker Compose"
        all_ok=false
    fi
    
    # Check Git
    if command -v git &> /dev/null; then
        log_success "Git found: $(git --version | awk '{print $3}')"
    else
        log_warning "Git not found (optional for cloning)"
    fi
    
    # Check Python3
    if command -v python3 &> /dev/null; then
        log_success "Python3 found: $(python3 --version | awk '{print $2}')"
    else
        log_warning "Python3 not found (needed for power supply detection)"
    fi
    
    # Check npm
    if command -v npm &> /dev/null; then
        log_success "npm found: $(npm --version)"
    else
        log_error "npm not found. Please install Node.js and npm"
        all_ok=false
    fi
    
    # Check disk space
    local available_space=$(df -BG "$SCRIPT_DIR" | awk 'NR==2 {print $4}' | tr -d 'G')
    if [ "$available_space" -ge 10 ]; then
        log_success "Disk space available: ${available_space}GB"
    else
        log_warning "Low disk space: ${available_space}GB (10GB+ recommended)"
    fi
    
    # Check USB device access (Linux only)
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if groups | grep -q dialout; then
            log_success "User in dialout group (USB access enabled)"
        else
            log_warning "User not in dialout group. Run: sudo usermod -aG dialout \$USER"
            log_warning "Then logout and login for changes to take effect"
        fi
    fi
    
    if [ "$all_ok" = false ]; then
        log_error "Prerequisites check failed. Please install missing components."
        exit 1
    fi
    
    log_success "All prerequisites satisfied"
}

###############################################################################
# Hardware Detection
###############################################################################

detect_hardware() {
    print_header "Detecting Hardware"
    
    local hw_json="{"
    
    # Check if lsusb is available
    if command -v lsusb &> /dev/null; then
        log_info "USB Devices:"
        lsusb | tee -a "$LOG_FILE"
        
        # Detect ST-Link
        if lsusb | grep -iq "stm\|st-link"; then
            log_success "ST-Link programmer detected"
            hw_json+='"st_link": true,'
        else
            log_warning "ST-Link programmer not detected"
            hw_json+='"st_link": false,'
        fi
        
        # Detect FTDI devices
        local ftdi_count=$(lsusb | grep -ic "ftdi" || true)
        if [ "$ftdi_count" -ge 3 ]; then
            log_success "FTDI devices detected: $ftdi_count (3+ required)"
            hw_json+='"ftdi_count": '$ftdi_count','
        else
            log_warning "FTDI devices found: $ftdi_count (3 required for full functionality)"
            hw_json+='"ftdi_count": '$ftdi_count','
        fi
        
        # Detect Siglent Power Supply
        if lsusb | grep -iq "siglent\|0x0483:0x7540"; then
            log_success "Siglent power supply detected"
            hw_json+='"siglent_ps": true,'
        else
            log_warning "Siglent power supply not detected"
            hw_json+='"siglent_ps": false,'
        fi
    else
        log_warning "lsusb not available (install usbutils for USB device detection)"
    fi
    
    # Check serial ports
    log_info "Serial Ports:"
    hw_json+='"serial_ports": ['
    
    local serial_ports=()
    for port in /dev/ttyUSB* /dev/ttyACM*; do
        if [ -e "$port" ]; then
            log "  - $port"
            serial_ports+=("\"$port\"")
        fi
    done 2>/dev/null
    
    if [ ${#serial_ports[@]} -ge 4 ]; then
        log_success "Serial ports found: ${#serial_ports[@]} (4 required)"
    else
        log_warning "Serial ports found: ${#serial_ports[@]} (4 required: ttyUSB0-2, ttyACM0)"
    fi
    
    hw_json+=$(IFS=,; echo "${serial_ports[*]}")
    hw_json+='],'
    
    # Check stable serial device IDs
    if [ -d "/dev/serial/by-id" ]; then
        log_info "Stable device IDs:"
        ls -l /dev/serial/by-id/ | grep -v total | tee -a "$LOG_FILE"
    fi
    
    # Detect network devices (for LabJack)
    log_info "Checking network connectivity to LabJack T7 (192.168.8.148)..."
    if ping -c 1 -W 2 192.168.8.148 &> /dev/null; then
        log_success "LabJack T7 reachable at 192.168.8.148"
        hw_json+='"labjack_reachable": true'
    else
        log_warning "LabJack T7 not reachable at 192.168.8.148"
        hw_json+='"labjack_reachable": false'
    fi
    
    hw_json+="}"
    
    # Save hardware config
    echo "$hw_json" | python3 -m json.tool > "$HARDWARE_CONFIG_FILE" 2>/dev/null || echo "$hw_json" > "$HARDWARE_CONFIG_FILE"
    log_success "Hardware configuration saved to: $HARDWARE_CONFIG_FILE"
}

###############################################################################
# Power Supply Configuration
###############################################################################

configure_power_supply() {
    print_header "Configuring Power Supply"
    
    # Check if Python and PyVISA are available
    if ! command -v python3 &> /dev/null; then
        log_warning "Python3 not available, skipping power supply auto-configuration"
        return
    fi
    
    # Try to detect VISA resources
    log_info "Detecting VISA resources..."
    
    local visa_script='
import sys
try:
    import pyvisa
    rm = pyvisa.ResourceManager()
    resources = rm.list_resources()
    if resources:
        for res in resources:
            print(res)
    else:
        print("NONE")
except ImportError:
    print("PYVISA_NOT_INSTALLED")
except Exception as e:
    print(f"ERROR: {e}")
'
    
    local visa_result=$(python3 -c "$visa_script" 2>&1)
    
    if [[ "$visa_result" == "PYVISA_NOT_INSTALLED" ]]; then
        log_warning "PyVISA not installed. Install with: pip3 install pyvisa pyvisa-py"
        log_info "Skipping automatic power supply configuration"
        return
    elif [[ "$visa_result" == "NONE" ]] || [[ "$visa_result" == "ERROR"* ]]; then
        log_warning "No VISA devices detected: $visa_result"
        log_info "Ensure Siglent power supply is connected and powered on"
        return
    fi
    
    log_info "VISA resources found:"
    echo "$visa_result" | while read -r line; do
        log "  - $line"
    done
    
    # Find Siglent device
    local siglent_resource=$(echo "$visa_result" | grep -i "0x0483:0x7540" | head -1)
    
    if [ -z "$siglent_resource" ]; then
        log_warning "Siglent power supply not found in VISA resources"
        return
    fi
    
    log_success "Siglent power supply found: $siglent_resource"
    
    # Check if it differs from default
    local default_resource="USB0::0x0483::0x7540::SPD3ECAC3R0303::INSTR"
    
    if [ "$siglent_resource" = "$default_resource" ]; then
        log_success "Power supply uses default VISA address, no changes needed"
        return
    fi
    
    log_warning "Power supply VISA address differs from default:"
    log "  Default: $default_resource"
    log "  Detected: $siglent_resource"
    
    # Ask user if they want to update
    read -p "Update stm32_flash_api/app.py with detected address? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Skipping power supply configuration update"
        return
    fi
    
    # Backup original file
    mkdir -p "$BACKUP_DIR"
    local app_py_path="$SCRIPT_DIR/stm32_flash_api/app.py"
    local backup_path="$BACKUP_DIR/app.py.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [ -f "$app_py_path" ]; then
        cp "$app_py_path" "$backup_path"
        log_success "Backup created: $backup_path"
        
        # Replace all occurrences
        sed -i.tmp "s|$default_resource|$siglent_resource|g" "$app_py_path"
        rm -f "$app_py_path.tmp"
        
        log_success "Updated power supply VISA address in app.py"
    else
        log_error "File not found: $app_py_path"
    fi
}

###############################################################################
# STM32 Cube Programmer Download
###############################################################################

download_stm32_programmer() {
    print_header "STM32 Cube Programmer Setup"
    
    local programmer_path="$SCRIPT_DIR/$STM32_PROGRAMMER_DIR"
    
    # Check if already exists
    if [ -d "$programmer_path" ]; then
        log_success "STM32 Cube Programmer installer found at: $programmer_path"
        return
    fi
    
    log_warning "STM32 Cube Programmer installer not found"
    
    if [ "$SKIP_DOWNLOAD" = true ]; then
        log_warning "Skipping download (--skip-download flag set)"
        log_info "Please manually download from: $STM32_PROGRAMMER_URL"
        log_info "Extract to: $programmer_path"
        return
    fi
    
    log_info "STM32 Cube Programmer must be manually downloaded from ST.com"
    log_info "This requires accepting ST's license agreement."
    log ""
    log_info "Download URL: $STM32_PROGRAMMER_URL"
    log_info "Required file: en.stm32cubeprg-lin-v${STM32_PROGRAMMER_VERSION}.zip"
    log ""
    
    read -p "Have you already downloaded the installer? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter path to downloaded zip file: " zip_path
        
        if [ ! -f "$zip_path" ]; then
            log_error "File not found: $zip_path"
            return
        fi
        
        log_info "Extracting installer..."
        unzip -q "$zip_path" -d "$SCRIPT_DIR/stm32_flash_cli/"
        
        if [ -d "$programmer_path" ]; then
            log_success "STM32 Cube Programmer extracted successfully"
        else
            log_error "Extraction failed or unexpected directory structure"
        fi
    else
        log_info "Please download the installer and re-run this script"
        log_info "Or use --skip-download flag and extract manually to:"
        log_info "  $programmer_path"
    fi
}

###############################################################################
# Docker Build
###############################################################################

build_docker_images() {
    print_header "Building Docker Images"
    
    if [ "$SKIP_BUILD" = true ]; then
        log_warning "Skipping Docker build (--skip-build flag set)"
        return
    fi
    
    # Check if images already exist
    if docker images | grep -q "stm32_flash_api.*2.2"; then
        log_info "Docker image stm32_flash_api:2.2 already exists"
        read -p "Rebuild images? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping Docker build"
            return
        fi
    fi
    
    # Build base CLI image
    log_info "Building stm32_flash_cli:0.1 base image..."
    cd "$SCRIPT_DIR/stm32_flash_cli"
    
    if ! docker build -t stm32_flash_cli:0.1 .; then
        log_error "Failed to build stm32_flash_cli:0.1"
        exit 1
    fi
    
    log_success "Built stm32_flash_cli:0.1"
    
    # Check if committed image exists
    if docker images | grep -q "stm32_flash_cli.*1.1"; then
        log_success "Committed image stm32_flash_cli:1.1 already exists"
    else
        log ""
        log_warning "STM32 Cube Programmer must be installed manually inside container"
        log_info "Steps:"
        log "  1. Start container: docker run -it stm32_flash_cli:0.1"
        log "  2. Inside container: cd /home/ubuntu/en.stm32cubeprg-lin-v2-18-0"
        log "  3. Run installer: ./SetupSTM32CubeProgrammer-2.18.0.linux"
        log "  4. Accept all defaults"
        log "  5. DO NOT EXIT the container yet!"
        log "  6. In NEW terminal, find container ID: docker ps"
        log "  7. Commit container: docker commit <CONTAINER_ID> stm32_flash_cli:1.1"
        log "  8. Now you can exit the container"
        log ""
        
        read -p "Press Enter when you have completed these steps and created stm32_flash_cli:1.1..."
        
        # Verify committed image exists
        if ! docker images | grep -q "stm32_flash_cli.*1.1"; then
            log_error "Image stm32_flash_cli:1.1 not found"
            log_error "Please complete the manual installation steps above"
            exit 1
        fi
        
        log_success "Verified stm32_flash_cli:1.1 exists"
    fi
    
    # Build API image
    log_info "Building stm32_flash_api:2.2 image..."
    cd "$SCRIPT_DIR/stm32_flash_api"
    
    if ! docker build -t stm32_flash_api:2.2 .; then
        log_error "Failed to build stm32_flash_api:2.2"
        exit 1
    fi
    
    log_success "Built stm32_flash_api:2.2"
    cd "$SCRIPT_DIR"
}

###############################################################################
# Node-RED Dependencies
###############################################################################

install_node_red_deps() {
    print_header "Installing Node-RED Dependencies"
    
    local node_red_path="$SCRIPT_DIR/node-red-data"
    
    if [ ! -f "$node_red_path/package.json" ]; then
        log_error "package.json not found in $node_red_path"
        return
    fi
    
    cd "$node_red_path"
    
    if [ -d "node_modules" ]; then
        log_info "node_modules directory exists"
        read -p "Reinstall dependencies? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping npm install"
            cd "$SCRIPT_DIR"
            return
        fi
    fi
    
    log_info "Running npm install..."
    if npm install; then
        log_success "Node-RED dependencies installed successfully"
    else
        log_error "npm install failed"
        cd "$SCRIPT_DIR"
        exit 1
    fi
    
    cd "$SCRIPT_DIR"
}

###############################################################################
# Generate Configuration Files
###############################################################################

generate_config_files() {
    print_header "Generating Configuration Files"
    
    # Create .env.example if it doesn't exist
    if [ ! -f "$SCRIPT_DIR/.env.example" ]; then
        log_info "Creating .env.example..."
        # This will be created by a separate script
        log_warning ".env.example will be created separately"
    fi
    
    # Create udev rules reference
    local udev_ref="$SCRIPT_DIR/udev_rules_reference.txt"
    cat > "$udev_ref" << 'EOF'
# GGB Teststand - UDEV Rules Reference
# 
# These udev rules can be used to create stable device names for serial ports.
# Currently the system uses numbered devices (/dev/ttyUSB0-2), but you can
# use these rules for more reliable device naming.
#
# Installation (Linux only):
#   1. Copy relevant rules to /etc/udev/rules.d/99-ggb-teststand.rules
#   2. Run: sudo udevadm control --reload-rules
#   3. Run: sudo udevadm trigger
#   4. Reconnect USB devices
#   5. Update node-red-data/flows.json with new device paths

# Example: FTDI devices by serial number
# Replace SERIAL_NUMBER with your actual FTDI serial numbers
# Find with: udevadm info -a -n /dev/ttyUSB0 | grep serial

# Debug serial (ttyUSB0)
SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="SERIAL_NUMBER_1", SYMLINK+="ttyUSB_DEBUG"

# Reader1 RS485 (ttyUSB1)
SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="SERIAL_NUMBER_2", SYMLINK+="ttyUSB_READER1"

# Reader2 RS485 (ttyUSB2)
SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="SERIAL_NUMBER_3", SYMLINK+="ttyUSB_READER2"

# ESP32 (ttyACM0) - may vary by device
SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", SYMLINK+="ttyUSB_ESP32"

# ST-Link permissions
SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374b", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3748", MODE="0666", GROUP="plugdev"

EOF
    log_success "Created udev rules reference: $udev_ref"
}

###############################################################################
# Verification
###############################################################################

verify_installation() {
    print_header "Verifying Installation"
    
    local all_ok=true
    
    # Check Docker images
    log_info "Checking Docker images..."
    if docker images | grep -q "stm32_flash_api.*2.2"; then
        log_success "stm32_flash_api:2.2 found"
    else
        log_error "stm32_flash_api:2.2 not found"
        all_ok=false
    fi
    
    # Check Node-RED dependencies
    if [ -d "$SCRIPT_DIR/node-red-data/node_modules" ]; then
        log_success "Node-RED dependencies installed"
    else
        log_error "Node-RED dependencies not found"
        all_ok=false
    fi
    
    # Check hardware config
    if [ -f "$HARDWARE_CONFIG_FILE" ]; then
        log_success "Hardware configuration file created"
    fi
    
    if [ "$all_ok" = true ]; then
        log_success "Installation verification complete"
    else
        log_warning "Some components may need attention"
    fi
}

###############################################################################
# Generate Report
###############################################################################

generate_report() {
    print_header "Setup Summary"
    
    log ""
    log "Setup completed successfully!"
    log ""
    log "Next Steps:"
    log "  1. Review hardware configuration: cat $HARDWARE_CONFIG_FILE"
    log "  2. Start services: docker compose -f docker_compose.yml up"
    log "  3. Access Node-RED: http://localhost:1880"
    log "  4. Access STM32 Flash API: http://localhost:5000"
    log "  5. Access Filebrowser: http://localhost:8080"
    log ""
    log "Documentation:"
    log "  - Main README: README.md"
    log "  - Hardware Setup: docs/HARDWARE_SETUP.md"
    log "  - Troubleshooting: docs/TROUBLESHOOTING.md"
    log ""
    log "Configuration Files:"
    log "  - Hardware Config: $HARDWARE_CONFIG_FILE"
    log "  - Setup Log: $LOG_FILE"
    log "  - UDEV Rules Reference: udev_rules_reference.txt"
    
    if [ -d "$BACKUP_DIR" ]; then
        log "  - Backups: $BACKUP_DIR"
    fi
    
    log ""
    log_success "Setup script completed. Review $LOG_FILE for details."
}

###############################################################################
# Main
###############################################################################

main() {
    # Initialize log
    echo "GGB Teststand Setup - $(date)" > "$LOG_FILE"
    echo "======================================" >> "$LOG_FILE"
    
    print_header "GGB Teststand Setup Script"
    log "Started: $(date)"
    log "Log file: $LOG_FILE"
    
    parse_arguments "$@"
    
    check_prerequisites
    detect_hardware
    
    if [ "$CHECK_ONLY" = true ]; then
        log_info "Check-only mode, exiting"
        exit 0
    fi
    
    download_stm32_programmer
    configure_power_supply
    build_docker_images
    install_node_red_deps
    generate_config_files
    verify_installation
    generate_report
    
    log ""
    log "Completed: $(date)"
}

# Run main function
main "$@"
