#!/bin/bash
# OpenClaw Security-Hardened Setup Script
# Run this after WSL2 and OpenClaw are installed
# Usage: bash setup.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🦞 OpenClaw Security Hardening Script${NC}"
echo "========================================"
echo ""

# --- DNS Hardening ---
echo -e "${YELLOW}[1/6] DNS Hardening${NC}"

if grep -q "generateResolvConf = false" /etc/wsl.conf 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} wsl.conf already configured"
else
    echo -e "  Applying wsl.conf settings..."
    sudo tee /etc/wsl.conf > /dev/null << 'EOF'
[network]
generateResolvConf = false
generateHosts = false
EOF
    echo -e "  ${GREEN}✓${NC} wsl.conf updated"
fi

if [ "$(cat /etc/resolv.conf 2>/dev/null | grep -c '8.8.8.8')" -eq 0 ]; then
    sudo chattr -i /etc/resolv.conf 2>/dev/null || true
    sudo rm -f /etc/resolv.conf
    echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" | sudo tee /etc/resolv.conf > /dev/null
    sudo chattr +i /etc/resolv.conf
    echo -e "  ${GREEN}✓${NC} resolv.conf hardened and locked"
else
    echo -e "  ${GREEN}✓${NC} resolv.conf already configured"
fi

# Pin Telegram API to IPv4
if grep -q "api.telegram.org" /etc/hosts 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Telegram API already pinned in /etc/hosts"
else
    TELEGRAM_IP=$(dig api.telegram.org A +short | head -1)
    if [ -n "$TELEGRAM_IP" ]; then
        echo "$TELEGRAM_IP  api.telegram.org" | sudo tee -a /etc/hosts > /dev/null
        echo -e "  ${GREEN}✓${NC} Telegram API pinned to $TELEGRAM_IP"
    else
        echo -e "  ${RED}✗${NC} Could not resolve api.telegram.org — pin manually"
    fi
fi

# --- File Permissions ---
echo -e "${YELLOW}[2/6] Credential File Permissions${NC}"

for f in ~/.openclaw/openclaw.json ~/.openclaw/auth-profiles.json; do
    if [ -f "$f" ]; then
        chmod 600 "$f"
        echo -e "  ${GREEN}✓${NC} $f → 600"
    else
        echo -e "  ${YELLOW}⚠${NC} $f not found (run openclaw onboard first)"
    fi
done

# --- Telemetry ---
echo -e "${YELLOW}[3/6] Disable ClawHub Telemetry${NC}"

if grep -q "CLAWHUB_DISABLE_TELEMETRY" ~/.bashrc 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Telemetry already disabled"
else
    echo 'export CLAWHUB_DISABLE_TELEMETRY=1' >> ~/.bashrc
    echo -e "  ${GREEN}✓${NC} Telemetry disabled in .bashrc"
fi

# --- Docker ---
echo -e "${YELLOW}[4/6] Docker Setup${NC}"

if command -v docker &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} Docker installed: $(docker --version)"
else
    echo -e "  Installing Docker..."
    sudo apt update -qq
    sudo apt install -y -qq docker.io
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker "$USER"
    echo -e "  ${GREEN}✓${NC} Docker installed (log out and back in for group membership)"
fi

# --- UFW Firewall ---
echo -e "${YELLOW}[5/6] Firewall (UFW)${NC}"

if sudo ufw status | grep -q "Status: active"; then
    echo -e "  ${GREEN}✓${NC} UFW already active"
else
    sudo ufw default deny incoming > /dev/null
    sudo ufw default allow outgoing > /dev/null
    sudo ufw allow ssh > /dev/null
    sudo ufw deny 18789 > /dev/null
    echo "y" | sudo ufw enable > /dev/null
    echo -e "  ${GREEN}✓${NC} UFW enabled with hardened rules"
fi

# --- Verification ---
echo -e "${YELLOW}[6/6] Verification${NC}"

echo -e "  DNS:      $(cat /etc/resolv.conf | head -1)"
echo -e "  Immutable: $(lsattr /etc/resolv.conf 2>/dev/null | awk '{print $1}')"
echo -e "  UFW:      $(sudo ufw status | head -1)"

echo ""
echo -e "${GREEN}========================================"
echo -e "Hardening complete."
echo -e "========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Edit ~/.openclaw/openclaw.json with the hardened config from docs/security.md"
echo "  2. Generate gateway token: openssl rand -hex 32"
echo "  3. Restart: sudo systemctl restart openclaw-gateway"
echo "  4. Verify: openclaw doctor && openclaw security audit --deep"
echo "  5. Set up healthchecks.io monitoring (see docs/security.md Part 8)"
