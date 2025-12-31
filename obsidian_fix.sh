#!/bin/bash

echo "Starting Obsidian and Keyboard fix for Ubuntu 24.04 (AMD)..."

# 1. Fix the Obsidian Desktop Shortcut (to use Wayland and No-Sandbox)
# This looks for Obsidian in the most common installation locations
DESKTOP_FILES=$(find ~/.local/share/applications /usr/share/applications -name "obsidian*.desktop")

if [ -z "$DESKTOP_FILES" ]; then
    echo "(!) Could not find Obsidian .desktop file. If using Snap/Flatpak, flags may need manual entry."
else
    for FILE in $DESKTOP_FILES; do
        echo "Updating shortcut: $FILE"
        sudo sed -i 's|Exec=.*|Exec=obsidian --no-sandbox --enable-features=UseOzonePlatform --ozone-platform=wayland %u|' "$FILE"
    done
fi

# 2. Fix the Dell/AMD Keyboard Sleep Bug (i8042 controller)
# This prevents the keyboard from "dropping" focus or failing after suspend
echo "Applying Kernel fix for Dell Inspiron keyboard controller..."
GRUB_FILE="/etc/default/grub"
if grep -q "i8042.nopnp" "$GRUB_FILE"; then
    echo "Kernel fix already present."
else
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="i8042.nopnp /' "$GRUB_FILE"
    echo "Updating GRUB bootloader..."
    sudo update-grub
fi

echo "--------------------------------------------------------"
echo "Done! Please REBOOT your computer for changes to take effect."
echo "--------------------------------------------------------"
