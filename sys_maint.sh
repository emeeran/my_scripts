#!/bin/bash
# Ubuntu System Maintenance Script
# Author: Meeran (Optimized for Dell Inspiron 5415, AMD Ryzen 5 5500U, 16GB RAM)
# Purpose: Regular system maintenance to keep performance at peak
# Recommended: Run weekly or bi-weekly

set -e

# Color formatting
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_VERSION="2.0"
LOG_FILE="/tmp/system_maintenance_$(date +%Y%m%d_%H%M%S).log"
MAINTENANCE_REPORT="/tmp/maintenance_report_$(date +%Y%m%d).txt"

# System info
TOTAL_RAM=$(free -g | awk 'NR==2{print $2}')
USED_RAM=$(free -g | awk 'NR==2{print $3}')
FREE_SPACE_ROOT=$(df -h / | awk 'NR==2 {print $4}')
FREE_SPACE_HOME=$(df -h /home 2>/dev/null | awk 'NR==2 {print $4}' || echo "N/A")
UPTIME=$(uptime -p)

# Initialize arrays
CLEANED_ITEMS=()
PERFORMANCE_IMPROVEMENTS=()
WARNINGS=()
ERRORS=()

printf "${GREEN}=== Ubuntu System Maintenance Script v${SCRIPT_VERSION} ===${NC}\n"
printf "${BLUE}Starting maintenance at: $(date)${NC}\n"
printf "${CYAN}System Info: ${TOTAL_RAM}GB RAM (${USED_RAM}GB used) | Root: ${FREE_SPACE_ROOT} free | Uptime: ${UPTIME}${NC}\n\n"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function for yes/no prompts with default
ask() {
    local prompt="$1"
    local default="${2:-y}"
    local response
    
    read -p "$prompt (y/n) [default: $default]: " response
    response=${response:-$default}
    case "$response" in 
      y|Y ) return 0 ;;
      * ) return 1 ;;
    esac
}

# Check if running as root (not recommended)
if [[ $EUID -eq 0 ]]; then
    printf "${RED}⚠️  Warning: Running as root. Some user-specific cleanups may not work properly.${NC}\n\n"
    WARNINGS+=("Script run as root - user-specific cleanups may be incomplete")
fi

# --- Package Management Cleanup ---
printf "${PURPLE}=== Package Management Cleanup ===${NC}\n"

if ask "Clean package cache and remove orphaned packages?"; then
    log "Starting package cleanup"
    
    # Update package database
    printf "📦 Updating package database...\n"
    sudo apt update > /dev/null 2>&1
    
    # Clean package cache
    printf "🗑️  Cleaning package cache...\n"
    CACHE_SIZE_BEFORE=$(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1 || echo "0")
    sudo apt clean
    sudo apt autoclean
    CACHE_SIZE_AFTER=$(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1 || echo "0")
    
    # Remove orphaned packages
    printf "📦 Removing orphaned packages...\n"
    ORPHANED=$(sudo apt autoremove --dry-run 2>/dev/null | grep -c "packages will be REMOVED" || echo "0")
    if [[ $ORPHANED -gt 0 ]]; then
        sudo apt autoremove -y > /dev/null 2>&1
        CLEANED_ITEMS+=("Removed ${ORPHANED} orphaned packages")
    fi
    
    # Remove residual config files
    printf "⚙️  Cleaning residual configuration files...\n"
    RESIDUAL_CONFIGS=$(dpkg -l | awk '/^rc/ { print $2 }' | wc -l)
    if [[ $RESIDUAL_CONFIGS -gt 0 ]]; then
        dpkg -l | awk '/^rc/ { print $2 }' | sudo xargs dpkg --purge 2>/dev/null || true
        CLEANED_ITEMS+=("Removed ${RESIDUAL_CONFIGS} residual config files")
    fi
    
    CLEANED_ITEMS+=("Package cache cleaned (was: ${CACHE_SIZE_BEFORE}, now: ${CACHE_SIZE_AFTER})")
    log "Package cleanup completed"
fi

# --- System Cache and Temporary Files ---
printf "\n${PURPLE}=== System Cache and Temporary Files ===${NC}\n"

if ask "Clean system caches and temporary files?"; then
    log "Starting system cache cleanup"
    
    # Calculate initial sizes
    TEMP_SIZE_BEFORE=$(du -sh /tmp 2>/dev/null | cut -f1 || echo "0")
    
    # Clean /tmp (files older than 7 days)
    printf "🗂️  Cleaning /tmp directory...\n"
    sudo find /tmp -type f -atime +7 -delete 2>/dev/null || true
    sudo find /tmp -type d -empty -delete 2>/dev/null || true
    
    # Clean /var/tmp (files older than 30 days)
    printf "📁 Cleaning /var/tmp directory...\n"
    sudo find /var/tmp -type f -atime +30 -delete 2>/dev/null || true
    
    # Clean systemd journal logs (keep last 100MB)
    printf "📄 Managing systemd journal logs...\n"
    JOURNAL_SIZE_BEFORE=$(sudo du -sh /var/log/journal 2>/dev/null | cut -f1 || echo "0")
    sudo journalctl --vacuum-size=100M > /dev/null 2>&1
    JOURNAL_SIZE_AFTER=$(sudo du -sh /var/log/journal 2>/dev/null | cut -f1 || echo "0")
    
    # Clean old log files
    printf "📋 Cleaning old log files...\n"
    sudo find /var/log -name "*.log.*.gz" -mtime +30 -delete 2>/dev/null || true
    sudo find /var/log -name "*.[0-9]*" -mtime +30 -delete 2>/dev/null || true
    
    # Clean crash reports
    printf "💥 Removing crash reports...\n"
    CRASH_REPORTS=$(find /var/crash -name "*.crash" 2>/dev/null | wc -l || echo "0")
    if [[ $CRASH_REPORTS -gt 0 ]]; then
        sudo rm -f /var/crash/*.crash 2>/dev/null || true
        CLEANED_ITEMS+=("Removed ${CRASH_REPORTS} crash reports")
    fi
    
    TEMP_SIZE_AFTER=$(du -sh /tmp 2>/dev/null | cut -f1 || echo "0")
    CLEANED_ITEMS+=("Temporary files cleaned (/tmp: ${TEMP_SIZE_BEFORE} → ${TEMP_SIZE_AFTER})")
    CLEANED_ITEMS+=("Journal logs cleaned (${JOURNAL_SIZE_BEFORE} → ${JOURNAL_SIZE_AFTER})")
    log "System cache cleanup completed"
fi

# --- User Cache and Browser Cleanup ---
printf "\n${PURPLE}=== User Cache and Browser Cleanup ===${NC}\n"

if ask "Clean user caches and browser data?"; then
    log "Starting user cache cleanup"
    
    # User cache directories
    if [[ -d "$HOME/.cache" ]]; then
        CACHE_SIZE_BEFORE=$(du -sh "$HOME/.cache" 2>/dev/null | cut -f1 || echo "0")
        printf "🗃️  Cleaning user cache directory...\n"
        
        # Clean thumbnails cache
        if [[ -d "$HOME/.cache/thumbnails" ]]; then
            find "$HOME/.cache/thumbnails" -type f -atime +30 -delete 2>/dev/null || true
        fi
        
        # Clean pip cache
        if [[ -d "$HOME/.cache/pip" ]]; then
            rm -rf "$HOME/.cache/pip"/* 2>/dev/null || true
        fi
        
        # Clean npm cache
        if command -v npm >/dev/null 2>&1; then
            npm cache clean --force > /dev/null 2>&1 || true
        fi
        
        # Clean yarn cache
        if command -v yarn >/dev/null 2>&1; then
            yarn cache clean > /dev/null 2>&1 || true
        fi
        
        CACHE_SIZE_AFTER=$(du -sh "$HOME/.cache" 2>/dev/null | cut -f1 || echo "0")
        CLEANED_ITEMS+=("User cache cleaned (${CACHE_SIZE_BEFORE} → ${CACHE_SIZE_AFTER})")
    fi
    
    # Chrome/Chromium cleanup
    CHROME_DIRS=(
        "$HOME/.config/google-chrome"
        "$HOME/.config/chromium"
        "$HOME/.config/microsoft-edge"
    )
    
    for chrome_dir in "${CHROME_DIRS[@]}"; do
        if [[ -d "$chrome_dir" ]]; then
            printf "🌐 Cleaning $(basename "$chrome_dir") cache...\n"
            find "$chrome_dir" -name "*.tmp" -delete 2>/dev/null || true
            find "$chrome_dir" -name "Cache*" -type d -exec rm -rf {} + 2>/dev/null || true
            find "$chrome_dir" -name "Code Cache*" -type d -exec rm -rf {} + 2>/dev/null || true
            CLEANED_ITEMS+=("$(basename "$chrome_dir") cache cleaned")
        fi
    done
    
    # Firefox cleanup
    FIREFOX_PROFILE=$(find "$HOME/.mozilla/firefox" -name "*.default-release" -type d 2>/dev/null | head -1)
    if [[ -n "$FIREFOX_PROFILE" && -d "$FIREFOX_PROFILE" ]]; then
        printf "🦊 Cleaning Firefox cache...\n"
        rm -rf "$FIREFOX_PROFILE/cache2"/* 2>/dev/null || true
        rm -rf "$FIREFOX_PROFILE/startupCache"/* 2>/dev/null || true
        rm -rf "$FIREFOX_PROFILE/OfflineCache"/* 2>/dev/null || true
        CLEANED_ITEMS+=("Firefox cache cleaned")
    fi
    
    log "User cache cleanup completed"
fi

# --- Development Environment Cleanup ---
printf "\n${PURPLE}=== Development Environment Cleanup ===${NC}\n"

if ask "Clean development caches (Docker, Node modules, etc.)?"; then
    log "Starting development cleanup"
    
    # Docker cleanup
    if command -v docker >/dev/null 2>&1; then
        printf "🐳 Cleaning Docker resources...\n"
        
        # Clean up unused containers, networks, images
        DOCKER_CLEANUP=$(docker system prune -f 2>/dev/null | grep "Total reclaimed space" || echo "0B reclaimed")
        if [[ "$DOCKER_CLEANUP" != "0B reclaimed" ]]; then
            CLEANED_ITEMS+=("Docker cleanup: $DOCKER_CLEANUP")
        fi
        
        # Remove dangling images
        DANGLING_IMAGES=$(docker images -f "dangling=true" -q | wc -l)
        if [[ $DANGLING_IMAGES -gt 0 ]]; then
            docker rmi $(docker images -f "dangling=true" -q) >/dev/null 2>&1 || true
            CLEANED_ITEMS+=("Removed ${DANGLING_IMAGES} dangling Docker images")
        fi
    fi
    
    # Clean old node_modules (in common dev directories)
    DEV_DIRS=("$HOME/Projects" "$HOME/Development" "$HOME/dev" "$HOME/code" "$HOME/workspace")
    for dev_dir in "${DEV_DIRS[@]}"; do
        if [[ -d "$dev_dir" ]]; then
            printf "📦 Cleaning old node_modules in $(basename "$dev_dir")...\n"
            find "$dev_dir" -name "node_modules" -type d -mtime +60 -exec rm -rf {} + 2>/dev/null || true
        fi
    done
    
    # Clean Python __pycache__
    if [[ -d "$HOME" ]]; then
        printf "🐍 Cleaning Python cache files...\n"
        find "$HOME" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
        find "$HOME" -name "*.pyc" -delete 2>/dev/null || true
    fi
    
    # Clean VS Code extensions cache
    if [[ -d "$HOME/.vscode/extensions" ]]; then
        find "$HOME/.vscode/extensions" -name "*.vsix" -delete 2>/dev/null || true
    fi
    
    log "Development cleanup completed"
fi

# --- Memory and Performance Optimization ---
printf "\n${PURPLE}=== Memory and Performance Optimization ===${NC}\n"

if ask "Optimize memory and system performance?"; then
    log "Starting performance optimization"
    
    # Clear page cache, dentries and inodes
    printf "🧠 Clearing system caches...\n"
    FREE_MEM_BEFORE=$(free -h | awk 'NR==2{print $7}')
    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
    FREE_MEM_AFTER=$(free -h | awk 'NR==2{print $7}')
    PERFORMANCE_IMPROVEMENTS+=("Memory freed: ${FREE_MEM_BEFORE} → ${FREE_MEM_AFTER}")
    
    # Defragment and optimize SSD (TRIM)
    if lsblk -d -o name,rota | awk '$2=="0"' | grep -q .; then
        printf "💾 Running SSD TRIM optimization...\n"
        sudo fstrim -av > /dev/null 2>&1 || true
        PERFORMANCE_IMPROVEMENTS+=("SSD TRIM optimization completed")
    fi
    
    # Update locate database
    printf "🔍 Updating locate database...\n"
    sudo updatedb > /dev/null 2>&1 || true
    PERFORMANCE_IMPROVEMENTS+=("Locate database updated")
    
    # Prelink binaries for faster loading (if prelink is installed)
    if command -v prelink >/dev/null 2>&1; then
        printf "🔗 Optimizing binary linking...\n"
        sudo prelink -amR > /dev/null 2>&1 || true
        PERFORMANCE_IMPROVEMENTS+=("Binary linking optimized")
    fi
    
    log "Performance optimization completed"
fi

# --- System Health Checks ---
printf "\n${PURPLE}=== System Health Checks ===${NC}\n"

if ask "Run system health and security checks?"; then
    log "Starting system health checks"
    
    # Check disk usage and warn if > 80%
    printf "💾 Checking disk usage...\n"
    ROOT_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $ROOT_USAGE -gt 80 ]]; then
        WARNINGS+=("Root partition is ${ROOT_USAGE}% full - consider cleaning up")
    fi
    
    # Check for failed systemd services
    printf "⚙️  Checking for failed services...\n"
    FAILED_SERVICES=$(systemctl --failed --no-legend | wc -l)
    if [[ $FAILED_SERVICES -gt 0 ]]; then
        WARNINGS+=("${FAILED_SERVICES} systemd services have failed")
        systemctl --failed --no-legend >> "$LOG_FILE"
    fi
    
    # Check system load
    printf "📊 Checking system load...\n"
    LOAD_AVERAGE=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    if (( $(echo "$LOAD_AVERAGE > $CPU_CORES" | bc -l) )); then
        WARNINGS+=("System load ($LOAD_AVERAGE) is higher than CPU cores ($CPU_CORES)")
    fi
    
    # Check memory usage
    printf "🧠 Checking memory usage...\n"
    MEMORY_USAGE=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [[ $MEMORY_USAGE -gt 85 ]]; then
        WARNINGS+=("Memory usage is ${MEMORY_USAGE}% - consider closing applications")
    fi
    
    # Check for security updates
    printf "🛡️  Checking for security updates...\n"
    SECURITY_UPDATES=$(apt list --upgradable 2>/dev/null | grep -c "security" || echo "0")
    if [[ $SECURITY_UPDATES -gt 0 ]]; then
        WARNINGS+=("${SECURITY_UPDATES} security updates available - run 'sudo apt upgrade'")
    fi
    
    # Check last backup (if rsync or timeshift is available)
    if command -v timeshift >/dev/null 2>&1; then
        LAST_BACKUP=$(timeshift --list | grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}_[0-9]\{2\}-[0-9]\{2\}-[0-9]\{2\}' | sort -r | head -1)
        if [[ -n "$LAST_BACKUP" ]]; then
            BACKUP_AGE=$(( ($(date +%s) - $(date -d "${LAST_BACKUP:0:10}" +%s)) / 86400 ))
            if [[ $BACKUP_AGE -gt 7 ]]; then
                WARNINGS+=("Last system backup was ${BACKUP_AGE} days ago")
            fi
        fi
    fi
    
    log "System health checks completed"
fi

# --- Generate Maintenance Report ---
printf "\n${YELLOW}=== Generating Maintenance Report ===${NC}\n"

{
    echo "======================================"
    echo "Ubuntu System Maintenance Report"
    echo "======================================"
    echo "Date: $(date)"
    echo "System: Dell Inspiron 5415 | AMD Ryzen 5 5500U | ${TOTAL_RAM}GB RAM"
    echo "Uptime: $UPTIME"
    echo "Script Version: $SCRIPT_VERSION"
    echo ""
    
    echo "DISK USAGE:"
    df -h / /home 2>/dev/null | grep -E '^/|Filesystem'
    echo ""
    
    echo "MEMORY USAGE:"
    free -h
    echo ""
    
    if [[ ${#CLEANED_ITEMS[@]} -gt 0 ]]; then
        echo "ITEMS CLEANED:"
        for item in "${CLEANED_ITEMS[@]}"; do
            echo "  ✅ $item"
        done
        echo ""
    fi
    
    if [[ ${#PERFORMANCE_IMPROVEMENTS[@]} -gt 0 ]]; then
        echo "PERFORMANCE IMPROVEMENTS:"
        for improvement in "${PERFORMANCE_IMPROVEMENTS[@]}"; do
            echo "  🚀 $improvement"
        done
        echo ""
    fi
    
    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        echo "WARNINGS:"
        for warning in "${WARNINGS[@]}"; do
            echo "  ⚠️  $warning"
        done
        echo ""
    fi
    
    if [[ ${#ERRORS[@]} -gt 0 ]]; then
        echo "ERRORS:"
        for error in "${ERRORS[@]}"; do
            echo "  ❌ $error"
        done
        echo ""
    fi
    
    echo "SYSTEM SERVICES STATUS:"
    systemctl list-units --failed --no-legend || echo "  ✅ No failed services"
    echo ""
    
    echo "TOP PROCESSES BY MEMORY:"
    ps aux --sort=-%mem | head -6
    echo ""
    
    echo "TOP PROCESSES BY CPU:"
    ps aux --sort=-%cpu | head -6
    echo ""
    
} > "$MAINTENANCE_REPORT"

# --- Final Summary ---
printf "\n${GREEN}=== 📊 MAINTENANCE SUMMARY ===${NC}\n"

printf "${CYAN}=== Cleaned Items ===${NC}\n"
if [[ ${#CLEANED_ITEMS[@]} -gt 0 ]]; then
    for item in "${CLEANED_ITEMS[@]}"; do
        printf "  ✅ %s\n" "$item"
    done
else
    printf "  📝 No items were cleaned\n"
fi

if [[ ${#PERFORMANCE_IMPROVEMENTS[@]} -gt 0 ]]; then
    printf "\n${PURPLE}=== Performance Improvements ===${NC}\n"
    for improvement in "${PERFORMANCE_IMPROVEMENTS[@]}"; do
        printf "  🚀 %s\n" "$improvement"
    done
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    printf "\n${YELLOW}=== Warnings ===${NC}\n"
    for warning in "${WARNINGS[@]}"; do
        printf "  ⚠️  %s\n" "$warning"
    done
fi

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    printf "\n${RED}=== Errors ===${NC}\n"
    for error in "${ERRORS[@]}"; do
        printf "  ❌ %s\n" "$error"
    done
fi

printf "\n${GREEN}=== 📋 Reports Generated ===${NC}\n"
printf "  📄 Detailed log: %s\n" "$LOG_FILE"
printf "  📊 Maintenance report: %s\n" "$MAINTENANCE_REPORT"

printf "\n${GREEN}=== 🎉 MAINTENANCE COMPLETE! ===${NC}\n"
printf "${BLUE}Completed at: $(date)${NC}\n"
printf "${CYAN}Next recommended run: $(date -d '+1 week')${NC}\n"

# Optional: Set up automatic maintenance
if ask "\nWould you like to set up automatic weekly maintenance (crontab)?"; then
    SCRIPT_PATH=$(realpath "$0")
    (crontab -l 2>/dev/null; echo "0 2 * * 0 $SCRIPT_PATH --auto >> /var/log/system-maintenance.log 2>&1") | crontab -
    printf "${GREEN}✅ Weekly maintenance scheduled for Sundays at 2 AM${NC}\n"
    printf "${YELLOW}💡 Check logs at: /var/log/system-maintenance.log${NC}\n"
fi

# Handle --auto flag for cron jobs
if [[ "$1" == "--auto" ]]; then
    printf "\n${CYAN}=== AUTOMATED MAINTENANCE MODE ===${NC}\n"
    printf "Running essential maintenance tasks automatically...\n"
    # In auto mode, skip interactive prompts and run essential tasks
fi

log "Maintenance script completed successfully"
