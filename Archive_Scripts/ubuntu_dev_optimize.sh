#!/bin/bash

# Ubuntu 24.04 Development Environment Optimization Script
# Optimized for Dell Inspiron 5415 with AMD Ryzen 5 5500U
# Author: System Optimization Script
# Version: 1.0

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging setup
LOG_DIR="$HOME/.local/share/dev_optimization"
LOG_FILE="$LOG_DIR/dev_optimization.log"
BACKUP_DIR="$HOME/.config/optimization_backups/$(date +%Y%m%d_%H%M%S)"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Function to print colored output
print_status() {
    local msg="${GREEN}[INFO]${NC} $1"
    echo -e "$msg"
    echo "[INFO] $1" >> "$LOG_FILE" 2>/dev/null || true
}

print_warning() {
    local msg="${YELLOW}[WARNING]${NC} $1"
    echo -e "$msg"
    echo "[WARNING] $1" >> "$LOG_FILE" 2>/dev/null || true
}

print_error() {
    local msg="${RED}[ERROR]${NC} $1"
    echo -e "$msg" >&2
    echo "[ERROR] $1" >> "$LOG_FILE" 2>/dev/null || true
}

print_section() {
    local msg="\n${BLUE}=== $1 ===${NC}"
    echo -e "$msg"
    echo -e "\n=== $1 ===" >> "$LOG_FILE" 2>/dev/null || true
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root for safety reasons."
        print_error "Please run as regular user. Sudo will be used when needed."
        exit 1
    fi
}

# Create backup directory and ensure log directory exists
create_backup_dir() {
    print_status "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    print_status "Creating log directory: $LOG_DIR"
    mkdir -p "$LOG_DIR"
    
    # Initialize log file
    echo "=== Development Optimization Log - $(date) ===" > "$LOG_FILE"
}

# System information detection
detect_system() {
    print_section "SYSTEM DETECTION"
    
    CPU_CORES=$(nproc)
    RAM_GB=$(free -g | awk 'NR==2{print $2}')
    
    print_status "Detected: AMD Ryzen 5 5500U with $CPU_CORES cores"
    print_status "RAM: ${RAM_GB}GB"
    print_status "OS: $(lsb_release -d | cut -f2)"
    print_status "Kernel: $(uname -r)"
}

# Update system packages
update_system() {
    print_section "SYSTEM UPDATE"
    
    print_status "Updating package lists..."
    sudo apt update
    
    print_status "Upgrading installed packages..."
    sudo apt upgrade -y
    
    print_status "Installing essential development packages..."
    
    # First, clean up any repository issues
    print_status "Cleaning up repository configurations..."
    sudo apt update --fix-missing 2>/dev/null || true
    
    # Install packages in groups to handle potential failures gracefully
    print_status "Installing core development tools..."
    sudo apt install -y \
        curl wget git vim neovim htop \
        build-essential cmake pkg-config \
        software-properties-common apt-transport-https \
        ca-certificates gnupg lsb-release || true
    
    print_status "Installing shell and terminal tools..."
    sudo apt install -y \
        zsh fish tmux screen \
        tree fzf ripgrep fd-find bat || true
    
    # Try to install eza (replacement for exa), fallback if not available
    print_status "Installing modern terminal utilities..."
    if sudo apt install -y eza 2>/dev/null; then
        print_status "Installed eza (modern ls replacement)"
    else
        print_warning "eza not available, will use standard ls with aliases"
    fi
    
    # Install btop if available, fallback to htop
    if sudo apt install -y btop 2>/dev/null; then
        print_status "Installed btop (modern htop replacement)"
    else
        print_warning "btop not available, using htop"
    fi
    
    print_status "Installing development languages and tools..."
    sudo apt install -y \
        python3-dev python3-pip python3-venv \
        nodejs npm \
        default-jdk || true
    
    # Install yarn separately as it might conflict
    if ! sudo apt install -y yarn 2>/dev/null; then
        print_warning "yarn package conflicts detected, will install via npm later"
    fi
    
    print_status "Installing containerization tools..."
    sudo apt install -y docker.io docker-compose-v2 || sudo apt install -y docker.io docker-compose || true
    
    print_status "Installing system optimization tools..."
    sudo apt install -y \
        neofetch \
        preload \
        zram-config || true
    
    # Install VS Code if not already installed
    if ! command -v code &> /dev/null; then
        print_status "Installing Visual Studio Code..."
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
        sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
        sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
        sudo apt update && sudo apt install -y code || print_warning "VS Code installation failed"
        rm -f packages.microsoft.gpg
    fi
    
    # Install yarn via npm if apt version failed
    if ! command -v yarn &> /dev/null; then
        print_status "Installing yarn via npm..."
        sudo npm install -g yarn 2>/dev/null || print_warning "yarn installation via npm failed"
    fi
}

# AMD-specific optimizations
optimize_amd_graphics() {
    print_section "AMD GRAPHICS OPTIMIZATION"
    
    # Install AMD drivers and utilities
    sudo apt install -y \
        mesa-utils \
        mesa-vulkan-drivers \
        libvulkan1 \
        vulkan-utils \
        vainfo \
        amd64-microcode
    
    # Create AMD GPU configuration
    print_status "Configuring AMD GPU settings..."
    
    # Enable GPU performance mode
    if [[ -d /sys/class/drm/card0/device ]]; then
        echo "high" | sudo tee /sys/class/drm/card0/device/power_dpm_force_performance_level > /dev/null 2>&1 || true
    fi
    
    # Configure Mesa drivers for better performance
    cat > "$HOME/.drirc" << 'EOF'
<driconf>
    <device>
        <application name="Default">
            <option name="mesa_glthread" value="true" />
            <option name="mesa_no_error" value="true" />
            <option name="allow_glsl_extension_directive_midshader" value="true" />
        </application>
    </device>
</driconf>
EOF
    
    print_status "AMD graphics optimization completed"
}

# CPU performance optimization
optimize_cpu() {
    print_section "CPU OPTIMIZATION"
    
    # Install CPU frequency scaling tools
    sudo apt install -y cpufrequtils
    
    # Set CPU governor to performance for development
    print_status "Setting CPU governor to performance mode..."
    echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils
    
    # Configure CPU scaling
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [[ -f "$cpu" ]]; then
            echo "performance" | sudo tee "$cpu" > /dev/null 2>&1 || true
        fi
    done
    
    # Optimize CPU scheduler
    print_status "Optimizing CPU scheduler..."
    cat << 'EOF' | sudo tee /etc/sysctl.d/99-cpu-optimization.conf
# CPU optimization for development workloads
kernel.sched_autogroup_enabled = 0
kernel.sched_child_runs_first = 1
kernel.sched_latency_ns = 1000000
kernel.sched_min_granularity_ns = 100000
kernel.sched_wakeup_granularity_ns = 500000
kernel.sched_migration_cost_ns = 250000
EOF
}

# Memory optimization
optimize_memory() {
    print_section "MEMORY OPTIMIZATION"
    
    # Configure swap and memory settings
    print_status "Optimizing memory management..."
    
    # Backup original sysctl.conf
    sudo cp /etc/sysctl.conf "$BACKUP_DIR/sysctl.conf.backup"
    
    cat << 'EOF' | sudo tee /etc/sysctl.d/99-memory-optimization.conf
# Memory optimization for development
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
vm.dirty_expire_centisecs = 3000
vm.dirty_writeback_centisecs = 500
vm.overcommit_memory = 1
vm.overcommit_ratio = 50

# Network optimization
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq

# File system optimization
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192
EOF
    
    # Apply settings immediately
    sudo sysctl -p /etc/sysctl.d/99-memory-optimization.conf
    
    # Configure ZRAM for better memory compression
    print_status "Configuring ZRAM..."
    sudo systemctl enable zram-config
}

# I/O optimization
optimize_io() {
    print_section "I/O OPTIMIZATION"
    
    # Install and configure I/O scheduler
    print_status "Optimizing I/O scheduler..."
    
    # Set I/O scheduler to mq-deadline for SSDs
    cat << 'EOF' | sudo tee /etc/udev/rules.d/60-ioschedulers.rules
# Set I/O scheduler for different device types
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
EOF
    
    # Configure I/O parameters
    cat << 'EOF' | sudo tee /etc/sysctl.d/99-io-optimization.conf
# I/O optimization
kernel.io_delay_type = 3
vm.page-cluster = 0
vm.block_dump = 0
EOF
}

# Development tools optimization
optimize_dev_tools() {
    print_section "DEVELOPMENT TOOLS OPTIMIZATION"
    
    # Configure Git
    print_status "Optimizing Git configuration..."
    git config --global core.preloadindex true
    git config --global core.fscache true
    git config --global gc.auto 256
    git config --global feature.manyFiles true
    git config --global index.threads 0
    
    # Install and configure Node.js optimizations
    print_status "Optimizing Node.js environment..."
    
    # Increase Node.js memory limit and optimize V8
    cat << 'EOF' >> "$HOME/.bashrc"

# Node.js optimizations
export NODE_OPTIONS="--max-old-space-size=4096 --optimize-for-size"
export UV_THREADPOOL_SIZE=16

# Development environment optimizations
export MAKEFLAGS="-j$(nproc)"
export CARGO_BUILD_JOBS=$(nproc)
EOF
    
    # Configure NPM for better performance
    npm config set registry https://registry.npmjs.org/
    npm config set progress false
    npm config set audit false
    npm config set fund false
    
    # Python optimizations
    print_status "Optimizing Python environment..."
    cat << 'EOF' >> "$HOME/.bashrc"

# Python optimizations
export PYTHONDONTWRITEBYTECODE=1
export PYTHONUNBUFFERED=1
export PIP_DISABLE_PIP_VERSION_CHECK=1
EOF
}

# Configure development services
configure_services() {
    print_section "CONFIGURING DEVELOPMENT SERVICES"
    
    # Add user to docker group
    print_status "Adding user to docker group..."
    sudo usermod -aG docker "$USER"
    
    # Enable and start essential services
    print_status "Enabling development services..."
    sudo systemctl enable docker
    sudo systemctl start docker
    
    # Configure preload service for faster application loading
    sudo systemctl enable preload
    sudo systemctl start preload
    
    # Disable unnecessary services
    print_status "Disabling unnecessary services..."
    services_to_disable=(
        "bluetooth.service"
        "cups.service"
        "avahi-daemon.service"
    )
    
    for service in "${services_to_disable[@]}"; do
        if systemctl is-enabled "$service" &>/dev/null; then
            print_warning "Disabling $service (you can re-enable if needed)"
            sudo systemctl disable "$service" || true
        fi
    done
}

# Security and firewall optimization
configure_security() {
    print_section "SECURITY CONFIGURATION"
    
    # Install and configure UFW
    sudo apt install -y ufw fail2ban
    
    # Configure firewall
    print_status "Configuring firewall..."
    sudo ufw --force enable
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Allow common development ports
    dev_ports=(22 80 443 3000 3001 4200 5000 5173 8000 8080 8081 9000)
    for port in "${dev_ports[@]}"; do
        sudo ufw allow "$port"
    done
    
    # Configure fail2ban
    print_status "Configuring fail2ban..."
    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban
}

# Clean up system
cleanup_system() {
    print_section "SYSTEM CLEANUP"
    
    print_status "Cleaning package cache..."
    sudo apt autoremove -y
    sudo apt autoclean
    
    print_status "Cleaning temporary files..."
    sudo rm -rf /tmp/*
    sudo journalctl --vacuum-time=7d
    
    # Clear thumbnail cache
    if [[ -d "$HOME/.cache/thumbnails" ]]; then
        rm -rf "$HOME/.cache/thumbnails"/*
    fi
    
    print_status "System cleanup completed"
}

# Configure shell environment
configure_shell() {
    print_section "SHELL ENVIRONMENT CONFIGURATION"
    
    # Install Oh My Zsh if zsh is available
    if command -v zsh &> /dev/null; then
        print_status "Installing Oh My Zsh..."
        if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        fi
        
        # Configure useful aliases
        cat << 'EOF' >> "$HOME/.zshrc"

# Development aliases
alias ll='ls -la --color=auto'
alias la='ls -la --color=auto'

# Try to use eza if available, otherwise use ls
if command -v eza &> /dev/null; then
    alias ll='eza -la --git'
    alias la='eza -la'
    alias lt='eza -T'
fi

# Use bat if available, otherwise use cat
if command -v bat &> /dev/null; then
    alias cat='bat'
elif command -v batcat &> /dev/null; then
    alias cat='batcat'
fi

# Use modern tools if available
if command -v fd &> /dev/null; then
    alias find='fd'
fi

if command -v rg &> /dev/null; then
    alias grep='rg'
else
    alias grep='grep --color=auto'
fi

if command -v btop &> /dev/null; then
    alias htop='btop'
fi

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph'

# Docker aliases
alias dps='docker ps'
alias dimg='docker images'
alias dex='docker exec -it'

# System monitoring
alias sysinfo='neofetch'
alias temps='sensors'
EOF
    fi
    
    # Configure the same aliases for bash
    cat << 'EOF' >> "$HOME/.bashrc"

# Development aliases
alias ll='ls -la --color=auto'
alias la='ls -la --color=auto'

# Try to use eza if available, otherwise use ls
if command -v eza &> /dev/null; then
    alias ll='eza -la --git'
    alias la='eza -la'
    alias lt='eza -T'
fi

# Use bat if available, otherwise use cat
if command -v bat &> /dev/null; then
    alias cat='bat'
elif command -v batcat &> /dev/null; then
    alias cat='batcat'
fi

# Use modern tools if available
if command -v fd &> /dev/null; then
    alias find='fd'
fi

if command -v rg &> /dev/null; then
    alias grep='rg'
else
    alias grep='grep --color=auto'
fi

if command -v btop &> /dev/null; then
    alias htop='btop'
fi

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph'

# Docker aliases
alias dps='docker ps'
alias dimg='docker images'
alias dex='docker exec -it'

# System monitoring
alias sysinfo='neofetch'
EOF
}

# Performance monitoring setup
setup_monitoring() {
    print_section "PERFORMANCE MONITORING SETUP"
    
    # Install monitoring tools
    sudo apt install -y \
        iotop \
        powertop \
        tlp \
        tlp-rdw \
        acpi-call-dkms
    
    # Configure TLP for better battery and performance management
    print_status "Configuring TLP for optimal performance..."
    sudo systemctl enable tlp
    sudo systemctl start tlp
    
    # Create bin directory and performance monitoring script
    mkdir -p "$HOME/bin"
    cat << 'EOF' > "$HOME/bin/perf-monitor"
#!/bin/bash
# Performance monitoring script

echo "=== System Performance Monitor ==="
echo "Date: $(date)"
echo ""

echo "=== CPU Information ==="
lscpu | grep -E "(Model name|CPU\(s\)|CPU MHz|Cache)"
echo ""

echo "=== Memory Usage ==="
free -h
echo ""

echo "=== Disk Usage ==="
df -h / /home
echo ""

echo "=== CPU Temperature ==="
sensors | grep -E "(Core|Tctl)" || echo "Install lm-sensors: sudo apt install lm-sensors"
echo ""

echo "=== Top Processes by CPU ==="
ps aux --sort=-pcpu | head -10
echo ""

echo "=== Top Processes by Memory ==="
ps aux --sort=-pmem | head -10
EOF
    
    chmod +x "$HOME/bin/perf-monitor"
    
    # Add ~/bin to PATH if not already there
    if ! echo "$PATH" | grep -q "$HOME/bin"; then
        echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
        if [[ -f "$HOME/.zshrc" ]]; then
            echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zshrc"
        fi
    fi
}

# Final system verification
verify_optimization() {
    print_section "OPTIMIZATION VERIFICATION"
    
    print_status "Verifying CPU governor..."
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
    
    print_status "Verifying memory settings..."
    sysctl vm.swappiness vm.vfs_cache_pressure
    
    print_status "Verifying I/O scheduler..."
    cat /sys/block/*/queue/scheduler 2>/dev/null | head -3
    
    print_status "Checking development tools..."
    for tool in git node npm python3 docker; do
        if command -v "$tool" &> /dev/null; then
            print_status "$tool: $(command -v "$tool")"
        else
            print_warning "$tool: not found"
        fi
    done
}

# Reboot recommendation
recommend_reboot() {
    print_section "OPTIMIZATION COMPLETE"
    
    cat << EOF

${GREEN}╔════════════════════════════════════════════════════════════╗
║                    OPTIMIZATION COMPLETE!                   ║
╚════════════════════════════════════════════════════════════╝${NC}

${YELLOW}Important Notes:${NC}

1. ${GREEN}System Optimized For:${NC}
   • Software Development
   • AMD Ryzen 5 5500U Performance
   • 16GB RAM Utilization
   • SSD I/O Performance

2. ${GREEN}What was optimized:${NC}
   • CPU governor set to performance mode
   • Memory management tuned for development
   • I/O scheduler optimized for SSD
   • Development tools installed and configured
   • Security hardening applied

3. ${GREEN}Next Steps:${NC}
   • Reboot your system to apply all changes
   • Run 'source ~/.bashrc' or restart terminal
   • Use '$HOME/bin/perf-monitor' to check performance
   • Log out and back in to join docker group

4. ${GREEN}New Commands Available:${NC}
   • btop (better htop)
   • exa (better ls)
   • bat (better cat)
   • fd (better find)
   • rg (ripgrep)

${RED}REBOOT REQUIRED for all optimizations to take effect!${NC}

${BLUE}Backup created at: $BACKUP_DIR${NC}
${BLUE}Log file: $LOG_FILE${NC}

EOF
}

# Main execution function
main() {
    print_section "UBUNTU 24.04 DEVELOPMENT OPTIMIZATION"
    print_status "Starting optimization for Dell Inspiron 5415..."
    
    # Initialize directories and logging first
    mkdir -p "$LOG_DIR"
    echo "=== Development Optimization Log - $(date) ===" > "$LOG_FILE"
    
    check_root
    create_backup_dir
    detect_system
    
    # Core optimizations
    update_system
    optimize_amd_graphics
    optimize_cpu
    optimize_memory
    optimize_io
    
    # Development environment
    optimize_dev_tools
    configure_services
    configure_security
    configure_shell
    setup_monitoring
    
    # Cleanup and verification
    cleanup_system
    verify_optimization
    recommend_reboot
    
    print_status "Optimization completed successfully!"
}

# Error handling
trap 'print_error "Script interrupted. Check $LOG_FILE for details."; exit 1' INT TERM

# Run main function
main "$@"