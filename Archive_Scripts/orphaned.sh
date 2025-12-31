#!/bin/bash
#
# Title:         Orphaned Desktop Shortcut Cleaner
# Description:   Finds and removes orphaned .desktop files for a specific application.
# Author:        Gemini
# Version:       2.0
# Usage:         ./cleanup_shortcuts.sh

# --- Configuration ---
# An array of directories where .desktop files are commonly located.
# This includes user-local, system-wide, snap, and flatpak directories.
APP_DIRS=(
    "$HOME/.local/share/applications"
    "/usr/share/applications"
    "/usr/local/share/applications"
    "/var/lib/snapd/desktop/applications"
    "/var/lib/flatpak/exports/share/applications"
)

# --- Functions ---

# Function to check if a command exists.
# It handles both absolute paths (e.g., /opt/app/run) and
# commands that should be in the system's $PATH (e.g., firefox).
#
# Usage: command_exists "command_name"
command_exists() {
    local cmd_to_check="$1"

    # If the command path is absolute (starts with '/'),
    # we check if a file exists at that path and is executable.
    if [[ "$cmd_to_check" == /* ]]; then
        if [ -x "$cmd_to_check" ]; then
            return 0 # Success, command exists and is executable
        else
            return 1 # Failure, not found or not executable
        fi
    fi

    # If it's not an absolute path, we use the 'command -v' builtin.
    # This is a reliable way to see if a command is available in the shell's PATH.
    # We redirect output to /dev/null to keep the script output clean.
    command -v "$cmd_to_check" > /dev/null 2>&1
    return $? # Returns 0 if found, non-zero otherwise.
}

# --- Main Script Logic ---

echo "🧹 Orphaned Shortcut Cleaner"
echo "--------------------------------------------------"

# 1. Ask the user for the application name
read -p "Enter the name of the application to search for: " app_name

if [ -z "$app_name" ]; then
    echo "❌ No application name entered. Exiting."
    exit 1
fi

echo "Searching for orphaned shortcuts matching '$app_name'..."
echo

# Array to hold the paths of broken .desktop files we find.
orphaned_files=()
total_checked=0

# --- Pre-scan Check ---
# Filter out directories from APP_DIRS that don't exist on this system.
search_paths=()
for dir in "${APP_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        search_paths+=("$dir")
    fi
done

if [ ${#search_paths[@]} -eq 0 ]; then
    echo "❌ Error: Could not find any of the standard application directories to scan."
    exit 1
fi

# 2. Find all .desktop files matching the name and check them.
while IFS= read -r -d '' desktop_file; do
    ((total_checked++))

    # We only care about the 'Exec=' line in the .desktop file.
    exec_line=$(grep -E "^Exec=" "$desktop_file" || true)

    if [ -z "$exec_line" ]; then
        continue
    fi

    # Extract the command from the 'Exec=' line.
    command_value=$(echo "$exec_line" | cut -d'=' -f2-)
    read -r -a command_parts <<< "$command_value"

    command_to_check=""
    for part in "${command_parts[@]}"; do
        if [[ "$part" == *"="* ]]; then # Skip environment variables
            continue
        fi
        command_to_check="$part"
        break
    done

    if [ -z "$command_to_check" ]; then
        continue
    fi

    # 3. Check if the command exists. If not, it's an orphan.
    if ! command_exists "$command_to_check"; then
        orphaned_files+=("$desktop_file")
        echo "❗️ Found orphaned entry:"
        echo "   File:    $desktop_file"
        echo "   Command: '$command_to_check' (not found)"
        echo
    fi

# Use find with -iname for a case-insensitive search of files matching the app name.
done < <(find "${search_paths[@]}" -type f -iname "*$app_name*.desktop" -print0 2>/dev/null)


# --- Summary and Cleanup ---
echo "--------------------------------------------------"
echo "Scan complete. Checked $total_checked matching file(s)."

# If the array of broken files is empty, we're done!
if [ ${#orphaned_files[@]} -eq 0 ]; then
    echo "✅ No orphaned shortcuts found for '$app_name'."
    exit 0
fi

echo "Found ${#orphaned_files[@]} orphaned shortcut(s) that can be removed."
echo

# 4. Ask for confirmation before deleting anything.
read -p "Do you want to remove these orphaned shortcut(s)? (y/n): " choice
echo

case "$choice" in
    y|Y )
        echo "Removing orphaned files..."
        for file in "${orphaned_files[@]}"; do
            echo -n "   Deleting '$file'... "
            # Check if we have write permissions. If not, we need sudo.
            if [ -w "$file" ]; then
                rm "$file"
                echo "Done."
            else
                echo "Requires sudo permissions."
                sudo rm "$file"
            fi
        done
        ;;

    * )
        # Any other input means we do nothing.
        echo "No files were deleted. Run the script again if you change your mind."
        ;;
esac

echo
echo "✅ Cleanup finished."

