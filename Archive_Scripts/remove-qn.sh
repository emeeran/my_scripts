#!/bin/bash

# Qwen 3 CLI Removal Script
# This script removes all components installed by the Qwen 3 setup script

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}STATUS:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

print_status "Starting Qwen 3 CLI removal process..."

# 1. Remove virtual environment
VENV_DIR="$HOME/qwen3-env"
if [ -d "$VENV_DIR" ]; then
    print_status "Removing virtual environment: $VENV_DIR"
    rm -rf "$VENV_DIR"
else
    print_warning "Virtual environment not found: $VENV_DIR"
fi

# 2. Remove configuration files
CONFIG_DIR="$HOME/.config/qwen"
if [ -d "$CONFIG_DIR" ]; then
    print_status "Removing configuration directory: $CONFIG_DIR"
    rm -rf "$CONFIG_DIR"
else
    print_warning "Configuration directory not found: $CONFIG_DIR"
fi

# 3. Remove demo/example files
DEMO_FILES=(
    "$HOME/qwen-demo.sh"
    "$HOME/qwen3-examples.txt"
)

for file in "${DEMO_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_status "Removing demo file: $file"
        rm -f "$file"
    else
        print_warning "Demo file not found: $file"
    fi
done

# 4. Remove alias from shell profiles
print_status "Removing Qwen CLI alias from shell profiles..."

ALIAS_PATTERN="alias qwen="
PROFILE_FILES=(
    "$HOME/.bashrc"
    "$HOME/.zshrc"
    "$HOME/.profile"
)

for profile in "${PROFILE_FILES[@]}"; do
    if [ -f "$profile" ]; then
        if grep -q "$ALIAS_PATTERN" "$profile"; then
            print_status "Removing alias from $profile"
            # Create backup
            cp "$profile" "$profile.qwen_backup"
            # Remove the alias lines
            sed -i '/# Qwen CLI alias/d' "$profile"
            sed -i '/alias qwen=/d' "$profile"
        else
            print_warning "No Qwen alias found in $profile"
        fi
    fi
done

# 5. Remove global command if installed
GLOBAL_COMMANDS=(
    "/usr/local/bin/qwen"
    "$HOME/qwen"
)

for cmd in "${GLOBAL_COMMANDS[@]}"; do
    if [ -f "$cmd" ]; then
        print_status "Removing global command: $cmd"
        sudo rm -f "$cmd"
    fi
done

# 6. Remove cached models (optional - uncomment if you want to remove models)
# print_status "Removing cached models..."
# rm -rf "$HOME/.cache/huggingface"
# rm -rf "$HOME/.cache/modelscope"

print_status "Checking for remaining Qwen-related files..."

# Check for any remaining Qwen files
REMAINING_FILES=$(find "$HOME" -name "*qwen*" -type f 2>/dev/null | head -10)
if [ -n "$REMAINING_FILES" ]; then
    echo "Found potential remaining Qwen files:"
    echo "$REMAINING_FILES"
    echo "Please review and remove manually if needed."
fi

# 7. Final instructions
echo ""
print_status "REMOVAL COMPLETE!"
echo ""
echo "To finalize the removal:"
echo "1. Reload your shell or restart your terminal"
echo "2. Or run: source ~/.bashrc (or ~/.zshrc)"
echo ""
echo "Backups of modified shell profiles (if any):"
find "$HOME" -name "*.qwen_backup" 2>/dev/null || echo "No backups found"

# Optional: Remove backups
echo ""
read -p "Do you want to remove backup files? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    find "$HOME" -name "*.qwen_backup" -exec rm -f {} \;
    print_status "Backup files removed"
fi

print_status "Qwen 3 CLI has been successfully removed from your system!"
