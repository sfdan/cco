#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
	echo -e "${GREEN}▶${NC} $1"
}

warn() {
	echo -e "${YELLOW}⚠${NC} $1"
}

error() {
	echo -e "${RED}✗${NC} $1" >&2
}

info() {
	echo -e "${BLUE}ℹ${NC} $1"
}

# Configuration
GITHUB_REPO="nikvdp/ccon"
GITHUB_SSH_URL="git@github.com:${GITHUB_REPO}.git"
GITHUB_HTTPS_URL="https://github.com/${GITHUB_REPO}.git"
CCON_INSTALLATION_DIR="$HOME/.local/share/ccon"

# Determine symlink location using smart strategy
determine_symlink_location() {
	# Smart symlink strategy: use ~/bin if user already has it in PATH
	if [[ -d "$HOME/bin" && ":$PATH:" == *":$HOME/bin:"* ]]; then
		SYMLINK_DIR="$HOME/bin"
		NEEDS_SUDO=false
		log "Using existing ~/bin directory"
	else
		# Use system location, requires sudo
		SYMLINK_DIR="/usr/local/bin"
		NEEDS_SUDO=true
		log "Using /usr/local/bin (requires sudo)"
	fi

	SYMLINK_PATH="${SYMLINK_DIR}/ccon"
}

# Check prerequisites
check_prerequisites() {
	log "Checking prerequisites..."

	# Check for required tools
	local missing_tools=()

	if ! command -v git &>/dev/null; then
		missing_tools+=("git")
	fi

	if ! command -v docker &>/dev/null; then
		missing_tools+=("docker")
	fi

	if [[ ${#missing_tools[@]} -gt 0 ]]; then
		error "Missing required tools: ${missing_tools[*]}"
		error "Please install them and try again."
		exit 1
	fi

	# Check if Docker daemon is running
	if ! docker info &>/dev/null; then
		error "Docker daemon is not running"
		error "Please start Docker and try again."
		exit 1
	fi

	log "Prerequisites check passed"
}

# Clone with SSH first, fallback to HTTPS
clone_repository() {
	local target_dir="$1"

	log "Attempting to clone with SSH authentication..."
	if git clone "$GITHUB_SSH_URL" "$target_dir" 2>/dev/null; then
		log "Successfully cloned using SSH"
		return 0
	fi

	warn "SSH clone failed, falling back to HTTPS..."
	if git clone "$GITHUB_HTTPS_URL" "$target_dir"; then
		log "Successfully cloned using HTTPS"
		return 0
	fi

	error "Failed to clone repository with both SSH and HTTPS"
	return 1
}

# Clone or update ccon installation
install_or_update_ccon() {
	# Determine if we're in a ccon repo
	if [[ -f "ccon" && -f "Dockerfile" ]]; then
		log "Running from ccon development directory"
	else
		log "Running standalone installation"
	fi

	# Clone/update ccon installation
	if [[ -d "$CCON_INSTALLATION_DIR/.git" ]]; then
		log "Updating existing ccon installation..."
		cd "$CCON_INSTALLATION_DIR"

		# Check for local modifications
		if ! git diff --quiet HEAD 2>/dev/null; then
			warn "WARNING: Your ccon installation has local modifications."
			warn "Most users should reset to the latest version (this is safe)."
			warn "Only say 'no' if you've customized ccon yourself."
			echo
			read -p "Reset to latest version and lose local changes? [Y/n] " -n 1 -r
			echo
			if [[ $REPLY =~ ^[Nn]$ ]]; then
				warn "Skipping update to preserve local changes"
				cd - >/dev/null
				return 0
			fi
			log "Resetting to latest version..."
			git reset --hard origin/master
		fi

		git fetch origin
		git pull origin master
		CURRENT_VERSION=$(git rev-parse --short HEAD)
		log "Updated to $CURRENT_VERSION"
		cd - >/dev/null
	else
		log "Installing ccon to $CCON_INSTALLATION_DIR..."
		mkdir -p "$(dirname "$CCON_INSTALLATION_DIR")"

		if ! clone_repository "$CCON_INSTALLATION_DIR"; then
			error "Failed to clone ccon repository"
			error "Please check your internet connection and try again."
			exit 1
		fi

		CURRENT_VERSION=$(cd "$CCON_INSTALLATION_DIR" && git rev-parse --short HEAD)
		log "Installed ccon $CURRENT_VERSION"
	fi
}

# Create symlink
create_symlink() {
	log "Creating symlink..."

	# Create symlink with appropriate permissions
	if [[ "$NEEDS_SUDO" == "true" ]]; then
		if ! sudo ln -sf "$CCON_INSTALLATION_DIR/ccon" "$SYMLINK_PATH"; then
			error "Failed to create symlink with sudo"
			exit 1
		fi
		log "Created symlink at $SYMLINK_PATH (used sudo)"
	else
		if ! ln -sf "$CCON_INSTALLATION_DIR/ccon" "$SYMLINK_PATH"; then
			error "Failed to create symlink"
			exit 1
		fi
		log "Created symlink at $SYMLINK_PATH"
	fi
}

# Verify installation
verify_installation() {
	log "Verifying installation..."

	if [[ ! -x "$CCON_INSTALLATION_DIR/ccon" ]]; then
		error "Installation verification failed: ccon script is not executable"
		exit 1
	fi

	if [[ ! -L "$SYMLINK_PATH" ]]; then
		error "Installation verification failed: symlink was not created"
		exit 1
	fi

	# Try to run ccon --help
	if ! "$SYMLINK_PATH" --help &>/dev/null; then
		error "Installation verification failed: ccon --help failed"
		exit 1
	fi

	log "Installation verified successfully"
}

# Show usage information
show_usage() {
	info ""
	info "🎉 ccon installation complete!"
	info ""
	info "📍 Installation details:"
	info "  • Files: ${BLUE}$CCON_INSTALLATION_DIR${NC}"
	info "  • Command: ${BLUE}$SYMLINK_PATH${NC}"
	info "  • Version: ${BLUE}$CURRENT_VERSION${NC}"
	info ""
	info "📋 Next steps:"
	info "  1. Make sure Claude Code is authenticated"
	info "  2. Run ccon in any project directory: ${BLUE}ccon${NC}"
	info "  3. For help: ${BLUE}ccon --help${NC}"
	info "  4. To update: ${BLUE}ccon --self-update${NC}"
	info ""
	info "📖 Documentation: https://github.com/${GITHUB_REPO}"
	info ""
}

# Main installation function
main() {
	log "🚀 Installing ccon - a thin protective layer for Claude"
	echo

	check_prerequisites
	determine_symlink_location
	install_or_update_ccon
	create_symlink
	verify_installation
	show_usage
}

# Handle command line arguments
case "${1:-}" in
--help | -h)
	echo "ccon installer - a thin protective layer for Claude"
	echo ""
	echo "Usage: curl -fsSL https://raw.githubusercontent.com/nikvdp/ccon/master/install.sh | bash"
	echo ""
	echo "This script will:"
	echo "  • Clone ccon to ~/.local/share/ccon"
	echo "  • Create symlink in ~/bin (if in PATH) or /usr/local/bin"
	echo "  • Enable global ccon usage from any directory"
	echo ""
	echo "Options:"
	echo "  --help, -h    Show this help message"
	exit 0
	;;
*)
	main
	;;
esac
