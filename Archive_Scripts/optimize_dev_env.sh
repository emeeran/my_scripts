#!/bin/bash

# Optimize System for Development Environment
# Script designed for Dell Inspiron 5415 with Ubuntu 24.04.2 LTS

echo "Starting system optimization for development environment..."

# Step 1: Update and Upgrade System
echo "Updating and upgrading system packages..."
sudo apt update && sudo apt upgrade -y

# Step 2: Install Essential Development Tools
echo "Installing essential development tools..."
sudo apt install -y build-essential git curl wget vim htop tmux tree zsh

# Step 3: Install Node.js and npm (for JavaScript/Node.js development)
echo "Installing Node.js and npm..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Step 4: Install Python and pip (for Python development)
echo "Installing Python and pip..."
sudo apt install -y python3 python3-pip python3-venv

# Step 5: Install Docker (for containerized development)
echo "Installing Docker..."
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker $USER

# Step 6: Install Visual Studio Code (for IDE support)
echo "Installing Visual Studio Code..."
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
sudo sh -c 'echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
sudo apt update
sudo apt install -y code

# Step 7: Install Oh My Zsh (for enhanced terminal experience)
echo "Installing Oh My Zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Step 8: Enable Swap File (if not already enabled)
echo "Enabling swap file..."
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Step 9: Optimize SSD Performance
echo "Optimizing SSD performance..."
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf

# Step 10: Clean Up Unnecessary Packages
echo "Cleaning up unnecessary packages..."
sudo apt autoremove -y
sudo apt clean

# Final Message
echo "System optimization complete!"
echo "Please reboot your system to apply all changes."
