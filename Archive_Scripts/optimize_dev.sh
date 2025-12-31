#!/bin/bash

set -e
echo "🛠️ Starting clean and robust system optimization for development..."

# Step 1: Update system
echo "📦 Updating system..."
sudo apt update && sudo apt full-upgrade -y

# Step 2: Remove Snap (optional)
# echo "🧹 Removing Snap and installing Flatpak..."
#sudo apt purge -y snapd || true
#rm -rf ~/snap
#sudo apt install -y flatpak gnome-software-plugin-flatpak

# Step 3: Remove bloatware
echo "❌ Removing GNOME games and unused apps..."
sudo apt purge -y \
  aisleriot gnome-mahjongg gnome-mines gnome-sudoku \
  libreoffice-* thunderbird rhythmbox cheese \
  totem transmission-common simple-scan \
  remmina shotwell || true

# Step 4: Clean system
echo "🧼 Cleaning orphaned packages and journal logs..."
sudo apt autoremove --purge -y
sudo apt clean
sudo journalctl --vacuum-time=5d

# Step 5: Install dev tools (skip already installed)
echo "⚙️ Installing core development tools..."
sudo apt install -y \
  build-essential curl git wget unzip \
  python3-pip python3-venv python3-dev \
  sqlite3 postgresql postgresql-contrib \
  flatpak gnome-software-plugin-flatpak \
  neofetch htop net-tools gnome-tweaks gnome-shell-extensions

# Step 6: Fix Node.js installation cleanly
echo "🔧 Installing Node.js LTS (fixing conflicts)..."
sudo apt purge -y nodejs npm
sudo rm -rf /etc/apt/sources.list.d/nodesource.list /usr/lib/node_modules ~/.npm ~/.nvm

curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs
sudo npm install -g n && sudo n lts

# Step 7: Docker install (fix containerd conflict)
echo "🐳 Installing Docker CE and Docker Compose (clean method)..."

# Remove conflicting Ubuntu docker packages
sudo apt purge -y docker.io docker-doc docker-compose containerd runc || true
sudo apt autoremove -y

# Install Docker CE from Docker repo
#sudo install -m 0755 -d /etc/apt/keyrings
#curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
 # sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

#echo \
#  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
#  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
 # | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

#sudo apt update
#sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable Docker
#sudo systemctl enable --now docker

# Step 8: Enable ZRAM
echo "🔄 Enabling ZRAM compressed swap..."
sudo apt install -y zram-tools
echo -e "ALGO=lz4\nPERCENT=50" | sudo tee /etc/default/zramswap
sudo systemctl enable --now zramswap.service

# Step 9: GNOME optimization
echo "🎛️ Optimizing GNOME settings..."
gsettings set org.gnome.desktop.interface enable-animations false
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'

# Step 10: UFW Firewall

echo "🛡️ Setting up UFW firewall..."
sudo ufw --force enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp

# Final Summary
echo -e "\n✅ All done!"
echo "👉 Reboot recommended: sudo reboot"
echo "👉 Use 'gnome-tweaks' to refine your GNOME desktop"

