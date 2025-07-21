#!/bin/bash

set -e

# Get the primary network interface
interface=$(ip route | grep default | awk '{print $5}')
if [ -z "$interface" ]; then
    echo "Unable to determine the default network interface. Please check your network connection." >&2
    exit 1
fi

# Get IP address, prefix, and gateway
ip_info=$(ip -4 addr show "$interface" | grep -oP 'inet \K[\d.]+/\d+')
ip_address=${ip_info%/*}
prefix=${ip_info#*/}
gateway=$(ip route | grep default | awk '{print $3}')

# Get DNS from systemd-resolved
dns=$(grep '^nameserver' /run/systemd/resolve/resolv.conf | awk '{print $2}' | head -n 1)
if [ -z "$dns" ]; then
    echo "Unable to get DNS from /run/systemd/resolve/resolv.conf, defaulting to 8.8.8.8"
    dns="8.8.8.8"
fi

# Backup existing netplan configuration
timestamp=$(date +%Y%m%d%H%M%S)
backup_dir="$HOME/netplan-backup/netplan-backup-$timestamp"
mkdir -p "$backup_dir"
sudo cp -p /etc/netplan/* "$backup_dir/"

# Disable cloud-init configuration if present
if [ -f /etc/netplan/50-cloud-init.yaml ]; then
    echo "Detected 50-cloud-init.yaml. Renaming to disable it..."
    sudo mv /etc/netplan/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml.bak
fi

# Generate new netplan static IP configuration
echo "Generating new /etc/netplan/01-static-ip.yaml..."
cat <<EOF | sudo tee /etc/netplan/01-static-ip.yaml > /dev/null
network:
  version: 2
  ethernets:
    $interface:
      dhcp4: no
      addresses: [$ip_address/$prefix]
      nameservers:
        addresses: [$dns]
      routes:
        - to: default
          via: $gateway
EOF

echo "Please verify the generated config. If correct, run 'sudo netplan try' to test and apply it."
