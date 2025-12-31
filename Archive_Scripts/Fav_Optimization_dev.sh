#!/bin/bash
# Enhanced Ubuntu 24.04 Dev Optimization Script
# Author: Meeran (Optimized for Dell Inspiron 5415, AMD Ryzen 5 5500U, 16GB RAM)
# Features: Performance optimization, de-bloating, memory management, and dev environment setup

set -e

# Color formatting - using printf for better compatibility
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# System info
TOTAL_RAM=$(free -g | awk 'NR==2{print $2}')
CPU_CORES=$(nproc)
SSD_DEVICE=$(lsblk -d -o name,rota | awk '$2=="0"{print "/dev/"$1; exit}')

printf "${GREEN}=== Enhanced Ubuntu 24.04 Development Optimization Script ===${NC}\n"
printf "${BLUE}System: Dell Inspiron 5415 | RAM: ${TOTAL_RAM}GB | CPU Cores: ${CPU_CORES} | SSD: ${SSD_DEVICE}${NC}\n\n"

# Track installed/tweaked features
SUMMARY=()
PERFORMANCE_GAINS=()

# Function for yes/no prompts
ask() {
    read -p "$1 (y/n): " choice
    case "$choice" in 
      y|Y ) return 0 ;;
      * ) return 1 ;;
    esac
}

# Function to check if service exists
service_exists() {
    systemctl list-unit-files | grep -q "^$1"
}

# Function to safely disable service
safe_disable_service() {
    if service_exists "$1"; then
        sudo systemctl disable "$1" 2>/dev/null || true
        sudo systemctl stop "$1" 2>/dev/null || true
        printf "${GREEN}Disabled: $1${NC}\n"
    fi
}

# Function to remove package safely
safe_remove() {
    if dpkg -l | grep -q "^ii  $1 "; then
        sudo apt purge -y "$1" 2>/dev/null || true
        printf "${RED}Removed: $1${NC}\n"
    fi
}

# --- Initial System Update ---
printf "${YELLOW}=== Updating System ===${NC}\n"
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y && sudo apt autoclean
SUMMARY+=("✅ System updated & cleaned")

# --- System De-bloating ---
if ask "Remove bloatware and unnecessary packages?"; then
    printf "${PURPLE}=== Removing Bloatware ===${NC}\n"
    
    # Ubuntu bloatware
    BLOAT_PACKAGES=(
        "thunderbird" "rhythmbox" "cheese" "aisleriot" "gnome-mahjongg"
        "gnome-mines" "gnome-sudoku" "four-in-a-row" "gnome-klotski"
        "five-or-more" "hitori" "iagno" "lightsoff" "quadrapassel"
        "swell-foop" "tali" "gnome-robots" "gnome-nibbles" "gnome-taquin"
        "gnome-tetravex" "remmina" "transmission-gtk" "totem"
        "simple-scan" "shotwell" "libreoffice-*" "firefox" "snap"
        "whoopsie" "apport" "popularity-contest" "ubuntu-report"
    )
    
    for package in "${BLOAT_PACKAGES[@]}"; do
        safe_remove "$package"
    done
    
    # Remove snap completely
    sudo snap remove --purge firefox 2>/dev/null || true
    sudo snap remove --purge snap-store 2>/dev/null || true
    sudo snap remove --purge snapd-desktop-integration 2>/dev/null || true
    sudo apt purge -y snapd gnome-software-plugin-snap 2>/dev/null || true
    
    # Disable unnecessary services
    SERVICES_TO_DISABLE=(
        "whoopsie.service"
        "apport.service" 
        "apport-autoreport.service"
        "ubuntu-report.service"
        "popularity-contest.timer"
        "motd-news.timer"
        "esm-cache.service"
        "ua-reboot-cmds.service"
    )
    
    for service in "${SERVICES_TO_DISABLE[@]}"; do
        safe_disable_service "$service"
    done
    
    sudo apt autoremove -y && sudo apt autoclean
    SUMMARY+=("✅ Bloatware removed and unnecessary services disabled")
    PERFORMANCE_GAINS+=("🚀 ~200-400MB RAM saved, faster boot time")
fi

# --- Advanced Memory Management ---
if ask "Apply advanced memory management optimizations (16GB RAM optimized)?"; then
    printf "${PURPLE}=== Configuring Memory Management ===${NC}\n"
    
    # Create optimized sysctl configuration
    sudo tee /etc/sysctl.d/99-performance.conf > /dev/null << 'EOF'
# Memory Management Optimization for 16GB RAM
vm.swappiness=5
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=5
vm.dirty_ratio=10
vm.dirty_expire_centisecs=3000
vm.dirty_writeback_centisecs=500

# Network Performance
net.core.rmem_default=262144
net.core.rmem_max=16777216
net.core.wmem_default=262144
net.core.wmem_max=16777216
net.core.netdev_max_backlog=5000

# File System Performance
fs.file-max=2097152
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=512

# Kernel Performance
kernel.sched_migration_cost_ns=5000000
kernel.sched_autogroup_enabled=0
EOF
    
    sudo sysctl -p /etc/sysctl.d/99-performance.conf
    SUMMARY+=("✅ Advanced memory management configured")
    PERFORMANCE_GAINS+=("🚀 Optimized for 16GB RAM, reduced memory pressure")
fi

# --- SSD Performance Optimization ---
if ask "Apply comprehensive SSD optimizations?"; then
    printf "${PURPLE}=== Optimizing SSD Performance ===${NC}\n"
    
    # Enable TRIM
    sudo systemctl enable fstrim.timer
    sudo systemctl start fstrim.timer
    
    # Optimize I/O scheduler for SSD
    if [[ -n "$SSD_DEVICE" ]]; then
        echo 'ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"' | sudo tee /etc/udev/rules.d/60-ioschedulers.rules > /dev/null
    fi
    
    # Optimize mount options
    sudo cp /etc/fstab /etc/fstab.backup
    sudo sed -i 's/errors=remount-ro/errors=remount-ro,noatime,commit=60/' /etc/fstab
    
    SUMMARY+=("✅ SSD optimized with TRIM, I/O scheduler, and mount options")
    PERFORMANCE_GAINS+=("🚀 Faster file I/O, extended SSD lifespan")
fi

# --- AMD CPU Performance Optimization ---
if ask "Optimize for AMD Ryzen 5 5500U performance?"; then
    printf "${PURPLE}=== AMD Ryzen Optimization ===${NC}\n"
    
    # Install AMD microcode
    sudo apt install -y amd64-microcode
    
    # Configure CPU governor
    sudo apt install -y cpufrequtils
    echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils > /dev/null
    
    # Set CPU scaling
    sudo tee /etc/systemd/system/cpu-performance.service > /dev/null << 'EOF'
[Unit]
Description=Set CPU Performance Mode
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl enable cpu-performance.service
    
    SUMMARY+=("✅ AMD Ryzen 5 5500U optimized with performance governor")
    PERFORMANCE_GAINS+=("🚀 Better CPU performance and responsiveness")
fi

# --- GPU Performance (AMD Radeon) ---
if ask "Optimize AMD Radeon graphics performance?"; then
    printf "${PURPLE}=== AMD Radeon Graphics Optimization ===${NC}\n"
    
    # Install Mesa drivers
    sudo apt install -y mesa-vulkan-drivers mesa-utils
    
    # Enable performance mode for AMD GPU
    sudo tee /etc/modprobe.d/amdgpu.conf > /dev/null << 'EOF'
options amdgpu ppfeaturemask=0xffffffff
EOF
    
    SUMMARY+=("✅ AMD Radeon graphics optimized")
    PERFORMANCE_GAINS+=("🚀 Better graphics performance for development tools")
fi

# --- Essential Development Tools ---
if ask "Install essential development tools and libraries?"; then
    printf "${PURPLE}=== Installing Development Tools ===${NC}\n"
    
    sudo apt install -y \
        build-essential \
        curl wget unzip zip \
        htop btop neofetch \
        net-tools tree \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        cmake \
        pkg-config \
        libssl-dev \
        zlib1g-dev \
        libbz2-dev \
        libreadline-dev \
        libsqlite3-dev \
        libffi-dev \
        liblzma-dev
    
    SUMMARY+=("✅ Essential development tools and libraries installed")
fi

# --- Git Configuration ---
if ask "Install and configure Git?"; then
    sudo apt install -y git git-lfs
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    git config --global core.autocrlf input
    SUMMARY+=("✅ Git installed with optimized configuration")
fi

# --- Python Development Environment ---
if ask "Set up Python development environment?"; then
    printf "${PURPLE}=== Setting up Python Environment ===${NC}\n"
    
    sudo apt install -y \
        python3 python3-pip python3-venv python3-dev \
        python3-setuptools python3-wheel
    
    # Install pipx for isolated Python apps
    python3 -m pip install --user pipx
    python3 -m pipx ensurepath
    
    # Install common Python tools
    pipx install black
    pipx install flake8
    pipx install mypy
    pipx install poetry
    
    SUMMARY+=("✅ Python development environment with pipx and tools")
fi

# --- Node.js & Modern JavaScript ---
if ask "Install Node.js (LTS) with performance optimizations?"; then
    printf "${PURPLE}=== Installing Node.js Environment ===${NC}\n"
    
    # Install Node.js LTS
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs
    
    # Configure npm for performance
    npm config set fund false
    npm config set audit-level moderate
    npm install -g npm@latest
    
    # Install global tools
    npm install -g \
        yarn \
        pnpm \
        typescript \
        @typescript-eslint/parser \
        prettier \
        nodemon \
        pm2
    
    SUMMARY+=("✅ Node.js with performance optimizations and modern tools")
fi

# --- Docker with Performance Tweaks ---
if ask "Install Docker with performance optimizations?"; then
    printf "${PURPLE}=== Installing Optimized Docker ===${NC}\n"
    
    # Install Docker
    sudo apt install -y ca-certificates gnupg lsb-release
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    # Optimize Docker daemon
    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "storage-opts": [
        "overlay2.override_kernel_check=true"
    ]
}
EOF
    
    sudo systemctl restart docker
    
    SUMMARY+=("✅ Docker with performance optimizations (logout/login required)")
    PERFORMANCE_GAINS+=("🚀 Optimized Docker daemon configuration")
fi

# --- Modern Code Editors ---
if ask "Install Visual Studio Code and Neovim?"; then
    printf "${PURPLE}=== Installing Code Editors ===${NC}\n"
    
    # VS Code
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/
    sudo sh -c 'echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    rm -f packages.microsoft.gpg
    sudo apt update && sudo apt install -y code
    
    # Neovim
    sudo apt install -y neovim
    
    SUMMARY+=("✅ VS Code and Neovim installed")
fi

# --- Database Systems ---
if ask "Install PostgreSQL and Redis?"; then
    printf "${PURPLE}=== Installing Database Systems ===${NC}\n"
    
    # PostgreSQL
    sudo apt install -y postgresql postgresql-contrib postgresql-client
    
    # Redis
    sudo apt install -y redis-server
    sudo systemctl enable redis-server
    
    SUMMARY+=("✅ PostgreSQL and Redis installed")
fi

# --- GNOME Performance Optimization ---
if ask "Apply GNOME performance optimizations?"; then
    printf "${PURPLE}=== Optimizing GNOME Desktop ===${NC}\n"
    
    # Install GNOME tweaks
    sudo apt install -y gnome-tweaks gnome-shell-extensions
    
    # Performance settings
    gsettings set org.gnome.desktop.interface enable-animations false
    gsettings set org.gnome.desktop.interface gtk-enable-primary-paste false
    gsettings set org.gnome.desktop.privacy remember-recent-files false
    gsettings set org.gnome.desktop.privacy recent-files-max-age 1
    gsettings set org.gnome.desktop.search-providers disable-external true
    gsettings set org.gnome.desktop.privacy report-technical-problems false
    
    # Disable telemetry
    gsettings set org.gnome.desktop.privacy send-software-usage-stats false
    
    # Power settings for performance
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 1800
    
    SUMMARY+=("✅ GNOME desktop optimized for performance")
    PERFORMANCE_GAINS+=("🚀 Faster desktop animations, reduced resource usage")
fi

# --- Firewall Configuration ---
if ask "Configure UFW firewall for development?"; then
    printf "${PURPLE}=== Configuring Firewall ===${NC}\n"
    
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Common development ports
    sudo ufw allow 22    # SSH
    sudo ufw allow 80    # HTTP
    sudo ufw allow 443   # HTTPS
    sudo ufw allow 3000  # React/Node dev server
    sudo ufw allow 5432  # PostgreSQL
    sudo ufw allow 6379  # Redis
    sudo ufw allow 8000  # Django/Flask dev server
    
    sudo ufw --force enable
    SUMMARY+=("✅ UFW firewall configured for development")
fi

# --- System Monitoring Tools ---
if ask "Install system monitoring and analysis tools?"; then
    printf "${PURPLE}=== Installing Monitoring Tools ===${NC}\n"
    
    sudo apt install -y \
        htop btop \
        iotop \
        nethogs \
        ncdu \
        inxi \
        hardinfo \
        stress \
        s-tui \
        powertop \
        tlp tlp-rdw
    
    # Configure TLP for laptop power management
    sudo systemctl enable tlp
    sudo systemctl start tlp
    
    SUMMARY+=("✅ System monitoring and power management tools installed")
fi

# --- Zsh Shell (Optional) ---
if ask "Install and configure Zsh with Oh My Zsh?"; then
    printf "${PURPLE}=== Setting up Zsh ===${NC}\n"
    
    sudo apt install -y zsh
    
    # Install Oh My Zsh
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        
        # Install useful plugins
        git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
        
        # Configure .zshrc
        sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting docker docker-compose npm node python)/' ~/.zshrc
    fi
    
    SUMMARY+=("✅ Zsh with Oh My Zsh and plugins installed")
fi

# --- Clean Up ---
printf "${YELLOW}=== Final Cleanup ===${NC}\n"
sudo apt autoremove -y && sudo apt autoclean
sudo updatedb 2>/dev/null || true
SUMMARY+=("✅ Final system cleanup completed")

# --- Performance Summary Report ---
printf "\n${GREEN}=== 📊 OPTIMIZATION SUMMARY REPORT ===${NC}\n"
printf "${BLUE}Hardware: Dell Inspiron 5415 | AMD Ryzen 5 5500U | 16GB RAM${NC}\n\n"

printf "${CYAN}=== Changes Applied ===${NC}\n"
for item in "${SUMMARY[@]}"; do
    printf "  %s\n" "$item"
done

if [ ${#PERFORMANCE_GAINS[@]} -gt 0 ]; then
    printf "\n${PURPLE}=== Performance Improvements ===${NC}\n"
    for gain in "${PERFORMANCE_GAINS[@]}"; do
        printf "  %s\n" "$gain"
    done
fi

printf "\n${YELLOW}=== Next Steps ===${NC}\n"
printf "  🔄 Restart your system to apply all optimizations\n"
printf "  🐳 Re-login to use Docker without sudo\n"
printf "  ⚡ Run 'sudo tlp start' after reboot for power management\n"
printf "  📊 Use 'btop' for system monitoring\n"
printf "  🔧 Configure your development tools and IDE extensions\n"

printf "\n${GREEN}=== 🎉 OPTIMIZATION COMPLETE! ===${NC}\n"
printf "${RED}⚠️  REBOOT REQUIRED FOR FULL EFFECT${NC}\n"
