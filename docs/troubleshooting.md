---
layout: default
title: "Troubleshooting"
nav_order: 3
---

# Troubleshooting

Every error below was encountered during real deployment. Every fix was tested.

---

## Agent not responding on Telegram

```bash
openclaw gateway status
openclaw logs --follow
curl -v https://api.telegram.org
cat /etc/resolv.conf
```

**Common causes:** DNS overwritten after WSL2 restart, gateway crashed silently, Telegram API resolving to IPv6.

---

## DNS overwritten after system update

```bash
# Check if resolv.conf is still a real file
ls -la /etc/resolv.conf

# If it's been reverted to a symlink, recreate:
sudo rm /etc/resolv.conf
echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" | sudo tee /etc/resolv.conf

# Optionally re-apply immutable flag if supported:
sudo chattr +i /etc/resolv.conf
```

Verify that `/etc/wsl.conf` still contains `generateResolvConf = false` — this is the primary permanent fix.

---

## Config validation failing

```bash
# Use OpenClaw's built-in validation (supports JSON5)
openclaw doctor
```

**Important:** Do not use `python3 -m json.tool` for config validation. OpenClaw config is JSON5 (supports comments and trailing commas), which strict JSON parsers will reject as invalid.

**Common cause:** Trailing comma or misplaced key after editing config manually. Use `openclaw config set` for individual changes instead of hand-editing.

---

## Gateway not starting

```bash
ss -tlnp | grep 18789          # Check if port is already in use
openclaw gateway restart
openclaw doctor
```

---

## Docker permission denied

```bash
docker ps                      # Test if Docker is accessible
sudo systemctl start docker    # Ensure Docker daemon is running
sudo usermod -aG docker $USER  # Add yourself to docker group
```

**Important:** After `usermod`, you must log out and log back in (or restart WSL2) for the group change to take effect permanently. `newgrp docker` only works for the current shell session.

---

## Sandbox containers failing to start

```bash
docker run hello-world         # Verify Docker itself works
sudo systemctl restart docker
openclaw gateway restart
```

---

## Codex quota exhausted

```bash
# Check remaining Codex quota
# ChatGPT web → Codex → Settings → Usage
# Plus: 5 hrs/day | Pro: 25 hrs/day

# Restart gateway to clear any internal cooldown
openclaw gateway stop
sleep 5
openclaw gateway start

# Confirm the active model is correctly set
cat ~/.openclaw/openclaw.json | grep -A3 '"model"'
# Should show: "primary": "openai-codex/gpt-5.4"

# Set a lighter fallback model for cron jobs to preserve quota
openclaw models set openai-codex/gpt-5.4 --fallback openai-codex/gpt-4.1-mini
```

**Note:** The gateway overwrites per-agent `models.json` on every start. Always set the model in `~/.openclaw/openclaw.json` (the source of truth) — not in the per-agent cache file.

---

## Model config reverts after gateway restart

```bash
# WRONG — this file is overwritten by the gateway on every start
nano ~/.openclaw/agents/main/agent/models.json

# CORRECT — edit the source of truth
nano ~/.openclaw/openclaw.json
# Set: agents.defaults.model.primary = "openai-codex/gpt-5.4"

# Always stop the gateway before editing, then start fresh
openclaw gateway stop
# ...edit openclaw.json...
openclaw gateway start
```

---

## healthchecks.io not receiving pings

```bash
# Test manually
curl -fsS https://hc-ping.com/YOUR_UUID
# Check crontab is correct
crontab -l
# Check if openclaw health itself is failing
openclaw health --json
```

---

## Related guides

- 📖 [Security Guide](security) — hardening, config reference, security checklist
- 📊 [Observability Guide](observability) — Prometheus, Grafana, Tempo, cost monitoring
- 🧩 [Skills Guide](skills) — safe skill installation and version pinning
