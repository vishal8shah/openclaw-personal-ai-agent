# Security-Hardened Deployment Guide

Complete walkthrough from WSL2 setup to a fully hardened personal AI agent deployment.

**Model tested against:** OpenAI Codex (GPT-5.4) — *See [docs.openclaw.ai](https://docs.openclaw.ai) for current model support.*

!!! tip
    A full five-layer observability stack accompanies this guide. See the [Observability Guide](observability.md) for Prometheus, Grafana, Tempo, and cost monitoring.

---

## Part 1 — Prerequisites

### 1.1 Hardware

Any x86-64 machine running Windows 10/11. A recycled laptop works perfectly.

- Windows 10/11 (WSL2 capable)
- ChatGPT Plus account (for OpenAI Codex / GPT-5.4 via OAuth)
- Telegram account (for bot creation via @BotFather)
- Basic comfort with a Linux terminal

### 1.2 Install WSL2 + Ubuntu

```powershell
# PowerShell as Administrator
wsl --install
wsl --set-default-version 2
```

Open Ubuntu from Start, then:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git nano ufw dnsutils
```

### 1.3 WSL2 DNS Hardening

WSL2 regenerates `/etc/resolv.conf` on every restart by default. This can break Telegram API resolution after system updates.

```bash
# Prevent WSL2 from overwriting DNS
echo -e "[network]\ngenerateResolvConf = false" | sudo tee /etc/wsl.conf

# Set static DNS
sudo rm /etc/resolv.conf
echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" | sudo tee /etc/resolv.conf

# Lock the file
sudo chattr +i /etc/resolv.conf
```

Verify:

```bash
cat /etc/resolv.conf          # Should show 8.8.8.8
dig api.telegram.org          # Should resolve
```

!!! note
    OpenAI APIs and other external services also depend on reliable DNS. This fix resolves both.

---

## Part 2 — Install OpenClaw

```bash
# Review the install script before running (always)
curl -fsSL https://openclaw.ai/install.sh -o install.sh
less install.sh
bash install.sh
source ~/.bashrc

# Verify installation
openclaw --version
openclaw doctor
```

---

## Part 3 — Security Configuration

### 3.1 Onboarding Wizard

```bash
openclaw onboard --install-daemon
```

When prompted:

- Select **OpenAI Codex** as your AI provider
- Authenticate via **ChatGPT Plus OAuth** (no API key needed for Plus users)
- Configure your Telegram bot token (from @BotFather)
- Enable **gateway as background service**

### 3.2 Authentication Token

```bash
openclaw auth token generate --length 64
```

64 characters = 384 bits of entropy.

### 3.3 Channel Allowlist

```bash
# Get your Telegram chat ID
openclaw telegram get-chat-id

# Lock to your DM only
openclaw config set security.allowedChannels '["telegram:YOUR_CHAT_ID"]'
openclaw config set security.requireDMPairing true
```

### 3.4 Tool Policy

```bash
openclaw config set tools.policy.mode "allowlist"
openclaw config set tools.policy.allowedTools '["read_file","write_file","run_command","search_web"]'
```

---

## Part 4 — Credential Security

### 4.1 File Permissions

```bash
chmod 600 ~/.openclaw/openclaw.json
chmod 600 ~/.openclaw/auth-profiles.json
chmod 700 ~/.openclaw/

# Verify
ls -la ~/.openclaw/
```

### 4.2 Spend Cap

For ChatGPT Plus users, Codex quota is managed by your Plus subscription (5 hrs/day). For API key users set a hard limit at platform.openai.com: **Billing → Usage limits → Hard limit**.

### 4.3 Key Rotation Protocol

```bash
# Rotate OpenClaw auth token
openclaw auth token rotate

# For API key users
openclaw config set providers.openai.apiKey "sk-..."
```

Rotation schedule: rotate if a device is lost, a key is exposed, or quarterly as routine hygiene.

---

## Part 5 — Supply Chain Security

See the full [Skills Guide](skills.md) for safe skill installation.

- **Review before install** — check clawhub.ai for community feedback and version history
- **Never install from unreviewed sources** — the ClawHavoc campaign showed how easy it is to publish malicious skills
- **Version-pin** — use the lockfile at `.clawhub/lock.json`
- **Update consciously** — review changelogs before `clawhub update`

---

## Part 6 — Sandbox Mode (Docker)

```bash
# Install Docker
sudo apt install -y docker.io
sudo usermod -aG docker $USER
# Log out and back in, then:
docker run hello-world

# Enable sandbox
openclaw config set sandbox.enabled true
openclaw config set sandbox.driver "docker"
openclaw config set sandbox.docker.networkMode "none"
openclaw config set sandbox.docker.readOnlyRootFilesystem true
```

Verify:

```bash
openclaw security audit --deep
```

---

## Part 7 — Physical Network Isolation

```
Internet → ISP Modem → [Home Router]  → Home devices
                              └→ [Agent Router] → Agent laptop (WSL2)
```

Any consumer router with a guest network or separate SSID achieves this.

---

## Part 8 — UFW Firewall

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw enable
sudo ufw status verbose
```

The gateway binds to loopback only (`127.0.0.1:18789`) by default — zero external surface even without UFW.

```bash
# Confirm loopback binding
ss -tlnp | grep 18789
```

---

## Part 9 — Health Monitoring

```bash
openclaw health --json
openclaw doctor
```

For external crash detection, use [healthchecks.io](https://healthchecks.io):

```bash
# Add to crontab (every 5 minutes)
*/5 * * * * /usr/local/bin/openclaw health --quiet && curl -fsS https://hc-ping.com/YOUR_UUID
```

!!! tip
    For the full observability stack see the [Observability Guide](observability.md).

---

## Part 10 — Security Audit

```bash
openclaw security audit --deep
openclaw doctor
ss -tlnp
sudo ufw status verbose
ls -la ~/.openclaw/
```

---

## Security Checklist

=== "Authentication"
    - [ ] 64-char auth token generated
    - [ ] Channel allowlist restricted to your Telegram DM
    - [ ] DM pairing enabled

=== "Network"
    - [ ] UFW enabled with default deny inbound
    - [ ] Gateway binding confirmed on loopback only (`127.0.0.1:18789`)
    - [ ] DNS hardening applied

=== "Credentials"
    - [ ] `openclaw.json` permissions: `chmod 600`
    - [ ] `auth-profiles.json` permissions: `chmod 600`
    - [ ] Billing limit set (API key users)
    - [ ] Rotation protocol documented

=== "Sandbox"
    - [ ] Docker installed and accessible
    - [ ] Sandbox mode enabled (docker, no network)
    - [ ] Security audit passes: `openclaw security audit --deep`

=== "Supply Chain"
    - [ ] Only reviewed skills installed
    - [ ] Lockfile committed (`.clawhub/lock.json`)

=== "Monitoring"
    - [ ] healthchecks.io external ping configured
    - [ ] Observability stack deployed
    - [ ] Alert thresholds calibrated
