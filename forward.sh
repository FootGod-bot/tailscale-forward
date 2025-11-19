#!/bin/bash

# Ask for TrueNAS LAN IP
read -p "Enter the local IP of your TrueNAS server (e.g., 192.168.1.123): " TRUENAS_IP

# Enable IP forwarding for this session
sudo sysctl -w net.ipv4.ip_forward=1

# Set up immediate forwarding for all Tailscale traffic
sudo iptables -t nat -A PREROUTING -s 100.64.0.0/10 -p all -j DNAT --to-destination $TRUENAS_IP
sudo iptables -t nat -A POSTROUTING -s 100.64.0.0/10 -p all -j MASQUERADE

echo "Forwarding is active. Test from a Tailscale device now."
read -p "Press Enter when you've tested and want to make it permanent (or Ctrl+C to exit)..."

# Ask if user wants to make it permanent
read -p "Do you want to make this forwarding permanent? (y/n): " PERMA

if [[ "$PERMA" =~ ^[Yy]$ ]]; then
    # Create script for systemd service
    sudo tee /usr/local/bin/ts-forward.sh > /dev/null <<EOF
#!/bin/bash
sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A PREROUTING -s 100.64.0.0/10 -p all -j DNAT --to-destination $TRUENAS_IP
iptables -t nat -A POSTROUTING -s 100.64.0.0/10 -p all -j MASQUERADE
EOF

    sudo chmod +x /usr/local/bin/ts-forward.sh

    # Create systemd service
    sudo tee /etc/systemd/system/ts-forward.service > /dev/null <<EOF
[Unit]
Description=Tailscale to TrueNAS Forwarding
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ts-forward.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start the service
    sudo systemctl enable ts-forward.service
    sudo systemctl start ts-forward.service

    echo "Forwarding is now permanent and will start on boot."
else
    echo "Forwarding is active for this session only. It will be lost on reboot."
fi
