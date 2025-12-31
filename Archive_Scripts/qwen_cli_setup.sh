#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# System detection
OS="$(uname -s)"
ARCH="$(uname -m)"

# Installation paths
INSTALL_DIR="${HOME}/.local/bin"
BINARY_NAME="qwen-coder"
FULL_PATH="${INSTALL_DIR}/${BINARY_NAME}"

# GitHub repository details
REPO="qwenlm/qwen-coder"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"

# Dependency check
check_dependencies() {
    local deps=("curl" "jq" "tar")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        err "Missing dependencies: ${missing[*]}"
        err "Please install: curl, jq, tar"
        exit 1
    fi
}

# Get latest release information
get_latest_release() {
    log "Fetching latest release info..."
    curl -sL "$API_URL" | jq -r ".tag_name, .assets[].browser_download_url" | \
    grep -E "(tag_name|linux-amd64|linux-arm64)" | \
    paste - - | \
    awk '{print $2}' | \
    sed 's/tag_name://'
}

# Determine download URL based on architecture
get_download_url() {
    local tag="$1"
    case "$ARCH" in
        x86_64) echo "https://github.com/${REPO}/releases/download/${tag}/qwen-coder-linux-amd64.tar.gz" ;;
        aarch64|arm64) echo "https://github.com/${REPO}/releases/download/${tag}/qwen-coder-linux-arm64.tar.gz" ;;
        *) err "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
}

# Download and extract binary
install_binary() {
    local url="$1"
    local temp_dir
    temp_dir=$(mktemp -d)
    
    log "Downloading from: $url"
    curl -sL "$url" | tar -xz -C "$temp_dir"
    
    mkdir -p "$INSTALL_DIR"
    mv "${temp_dir}/${BINARY_NAME}" "$FULL_PATH"
    chmod +x "$FULL_PATH"
    
    rm -rf "$temp_dir"
    log "Installed to: $FULL_PATH"
}

# Update PATH in shell profiles
update_shell_profile() {
    local profile_files=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile")
    local path_export="export PATH=\"\$PATH:${INSTALL_DIR}\""
    
    for profile in "${profile_files[@]}"; do
        if [[ -f "$profile" ]] && ! grep -q "$INSTALL_DIR" "$profile"; then
            echo "" >> "$profile"
            echo "# Added by qwen-coder installer" >> "$profile"
            echo "$path_export" >> "$profile"
            log "Updated $profile"
        fi
    done
}

# Verify installation
verify_installation() {
    if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
        warn "Installation directory not in PATH"
        echo "Add this line to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
        echo "  export PATH=\"\$PATH:${INSTALL_DIR}\""
        echo "Then restart your terminal or run: source ~/.bashrc"
    fi
    
    if command -v "$BINARY_NAME" &>/dev/null; then
        log "Installation successful!"
        "$BINARY_NAME" --version
    else
        err "Installation failed. Try running: source ~/.bashrc"
        exit 1
    fi
}

# Main execution
main() {
    log "Starting Qwen Coder CLI installation..."
    
    # Check system compatibility
    if [[ "$OS" != "Linux" ]]; then
        err "This script only supports Linux. Your OS: $OS"
        exit 1
    fi
    
    check_dependencies
    
    # Get release info
    local release_info
    release_info=$(get_latest_release)
    local tag
    tag=$(echo "$release_info" | head -n1)
    local download_url
    download_url=$(get_download_url "$tag")
    
    log "Latest version: $tag"
    
    # Install
    install_binary "$download_url"
    update_shell_profile
    verify_installation
    
    log "Installation completed! 🎉"
    echo "Run 'qwen-coder --help' to get started"
}

main "$@"
