---
layout: default
title: "Complete Setup & Security Guide"
nav_order: 1
---

# 🦞 OpenClaw Personal AI Agent — Complete Setup & Security Guide

> **Self-hosted AI agent deployment with defence-in-depth hardening on WSL2 Ubuntu**
>
> **Version:** 2026.2.21-2 | **Platform:** Windows WSL2 + Ubuntu | **Model:** Google Gemini 3.1 Flash

---

## About This Guide

This guide documents a production-grade, security-hardened deployment of OpenClaw — a self-hosted personal AI agent that runs on your own hardware, connects via Telegram, and executes tasks using AI models like Google Gemini.

In early 2026, security researchers discovered tens of thousands of publicly accessible OpenClaw instances running with default configurations — the vast majority with authentication bypasses, gateways exposed on every network interface, and no encryption at rest. The ClawHavoc campaign saw hundreds of malicious skills published to ClawHub, and an independent Snyk study found a significant percentage of ClawHub skills leak credentials in plaintext.

This guide was built the hard way — through real deployment, real errors, and real fixes — so you don't have to.

---

## Prerequisites

Before starting, gather the following:

- Windows 10/11 machine (spare laptop is ideal — runs 24/7 at near-zero cost)
- Google account (for Gemini API key via [Google AI Studio](https://aistudio.google.com))
- Telegram account (for bot creation via @BotFather)
- Basic comfort with a Linux terminal

---

## The Threat Model

Understand what you're defending against before touching any configuration:

| Threat | Attack Vector | Risk |
|---|---|---|
| Exposed gateway | Bound to 0.0.0.0, scannable by Shodan | Critical |
| Unauthenticated access | No token auth — anyone with local IP has control | Critical |
| Malicious skills | ClawHavoc credential-stealing skills on ClawHub | High |
| Prompt injection | Malicious content hijacking agent via web/email | High |
| DNS poisoning | WSL2 IPv6/IPv4 race condition, MITM risk | Medium |
| Credential exposure | API keys in plaintext world-readable files | High |
| Runaway agent | Infinite loop draining API spend balance | Medium |
| Supply chain attack | Compromised skill update via `latest` tag | High |
| Network discovery | mDNS broadcasting agent presence on LAN | Medium |
| Silent failure | Crashed agent undetected for hours | Low-Medium |

---

## Part 1 — Environment Setup

### 1.1 Enable WSL2 on Windows

Open PowerShell as Administrator:

```powershell
wsl --install
wsl --set-default-version 2
```

Restart your machine when prompted. After restart, Ubuntu will finish installing and ask you to create a Linux username and password.

**Why WSL2:** It runs a full Linux kernel in a lightweight VM, giving OpenClaw a proper POSIX environment with process isolation from the Windows host. Running an AI agent directly on Windows without this isolation is a security antipattern — file permissions, process separation, and credential storage all work correctly in Linux in ways they do not on Windows natively.

**Verify:**

```bash
wsl --list --verbose
# Should show Ubuntu with Version 2
```

---

### 1.2 Update Ubuntu

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git nano ufw
```

---

### 1.3 WSL2 DNS Hardening — The Step Most Guides Skip

**This is one of the most overlooked security and stability configurations for WSL2 deployments.**

By default, WSL2 regenerates `/etc/resolv.conf` and `/etc/hosts` on every reboot. This creates two serious risks:

1. **Network instability** — WSL2's auto-generated DNS sometimes points to an unreachable address, causing your agent to lose connectivity to Telegram and Gemini APIs silently
2. **IPv6/IPv4 race condition** — WSL2 sometimes resolves `api.telegram.org` to an IPv6 address that Windows cannot route, causing connection failures that are extremely difficult to diagnose

**Step 1 — Disable WSL2 auto-generation:**

```bash
sudo nano /etc/wsl.conf
```

Paste exactly:

```ini
[network]
generateResolvConf = false
generateHosts = false
```

Save: `Ctrl+X` → `Y` → `Enter`

**Step 2 — Remove the WSL2 symlink and create a static DNS file:**

```bash
sudo rm /etc/resolv.conf
sudo nano /etc/resolv.conf
```

Paste:

```
nameserver 8.8.8.8
nameserver 8.8.4.4
```

**Step 3 — Make it immutable:**

```bash
sudo chattr +i /etc/resolv.conf
```

**Why `chattr +i`:** Without this flag, even with `generateResolvConf = false`, some Ubuntu packages (including `resolvconf`) can still overwrite the file. The immutable flag is the final guarantee that nothing touches your DNS config.

**Step 4 — Pin Telegram API to IPv4:**

First, verify the current IPv4 address for Telegram's API:

```bash
dig api.telegram.org A +short
```

Then pin the resolved address (replace with the IP from the command above if different):

```bash
echo "149.154.167.220  api.telegram.org" | sudo tee -a /etc/hosts
```

> **Maintenance note:** Telegram's API IPs can change. Re-verify with `dig api.telegram.org A` quarterly or if you experience connectivity issues.

**Step 5 — Restart WSL2 from PowerShell to apply `wsl.conf`:**

```powershell
wsl --shutdown
```

Then reopen Ubuntu.

**Verify everything:**

```bash
cat /etc/resolv.conf          # Should show 8.8.8.8
lsattr /etc/resolv.conf       # Should show ----i--- flag
curl -v https://api.telegram.org   # Should resolve to IPv4
```

---

## Part 2 — OpenClaw Installation

### 2.1 Install OpenClaw

> **Security note:** Piping remote scripts directly into bash (`curl | bash`) is convenient but skips inspection. The commands below download first, let you review, then execute.

```bash
curl -fsSL https://get.openclaw.ai -o install.sh
less install.sh               # Review the script before running
bash install.sh
source ~/.bashrc

# Verify
openclaw --version
# Should show: OpenClaw 2026.x.x or similar
```

### 2.2 Run Initial Setup Wizard

```bash
openclaw onboard
```

During onboarding you will configure:
- Your AI model provider (select Google / Gemini)
- Your Gemini API key (get from [aistudio.google.com](https://aistudio.google.com) → Get API Key)
- Your Telegram bot token (get from @BotFather on Telegram → `/newbot`)
- Your workspace directory

**Getting your Telegram user ID** — message @userinfobot on Telegram. It replies instantly with your numeric user ID. Save this — you'll need it for the allowlist config.

---

## Part 3 — Security Configuration

> This is where most deployments fail. The default OpenClaw config is optimised for getting started fast, not for security. Every setting below has a documented reason.

All configuration lives in:

```bash
nano ~/.openclaw/openclaw.json
```

Apply this complete hardened configuration:

```json
{
  "meta": {
    "lastTouchedVersion": "2026.2.x"
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "google/gemini-3.1-flash"
      },
      "workspace": "~/.openclaw/workspace",
      "tools": {
        "policy": "allowlist",
        "allowed": ["search", "read_file", "send_message", "browse_web"]
      },
      "sandbox": {
        "enabled": true,
        "mode": "all",
        "docker": {
          "network": "none",
          "workspaceAccess": "ro"
        }
      }
    }
  },
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "loopback",
    "mDNS": {
      "enabled": false
    },
    "auth": {
      "mode": "token",
      "token": "YOUR_GENERATED_TOKEN_HERE"
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "YOUR_BOT_TOKEN_HERE",
      "groupPolicy": "allowlist",
      "dmPolicy": "pairing",
      "allowFrom": ["YOUR_TELEGRAM_USER_ID_HERE"],
      "denyByDefault": true,
      "streaming": false,
      "network": {
        "autoSelectFamily": true
      }
    }
  },
  "skills": {
    "nano-pdf": {
      "version": "PINNED_VERSION_HERE"
    },
    "playwright-mcp": {
      "version": "PINNED_VERSION_HERE"
    }
  }
}
```

### Why Each Security Setting Matters

| Setting | What It Does | Without It |
|---|---|---|
| `bind: loopback` | Gateway only listens on 127.0.0.1 | Scannable by Shodan within hours |
| `auth.mode: token` | Requires 64-char token for all API calls | Any local process controls your agent |
| `mDNS: false` | Agent invisible to network scanners | Every LAN device discovers your agent |
| `denyByDefault: true` | Bot ignores all unknown senders | Anyone who finds your bot can command it |
| `allowFrom: [yourID]` | Only your Telegram ID is authorised | Any Telegram user can interact |
| `groupPolicy: allowlist` | Bot ignores group chats | Group members can inject commands |
| `dmPolicy: pairing` | New DMs require explicit approval | Unknown users bypass your allowlist |
| `tools.policy: allowlist` | Only listed tools are callable | Compromised agent can do anything |
| `sandbox.enabled: true` | Tool calls run in Docker isolation | Malicious code accesses host filesystem |
| `sandbox.network: none` | Sandboxed containers have no network | Malicious code can exfiltrate data |
| Skill version pinning | Fixed version, no auto-updates | Compromised skill update auto-installed |

**Generate your gateway token:**

```bash
openssl rand -hex 32
# Outputs a 64-character cryptographically random token
# Paste this into the "token" field above
```

After editing config:

```bash
sudo systemctl restart openclaw-gateway
openclaw doctor
```

---

## Part 4 — Credential Security

### 4.1 File Permissions

```bash
chmod 600 ~/.openclaw/openclaw.json
chmod 600 ~/.openclaw/auth-profiles.json

# Verify
ls -la ~/.openclaw/
# Both files should show: -rw------- (owner read/write only)
```

**Why `chmod 600`:** Default file creation on Linux is 644 — world-readable. Your bot token and Gemini API key are sitting in those files. `chmod 600` means only your user account can read them. No other process, no accidental terminal output visible in logs, no world-readable credentials.

### 4.2 Disable ClawHub Telemetry

```bash
echo 'export CLAWHUB_DISABLE_TELEMETRY=1' >> ~/.bashrc
source ~/.bashrc
```

**Why:** ClawHub telemetry sends install snapshots on every skill operation, including environment metadata. Disabling it eliminates a background data exfiltration channel you may not have consented to.

> **Note:** Verify the exact environment variable name in the [OpenClaw documentation](https://openclaw.ai/docs) for your installed version, as it may vary between releases.

### 4.3 API Spend Cap

1. Go to [aistudio.google.com](https://aistudio.google.com)
2. Navigate to your project → **Billing** → **Set budget alert**
3. Set daily limit: AUD $2–5/day (sufficient for heavy personal use)
4. Enable email alerts at 50% and 90% of limit

**Why:** A runaway agent in an infinite loop can exhaust your API balance in under an hour without a cap. Gemini Flash is cheap per token — but thousands of accidental loop iterations are not. This is your financial circuit breaker.

### 4.4 Key Rotation Protocol

If your API key is ever visible in terminal output, a screenshot, a log file, or a chat message — rotate it immediately. Exposed API keys are typically exploited within minutes.

```bash
# Gemini: aistudio.google.com → API Keys → Delete old → Create new
# Telegram: @BotFather → /revoke → regenerate token
# Then update ~/.openclaw/auth-profiles.json with new values
```

---

## Part 5 — Skill Installation (Security-First Approach)

### 5.1 Only Install Verified Skills

The ClawHavoc campaign placed hundreds of malicious skills on ClawHub — the majority from a single coordinated attacker. Always check before installing:

```bash
# Review skill details before installing
clawdhub info SKILL_NAME

# Check VirusTotal verification badge in output
# Look for: "Verified: true" and "ClawHavoc: clean"
```

### 5.2 Install Approved Skills

```bash
clawdhub install nano-pdf
clawdhub install playwright-mcp
```

Both are verified clean. nano-pdf enables document analysis; playwright-mcp enables web automation.

### 5.3 Verify Installed Versions For Pinning

```bash
clawdhub list --installed
# Note the exact version numbers
# Update the "skills" section of openclaw.json with these versions
```

**Why version pinning:** If you run `latest`, a compromised update is automatically pulled on next restart. The ClawHavoc campaign exploited this exact vector. Pinning means you upgrade consciously, on your timeline, after reviewing the changelog.

---

## Part 6 — Sandbox Mode (Docker)

Tool sandboxing is the kernel-level isolation layer. It runs every tool call inside a Docker container — if a malicious skill or injected prompt executes code, it is trapped with no host filesystem access, no network, and no ability to touch your credentials.

### 6.1 Install Docker in WSL2

```bash
sudo apt update
sudo apt install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker

# Add yourself to docker group (removes need for sudo)
sudo usermod -aG docker $USER
newgrp docker

# Verify
docker --version
docker run hello-world
```

> **Note:** `newgrp docker` only applies to the current shell session. For a permanent fix, log out and log back in (or restart WSL2 with `wsl --shutdown`). Otherwise you'll hit permission errors in new terminal windows.

### 6.2 Apply Sandbox Config

Already included in the hardened `openclaw.json` above. Verify it's present:

```bash
grep -A6 "sandbox" ~/.openclaw/openclaw.json
```

**Critical:** Never set `"network": "host"` in sandbox config. It defeats isolation entirely and is blocked by OpenClaw's security defaults.

```bash
sudo systemctl restart openclaw-gateway
openclaw doctor
```

---

## Part 7 — Firewall Hardening (UFW)

UFW adds a third independent network protection layer. Even if OpenClaw config is accidentally changed and the bind address reverts to 0.0.0.0, UFW blocks port 18789 at the kernel level regardless.

```bash
# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH if you need remote access to this machine
sudo ufw allow ssh

# Block gateway port at network level
sudo ufw deny 18789

# Enable
sudo ufw enable

# Verify
sudo ufw status verbose
```

Expected output:

```
Status: active
Default: deny (incoming), allow (outgoing)
18789    DENY IN    Anywhere
```

**Why this matters for defence-in-depth:**
- Layer 1 (Firewall): UFW blocks port 18789 at kernel level
- Layer 2 (Binding): Gateway bound to loopback — no external surface
- Layer 3 (Auth): Token required for all API calls

Any single layer failing does not compromise the system.

---

## Part 8 — Health Monitoring

### 8.1 Built-in Health Check

```bash
# Run after every config change
openclaw doctor

# Deep security audit
openclaw security audit --deep

# JSON output for scripting
openclaw health --json
```

### 8.2 External Monitoring with healthchecks.io

Without external monitoring, a crashed agent is invisible. You only find out when you notice hours later that Telegram stopped responding.

1. Go to [healthchecks.io](https://healthchecks.io) — create a free account
2. Click **Add Check** → **Simple** → Period: **5 minutes**
3. Copy your unique ping URL

```bash
# Add to crontab
crontab -e

# Add this line (replace YOUR_UUID with your healthchecks.io UUID)
*/5 * * * * openclaw health --json > /dev/null 2>&1 && curl -fsS --retry 3 https://hc-ping.com/YOUR_UUID > /dev/null
```

If the agent crashes, healthchecks.io sends you an alert (email or Telegram) within 5 minutes.

### 8.3 Systemd Service Management

```bash
# Check service status
sudo systemctl status openclaw-gateway

# Live logs
sudo journalctl -u openclaw-gateway -f

# Enable auto-start on boot
sudo systemctl enable openclaw-gateway
```

---

## Part 9 — CVE Patch Management

Stay current on security patches. OpenClaw has had critical vulnerabilities — including WebSocket-based remote code execution bugs — that were patched in prior releases. Instances without update alerts stayed vulnerable for weeks after public disclosure.

### 9.1 Subscribe to Security Advisories

1. Go to `github.com/openclaw-ai/openclaw`
2. Click **Watch** → **Custom** → tick **Security alerts**
3. Subscribe to: `github.com/openclaw-ai/openclaw/security/advisories`

### 9.2 Weekly Update Check

```bash
# Manual check
openclaw update check
openclaw update apply   # After reviewing changelog

# Automated weekly check (add to crontab)
crontab -e
# Add:
0 9 * * 1 openclaw update check
```

**Patch SLA:** Apply patches rated CVSS 7.0+ within 24 hours of advisory. CVSS 4.0–6.9 within 7 days.

---

## Security Checklist — Complete Verification

Run through this after full deployment:

```
NETWORK
[ ] Gateway bind: "loopback" — verified with: ss -tlnp | grep 18789
[ ] UFW active: default deny incoming, default allow outgoing
[ ] Port 18789 blocked at UFW level
[ ] mDNS broadcasting disabled in config

AUTHENTICATION
[ ] Gateway auth mode: "token"
[ ] Token generated with: openssl rand -hex 32
[ ] Telegram allowFrom contains ONLY your user ID
[ ] denyByDefault: true set
[ ] groupPolicy: allowlist set
[ ] dmPolicy: pairing set

CREDENTIALS
[ ] openclaw.json permissions: 600 (-rw-------)
[ ] auth-profiles.json permissions: 600 (-rw-------)
[ ] API spend cap set in Google AI Studio
[ ] No API key ever committed to git
[ ] CLAWHUB_DISABLE_TELEMETRY=1 in ~/.bashrc

SKILLS & TOOLS
[ ] Only VirusTotal-verified skills installed
[ ] ClawHavoc-flagged skills declined at install prompt
[ ] Tool allowlist configured (only needed tools enabled)
[ ] Sandbox mode enabled with Docker
[ ] Sandbox network: "none" (no exfiltration path)
[ ] Skill versions pinned (no "latest" tags)

DNS (WSL2 SPECIFIC)
[ ] generateResolvConf=false in /etc/wsl.conf
[ ] generateHosts=false in /etc/wsl.conf
[ ] /etc/resolv.conf immutable: lsattr shows ----i---
[ ] api.telegram.org pinned to IPv4 in /etc/hosts
[ ] DNS verified after WSL2 restart

MONITORING
[ ] openclaw doctor passing clean
[ ] openclaw security audit --deep passing
[ ] External health check via healthchecks.io active
[ ] Cron ping job running every 5 minutes
[ ] GitHub security advisories subscribed
[ ] Patch schedule: CVSS 7.0+ within 24h

GIT / PUBLISHING
[ ] .gitignore committed first, before any other files
[ ] No real tokens in any committed file
[ ] All .example files use placeholder values only
[ ] git add -p used before every commit
[ ] Secret scan run before every push
```

---

## Defence-in-Depth Architecture

This deployment implements 9 independent security layers. Any single layer failing does not compromise the system:

```
Layer 1 — Firewall (UFW):         Default deny all inbound at kernel level
Layer 2 — Network binding:        Gateway loopback-only — zero external surface
Layer 3 — Authentication:         64-char cryptographically random token
Layer 4 — Channel allowlist:      Telegram denyByDefault + owner ID only
Layer 5 — Tool policy:            Allowlist — only permitted tools callable
Layer 6 — Sandbox isolation:      Docker container — no host access, no network
Layer 7 — DNS hardening:          Static resolv.conf — no race condition, no MITM
Layer 8 — Credential hygiene:     chmod 600, spend caps, rotation protocol
Layer 9 — Supply chain:           Verified, version-pinned skills only
```

---

## Troubleshooting

### Agent not responding on Telegram

```bash
sudo systemctl status openclaw-gateway
sudo journalctl -u openclaw-gateway --since "10 min ago"
curl -v https://api.telegram.org
cat /etc/resolv.conf          # Verify DNS hasn't been overwritten
```

### DNS overwritten after update

```bash
lsattr /etc/resolv.conf       # If no 'i' flag, file was changed
sudo chattr +i /etc/resolv.conf   # Re-apply immutable flag
```

### openclaw doctor failing

```bash
openclaw config validate       # Check config syntax
cat ~/.openclaw/openclaw.json | python3 -m json.tool   # Verify valid JSON
```

### Gateway not starting

```bash
ss -tlnp | grep 18789          # Check if port is already in use
sudo systemctl restart openclaw-gateway
openclaw doctor
```

### Sandbox/Docker errors

```bash
docker ps                      # Verify Docker is running
sudo systemctl start docker
sudo usermod -aG docker $USER  # Ensure docker group membership
newgrp docker                  # Apply in current session
# For permanent fix: log out and back in, or restart WSL2
```

---

*Built through real deployment. Every error in the troubleshooting section was real. Every fix was tested.*
