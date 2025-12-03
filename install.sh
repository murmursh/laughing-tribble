#!/bin/bash

# Ensure script is running as root
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root or using sudo."
  exit 1
fi

# --- Environment Setup ---
cd

# 1. Update and Upgrade packages
echo "Updating and upgrading system packages..."
apt update && apt upgrade -y

# 2. Create user 'murmur' and grant passwordless sudo
if ! id "murmur" &>/dev/null; then
    echo "Creating user 'murmur'..."
    # --gecos "" is used to prevent the script from asking for full name, etc.
    adduser --disabled-password --gecos "" murmur
else
    echo "User 'murmur' already exists."
fi

# Get the correct home directory for 'murmur'
MURMUR_HOME=$(getent passwd murmur | cut -d: -f6)

# Configure passwordless sudo via a file in /etc/sudoers.d/
SUDO_CONFIG="/etc/sudoers.d/90-murmur-nopasswd"
if [ ! -f "$SUDO_CONFIG" ]; then
    echo "Configuring passwordless sudo for 'murmur'..."
    echo "murmur ALL=(ALL) NOPASSWD:ALL" > "$SUDO_CONFIG"
    chmod 0440 "$SUDO_CONFIG"
fi

# 3. Configure SSH connection with key 'murmur.pub' (Hardcoded)
SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE1cJBZL3VKQnM7sfDmWSVg7TrK/4Uiw+zVo20pYmc4o murmur@DESKTOP-ESMGGIK"
SSH_DIR="$MURMUR_HOME/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

echo "Setting up SSH key for 'murmur' at $AUTH_KEYS..."
mkdir -p "$SSH_DIR"
echo "$SSH_KEY" > "$AUTH_KEYS"
chmod 700 "$SSH_DIR"
chmod 600 "$AUTH_KEYS"
chown -R murmur:murmur "$SSH_DIR"

# 4. Disable root login to ssh
SSH_CONFIG="/etc/ssh/sshd_config"
echo "Disabling root SSH login by modifying $SSH_CONFIG..."

# Check if PermitRootLogin exists and modify it, otherwise append
# Use /etc/ssh/sshd_config.d/ files if preferred, but modifying the main config is simpler
if grep -qE '^\s*#?\s*PermitRootLogin' "$SSH_CONFIG"; then
    sed -i 's/^\s*#\?\s*PermitRootLogin.*/PermitRootLogin no/' "$SSH_CONFIG"
else
    # Append if the setting isn't found
    echo "PermitRootLogin no" >> "$SSH_CONFIG"
fi

# --- Application Installation (from original script) ---

# Install necessary packages
apt install curl git -y

# Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com | sh
# Add 'murmur' to docker group so they can use docker without sudo
usermod -aG docker murmur 

# Clone repository
REMN_DIR="/home/murmur/remn"
echo "Cloning repository into $REMN_DIR..."

# The original script used mkdir remn && cd remn. We will use mkdir -p to ensure it exists.
mkdir -p "$REMN_DIR"
cd "$REMN_DIR"

# Perform clone
git clone --depth 1 -b node https://github.com/murmursh/laughing-tribble.git

# Go back to original directory if needed later (though script ends here)
cd .. 

# Set ownership of the cloned directory (important for 'murmur' to operate)
chown -R murmur:murmur "$REMN_DIR"
echo "Installation script execution completed. plz relogin as murmur"