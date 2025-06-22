#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[claudito-installer]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[claudito-installer]${NC} $1"
}

error() {
    echo -e "${RED}[claudito-installer]${NC} $1" >&2
}

info() {
    echo -e "${BLUE}[claudito-installer]${NC} $1"
}

# Configuration
GITHUB_REPO="nikvdp/claudito"
GITHUB_RAW_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/master"
INSTALL_DIR="/usr/local/bin"
INSTALL_PATH="${INSTALL_DIR}/claudito"

# Check permissions and determine best install location
check_permissions() {
    # Prefer $HOME/bin if it's in PATH (common convention)
    if [[ ":$PATH:" == *":$HOME/bin:"* ]] && [[ -d "$HOME/bin" || -w "$HOME" ]]; then
        INSTALL_DIR="$HOME/bin"
        INSTALL_PATH="${INSTALL_DIR}/claudito"
        
        if [[ ! -d "$INSTALL_DIR" ]]; then
            log "Creating $HOME/bin directory"
            mkdir -p "$INSTALL_DIR"
        fi
        
        log "Installing claudito to ${INSTALL_PATH} (user bin)"
        return 0
    fi
    
    # Check if running as root for system install
    if [[ $EUID -eq 0 ]]; then
        log "Installing claudito system-wide to ${INSTALL_PATH}"
        return 0
    fi
    
    # Check if we can write to /usr/local/bin
    if [[ -w "$INSTALL_DIR" ]]; then
        log "Installing claudito to ${INSTALL_PATH}"
        return 0
    fi
    
    # Fallback to ~/.local/bin
    INSTALL_DIR="$HOME/.local/bin"
    INSTALL_PATH="${INSTALL_DIR}/claudito"
    
    if [[ ! -d "$INSTALL_DIR" ]]; then
        log "Creating local bin directory: ${INSTALL_DIR}"
        mkdir -p "$INSTALL_DIR"
    fi
    
    warn "Installing claudito to ${INSTALL_PATH} (user local)"
    warn "Make sure ${INSTALL_DIR} is in your PATH"
    
    return 0
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check for required tools
    local missing_tools=()
    
    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing_tools[*]}"
        error "Please install them and try again."
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running"
        error "Please start Docker and try again."
        exit 1
    fi
    
    log "Prerequisites check passed"
}

# Download and install claudito
install_claudito() {
    log "Downloading claudito from ${GITHUB_RAW_URL}/claudito..."
    
    # Download claudito script
    if ! curl -fsSL "${GITHUB_RAW_URL}/claudito" -o "${INSTALL_PATH}.tmp"; then
        error "Failed to download claudito script"
        error "Please check your internet connection and try again."
        exit 1
    fi
    
    # Make executable
    chmod +x "${INSTALL_PATH}.tmp"
    
    # Move to final location
    mv "${INSTALL_PATH}.tmp" "${INSTALL_PATH}"
    
    log "claudito installed successfully to ${INSTALL_PATH}"
}

# Verify installation
verify_installation() {
    log "Verifying installation..."
    
    if [[ ! -x "$INSTALL_PATH" ]]; then
        error "Installation verification failed: ${INSTALL_PATH} is not executable"
        exit 1
    fi
    
    # Try to run claudito --help
    if ! "$INSTALL_PATH" --help &> /dev/null; then
        error "Installation verification failed: claudito --help failed"
        exit 1
    fi
    
    log "Installation verified successfully"
}

# Show usage information
show_usage() {
    info ""
    info "🎉 Claudito installation complete!"
    info ""
    info "📋 Next steps:"
    info "  1. Make sure Claude Code is authenticated: ${BLUE}claude${NC}"
    info "  2. Run claudito in any project directory: ${BLUE}claudito${NC}"
    info "  3. For help: ${BLUE}claudito --help${NC}"
    info ""
    info "📖 Documentation: https://github.com/${GITHUB_REPO}"
    info ""
    
    # Check if install dir is in PATH
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]] && [[ "$INSTALL_DIR" != "/usr/local/bin" ]] && [[ "$INSTALL_DIR" != "$HOME/bin" ]]; then
        warn "⚠️  ${INSTALL_DIR} is not in your PATH"
        warn "   Add this to your shell profile (.bashrc, .zshrc, etc.):"
        warn "   ${BLUE}export PATH=\"\$PATH:${INSTALL_DIR}\"${NC}"
    fi
}

# Main installation function
main() {
    info "🚀 Installing claudito - Secure Claude Code Container"
    info ""
    
    check_prerequisites
    check_permissions
    install_claudito
    verify_installation
    show_usage
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "claudito installer"
        echo ""
        echo "Usage: curl -fsSL https://raw.githubusercontent.com/nikvdp/claudito/master/install.sh | bash"
        echo ""
        echo "This script will install claudito to /usr/local/bin (if writable) or ~/.local/bin"
        echo ""
        echo "Options:"
        echo "  --help, -h    Show this help message"
        exit 0
        ;;
    *)
        main
        ;;
esac