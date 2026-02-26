---
layout: default
title: "Troubleshooting"
nav_order: 2
---

# Troubleshooting

Every error below was encountered during real deployment. Every fix was tested.

## Agent not responding on Telegram

```bash
sudo systemctl status openclaw-gateway
sudo journalctl -u openclaw-gateway --since "10 min ago"
curl -v https://api.telegram.org
cat /etc/resolv.conf
```

**Common causes:** DNS overwritten after WSL2 restart, gateway crashed silently, Telegram API resolving to IPv6.

## DNS overwritten after system update

```bash
lsattr /etc/resolv.conf       # Check if immutable flag is still set
sudo chattr +i /etc/resolv.conf   # Re-apply if missing
```

Some Ubuntu packages (notably `resolvconf`) can strip the immutable flag during upgrades.

## openclaw doctor failing

```bash
openclaw config validate
cat ~/.openclaw/openclaw.json | python3 -m json.tool   # Check for JSON syntax errors
```

**Common cause:** Trailing comma in JSON after editing config manually.

## Gateway not starting

```bash
ss -tlnp | grep 18789          # Check if port is already in use
sudo systemctl restart openclaw-gateway
openclaw doctor
```

## Docker permission denied

```bash
docker ps                      # Test if Docker is accessible
sudo systemctl start docker    # Ensure Docker daemon is running
sudo usermod -aG docker $USER  # Add yourself to docker group
```

**Important:** After `usermod`, you must log out and log back in (or restart WSL2) for the group change to take effect permanently. `newgrp docker` only works for the current shell session.

## Sandbox containers failing to start

```bash
docker run hello-world         # Verify Docker itself works
sudo systemctl restart docker
sudo systemctl restart openclaw-gateway
```

## healthchecks.io not receiving pings

```bash
# Test manually
curl -fsS https://hc-ping.com/YOUR_UUID
# Check crontab is correct
crontab -l
# Check if openclaw health itself is failing
openclaw health --json
```
