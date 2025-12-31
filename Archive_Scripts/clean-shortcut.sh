#!/bin/bash
#
# Title:         Orphaned Desktop Shortcut Cleaner
# Description:   Scans for .desktop files that point to uninstalled or
#                non-existent executables and offers to remove them.
# Author:        Gemini
# Version:       1.2
# Usage:         ./cleanup_shortcuts.sh

# Note: 'set -e' was removed. It caused the script to exit prematurely if 'find'
# returned no results, as this would cause the 'read' command in the loop
# to fail. The script now handles this case gracefully.

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
echo "Scanning for broken .desktop files. This may take a moment..."

# Array to hold the paths of broken .desktop files we find.
broken_files=()
total_checked=0

# --- Pre-scan Check ---
# Filter out directories from APP_DIRS that don't exist on this system.
# This prevents the 'find' command from erroring out.
search_paths=()
for dir in "${APP_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        search_paths+=("$dir")
    fi
done

# If no valid application directories were found at all, exit gracefully.
if [ ${#search_paths[@]} -eq 0 ]; then
    echo "❌ Error: Could not find any of the standard application directories to scan."
    exit 1
fi

# The main loop. We use 'find' to locate all .desktop files and pipe them
# to a 'while' loop for processing using process substitution '< <(...)'.
# This method avoids creating a subshell for the loop, so variables like
# 'broken_files' can be modified and accessed after the loop finishes.
#
# - The `find ... -print0` and `while read -r -d ''` combination is a robust
#   way to handle filenames that might contain spaces or special characters.
# - We redirect stderr from find to /dev/null to hide "Permission denied" errors
#   for directories the user can't read.
while IFS= read -r -d '' desktop_file; do
    ((total_checked++))

    # We only care about the 'Exec=' line in the .desktop file.
    # We use grep to find the line that starts with "Exec=".
    exec_line=$(grep -E "^Exec=" "$desktop_file" || true)

    # If there's no 'Exec=' line, we can't check it, so we skip to the next file.
    if [ -z "$exec_line" ]; then
        continue
    fi

    # --- Extract the command from the 'Exec=' line ---
    # This can be tricky, as the line can have arguments (%U, %f),
    # environment variables (e.g., env GDK_BACKEND=x11), or quotes.
    # Our strategy is to take the first "word" on the line after 'Exec='
    # that doesn't look like an environment variable (i.e., doesn't contain '=').
    command_value=$(echo "$exec_line" | cut -d'=' -f2-)
    read -r -a command_parts <<< "$command_value"

    command_to_check=""
    for part in "${command_parts[@]}"; do
        # If the part contains an equals sign, it's likely an env var, so skip it.
        if [[ "$part" == *"="* ]]; then
            continue
        fi
        # The first part that is not an env var is our command.
        command_to_check="$part"
        break
    done

    # If we couldn't extract a command, skip this file.
    if [ -z "$command_to_check" ]; then
        continue
    fi

    # Now we check if the extracted command actually exists.
    if ! command_exists "$command_to_check"; then
        # If it doesn't exist, it's an orphan. Add it to our list.
        broken_files+=("$desktop_file")
        echo
        echo "❗️ Found orphaned entry:"
        echo "   File:    $desktop_file"
        echo "   Command: '$command_to_check' (not found)"
    fi

done < <(find "${search_paths[@]}" -type f -name "*.desktop" -print0 2>/dev/null)


# --- Summary and Cleanup ---
echo
echo "--------------------------------------------------"
echo "Scan complete. Checked $total_checked files."

# If the array of broken files is empty, we're done!
if [ ${#broken_files[@]} -eq 0 ]; then
    echo "✅ No orphaned .desktop files found. Your system is clean!"
    exit 0
fi

echo "Found ${#broken_files[@]} orphaned file(s) that can be removed."
echo

# Ask the user for confirmation before deleting anything.
read -p "Do you want to delete these files? (y/n/all): " choice
echo

case "$choice" in
    y|Y )
        # Interactive mode: ask for each file.
        echo "Entering interactive deletion mode..."
        for file in "${broken_files[@]}"; do
            read -p "   Delete '$file'? (y/n) " delete_confirm
            if [[ "$delete_confirm" == "y" || "$delete_confirm" == "Y" ]]; then
                echo -n "      Deleting... "
                # Check if we have write permissions. If not, we need sudo.
                if [ -w "$file" ]; then
                    rm "$file"
                    echo "Done."
                else
                    echo "Requires sudo permissions."
                    sudo rm "$file"
                fi
            else
                echo "      Skipping."
            fi
        done
        ;;

    all|ALL )
        # 'all' mode: delete all found files without asking again.
        echo "Deleting all found orphaned files..."
        for file in "${broken_files[@]}"; do
            echo -n "   Deleting '$file'... "
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

