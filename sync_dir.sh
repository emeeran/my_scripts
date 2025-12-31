#!/bin/bash

# Interactive Rsync Directory Sync Script
# Prompts for source, destination, and exclusions with robust error handling

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_error() { echo -e "${RED}ERROR: $1${NC}" >&2; }
print_success() { echo -e "${GREEN}$1${NC}"; }
print_info() { echo -e "${YELLOW}$1${NC}"; }

# Function to validate directory
validate_dir() {
    local dir="$1"
    local type="$2"
    
    # Expand tilde to home directory
    dir="${dir/#\~/$HOME}"
    
    if [[ "$type" == "source" ]]; then
        if [[ ! -d "$dir" ]]; then
            print_error "Source directory does not exist: $dir"
            return 1
        fi
        if [[ ! -r "$dir" ]]; then
            print_error "Source directory is not readable: $dir"
            return 1
        fi
    fi
    
    echo "$dir"
}

# Main script
main() {
    echo "======================================"
    echo "  Interactive Rsync Directory Sync"
    echo "======================================"
    echo
    
    # Prompt for source directory
    while true; do
        read -p "Enter source directory: " source
        source=$(validate_dir "$source" "source") && break
    done
    
    # Prompt for destination directory
    while true; do
        read -p "Enter destination directory: " destination
        destination="${destination/#\~/$HOME}"
        
        if [[ ! -d "$destination" ]]; then
            read -p "Destination does not exist. Create it? (y/n): " create
            if [[ "$create" =~ ^[Yy]$ ]]; then
                mkdir -p "$destination" || { print_error "Failed to create destination"; continue; }
                print_success "Created destination directory"
            else
                continue
            fi
        fi
        break
    done
    
    # Prompt for exclusions
    echo
    print_info "Enter exclusion patterns (one per line, empty line to finish):"
    print_info "Examples: *.log, .git, node_modules, __pycache__"
    exclusions=()
    while true; do
        read -p "> " pattern
        [[ -z "$pattern" ]] && break
        exclusions+=("$pattern")
    done
    
    # Build rsync command
    rsync_cmd="rsync -avh --progress"
    
    for pattern in "${exclusions[@]}"; do
        rsync_cmd+=" --exclude='$pattern'"
    done
    
    rsync_cmd+=" '$source/' '$destination/'"
    
    # Display summary
    echo
    echo "======================================"
    echo "Sync Summary:"
    echo "======================================"
    echo "Source:      $source"
    echo "Destination: $destination"
    echo "Exclusions:  ${exclusions[*]:-None}"
    echo
    echo "Command: $rsync_cmd"
    echo "======================================"
    echo
    
    # Confirm before proceeding
    read -p "Proceed with sync? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Sync cancelled"
        exit 0
    fi
    
    # Perform dry-run first
    echo
    print_info "Performing dry-run..."
    eval "$rsync_cmd --dry-run" || { print_error "Dry-run failed"; exit 1; }
    
    echo
    read -p "Dry-run complete. Proceed with actual sync? (y/n): " final_confirm
    if [[ ! "$final_confirm" =~ ^[Yy]$ ]]; then
        print_info "Sync cancelled"
        exit 0
    fi
    
    # Execute actual sync
    echo
    print_info "Starting sync..."
    if eval "$rsync_cmd"; then
        print_success "✓ Sync completed successfully!"
    else
        print_error "Sync failed with exit code $?"
        exit 1
    fi
}

# Check if rsync is installed
if ! command -v rsync &> /dev/null; then
    print_error "rsync is not installed. Please install it first."
    exit 1
fi

main
