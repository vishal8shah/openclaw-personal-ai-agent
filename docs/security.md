---
layout: default
title: "Complete Setup & Security Guide"
nav_order: 1
---

# 🦞 OpenClaw Personal AI Agent — Complete Setup & Security Guide

> **Self-hosted AI agent deployment with defence-in-depth hardening on WSL2 Ubuntu**
>
> **Tested against:** OpenClaw 2026.2.x | **Platform:** Windows WSL2 + Ubuntu | **Model:** Google Gemini 3 Flash

---

## About This Guide

This guide documents a security-hardened deployment of OpenClaw — a self-hosted personal AI agent that runs on your own hardware, connects via Telegram, and executes tasks using AI models like Google Gemini.

In early 2026, security researchers reported widespread publicly accessible OpenClaw instances running with default configurations — many with authentication bypassed, gateways exposed on every network interface, and no encryption at rest. The ClawHavoc campaign saw malicious skills published to ClawHub, and independent research found a notable percentage of ClawHub skills leaking credentials in plaintext.

This guide was built the hard way — through real deployment, real errors, and real fixes — so you don't have to.

> **Transparency note:** OpenClaw is evolving quickly. This guide is honest about two things: **what I actually used during my setup** (preserved for transparency), and **what the current official docs recommend** (which readers should follow). Where the two differ, both are shown and clearly labelled. For anything version-sensitive, always cross-reference the [official OpenClaw docs](https://docs.openclaw.ai).

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
| Lateral movement | Compromised agent pivots to home devices | Critical |
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

**Enable systemd** — required for service management to work in WSL2:

```bash
sudo nano /etc/wsl.conf
```

Add this block at the top:

```ini
[boot]
systemd=true
```

Then restart WSL2 from PowerShell:

```powershell
wsl --shutdown
```

Reopen Ubuntu. All service commands in this guide depend on this step.

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
sudo apt install -y curl wget git nano ufw dnsutils
```

---

### 1.3 WSL2 DNS Hardening — Optional but Recommended

> **Context:** This section documents troubleshooting I went through during my own WSL2 deployment. WSL2's DNS handling varies by Windows version, build, and network configuration. You may not need all of these steps — but if your agent starts dropping connections to Telegram or Gemini APIs, this section is where to look.

By default, WSL2 regenerates `/etc/resolv.conf` and `/etc/hosts` on every reboot. This can create two issues:

1. **Network instability** — WSL2's auto-generated DNS sometimes points to an unreachable address, causing your agent to lose connectivity silently
2. **IPv6/IPv4 race condition** — WSL2 sometimes resolves `api.telegram.org` to an IPv6 address that Windows cannot route, causing connection failures that are extremely difficult to diagnose

**Step 1 — Disable WSL2 auto-generation:**

```bash
sudo nano /etc/wsl.conf
```

Ensure your wsl.conf contains both blocks (add the `[network]` section below your existing `[boot]` section):

```ini
[boot]
systemd=true

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

**Step 3 — Make it immutable (if supported):**

```bash
sudo chattr +i /etc/resolv.conf
```

> **Note:** `chattr +i` may not work on all WSL2 filesystem configurations. If you see `Operation not supported`, don't worry — the `wsl.conf` setting `generateResolvConf = false` is the primary permanent fix that prevents WSL2 from overwriting your DNS. The `chattr` flag is a belt-and-braces safeguard for systems that support it.

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
lsattr /etc/resolv.conf       # Should show ----i--- flag (if chattr was supported)
curl -v https://api.telegram.org   # Should resolve to IPv4
```

---

## Part 2 — OpenClaw Installation

### 2.1 Install OpenClaw

> **Security note:** Piping remote scripts directly into bash (`curl | bash`) is convenient but skips inspection. The commands below download first, let you review, then execute.

**Recommended (current official install path):**

```bash
curl -fsSL https://openclaw.ai/install.sh -o install.sh
less install.sh               # Review the script before running
bash install.sh
source ~/.bashrc

# Verify
openclaw --version
```

The installer handles Node detection, installation, and onboarding in one step. See [docs.openclaw.ai/install](https://docs.openclaw.ai/install) for alternative methods (npm, Docker, Podman, Nix).

> **What I used:** During my own setup I used an earlier install path (`get.openclaw.ai`). I'm preserving that below for transparency, but readers should follow the current official docs above.
>
> ```bash
> curl -fsSL https://get.openclaw.ai -o install.sh
> less install.sh
> bash install.sh
> ```

### 2.2 Run Initial Setup Wizard

```bash
openclaw onboard --install-daemon
```

The `--install-daemon` flag installs the gateway as a background service (systemd user unit on Linux/WSL2) so it starts automatically. During onboarding you will configure:
- Your AI model provider (select Google / Gemini)
- Your Gemini API key (get from [aistudio.google.com](https://aistudio.google.com) → Get API Key)
- Your Telegram bot token (get from @BotFather on Telegram → `/newbot`)
- Your workspace directory

Verify it's running:

```bash
openclaw gateway status
```

**Getting your Telegram user ID** — message @userinfobot on Telegram. It replies instantly with your numeric user ID. Save this — you'll need it for the allowlist config.

---

## Part 3 — Security Configuration

> This is where most deployments fail. The default OpenClaw config is optimised for getting started fast, not for security. Every setting below has a documented reason.

All configuration lives in:

```bash
nano ~/.openclaw/openclaw.json
```

**Recommended hardened configuration (based on current OpenClaw docs):**

The config below follows the current [OpenClaw configuration reference](https://docs.openclaw.ai/gateway/configuration-reference) and [configuration examples](https://docs.openclaw.ai/gateway/configuration-examples). Verify against those docs for your installed version — the schema evolves between releases.

```json5
{
  // OpenClaw uses JSON5 — comments and trailing commas are valid
  "agents": {
    "defaults": {
      "model": {
        "primary": "google/gemini-3-flash-preview"
      },
      "workspace": "~/.openclaw/workspace",
      "sandbox": {
        "mode": "all",
        "workspaceAccess": "ro",
        "docker": {
          "network": "none"
        }
      }
    }
  },
  "tools": {
    "allow": ["read", "message", "web_search", "web_fetch"],
    "deny": ["exec", "process", "write"]
  },
  "gateway": {
    "port": 18789,
    "bind": "loopback",
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
      "allowFrom": ["tg:YOUR_TELEGRAM_USER_ID_HERE"],
      "streaming": "off",
      "network": {
        "autoSelectFamily": true,
        "dnsResultOrder": "ipv4first"
      }
    }
  }
}
```

> **What I tested vs. what's shown above:** My own deployment used an earlier config structure that included `agents.defaults.tools` (instead of top-level `tools`), tool names like `read_file`/`send_message`/`browse_web` (now `read`/`message`/`web_search`/`web_fetch`), model string without provider prefix (now `provider/model` format like `google/gemini-3-flash-preview`), `streaming: false` (instead of `"off"`), `allowFrom` without the `tg:` prefix, `gateway.mDNS.enabled: false` (instead of the env var approach), and a `denyByDefault` flag that no longer appears in current docs. The config above has been updated to match the current documented schema. If you're running an older version, your working config may look different — both patterns may work, but the current docs are the safer reference.

> **Disabling mDNS:** To prevent the gateway from broadcasting its presence on the local network, add `OPENCLAW_DISABLE_BONJOUR=1` to your environment (shown in [Part 4](#part-4--credential-security)). The official docs describe this as the supported method. In earlier versions, a `gateway.mDNS` config key was available — if your version supports it, `discovery.mdns.mode: "minimal"` reduces TXT record exposure while keeping basic device discovery.

> **Config format note:** OpenClaw uses JSON5 (supports comments and trailing commas). Do not validate with `python3 -m json.tool` as it will reject valid JSON5 features. Use `openclaw doctor` for config validation instead.

### Why Each Security Setting Matters

| Setting | What It Does | Without It |
|---|---|---|
| `bind: loopback` | Gateway only listens on 127.0.0.1 | Scannable by Shodan within hours |
| `auth.mode: token` | Requires 64-char token for all API calls | Any local process controls your agent |
| `OPENCLAW_DISABLE_BONJOUR=1` | Agent invisible to network scanners | Every LAN device discovers your agent |
| `dmPolicy: pairing` | New DMs require explicit approval | Unknown users bypass your allowlist |
| `allowFrom: [tg:yourID]` | Only your Telegram ID is authorised | Any Telegram user can interact |
| `groupPolicy: allowlist` | Bot ignores group chats | Group members can inject commands |
| `streaming: "off"` | Disables partial message streaming | Potentially leaks partial responses |
| `tools.allow` | Only listed tools are callable | Compromised agent can do anything |
| `sandbox.enabled: true` | Tool calls run in Docker isolation | Malicious code accesses host filesystem |
| `sandbox.docker.network: none` | Sandboxed containers have no network | Malicious code can exfiltrate data |
| Skill version pinning | Fixed version, no auto-updates | Compromised skill update auto-installed |

**Generate your gateway token:**

```bash
openssl rand -hex 32
# Outputs a 64-character cryptographically random token
# Paste this into the "token" field above
```

After editing config:

```bash
openclaw gateway restart
openclaw doctor
```

---

## Part 4 — Credential Security

### 4.1 File Permissions

API keys are stored in agent-scoped auth profiles. The exact path depends on your agent ID — find yours with:

```bash
find ~/.openclaw -name "auth-profiles.json"
```

The typical path is `~/.openclaw/agents/<agentId>/agent/auth-profiles.json`. Lock both config files down:

```bash
chmod 600 ~/.openclaw/openclaw.json
chmod 600 ~/.openclaw/agents/*/agent/auth-profiles.json

# Verify
ls -la ~/.openclaw/openclaw.json
# Should show: -rw------- (owner read/write only)
```

**Why `chmod 600`:** Default file creation on Linux is 644 — world-readable. Your bot token and Gemini API key are sitting in those files. `chmod 600` means only your user account can read them. No other process, no accidental terminal output visible in logs, no world-readable credentials.

### 4.2 Disable ClawHub Telemetry

> **Note:** The ClawHub CLI was originally distributed as `clawdhub` in earlier releases. It has since been renamed to `clawhub`. This guide uses the current name `clawhub` throughout. If you installed during the earlier period, your system may still have the old binary name — both should work, but `clawhub` is the current documented name.

```bash
echo 'export CLAWHUB_DISABLE_TELEMETRY=1' >> ~/.bashrc
echo 'export OPENCLAW_DISABLE_BONJOUR=1' >> ~/.bashrc
source ~/.bashrc
```

**Why:** ClawHub sends a minimal install snapshot during `clawhub sync` to compute install counts. Disabling it eliminates this background data transmission if you prefer not to participate. The Bonjour/mDNS disable prevents the gateway from broadcasting its presence on the local network (see [Part 3](#part-3--security-configuration)).

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
# Then update auth-profiles.json with new values:
find ~/.openclaw -name "auth-profiles.json" -exec nano {} \;
```

---

## Part 5 — Skill Installation (Security-First Approach)

### 5.1 Review Skills Before Installing

The ClawHavoc campaign placed malicious skills on ClawHub. Always review before installing:

```bash
# Search for skills by name or function
clawhub search "pdf"

# Check the skill page on clawhub.ai for community feedback, stars, and version history
```

> **Note on `clawhub search`:** The current documented ClawHub CLI commands are `search`, `install`, `update`, `list`, `publish`, and `sync`. Other commands (like `info`) may exist in some versions but are not in the current public docs — if you use them and they work, treat them as version-specific behaviour.

### 5.2 Install Skills Deliberately

```bash
clawhub install nano-pdf
clawhub install playwright-mcp
```

Both were reviewed before install and deliberately version-tracked. nano-pdf enables document analysis; playwright-mcp enables web automation.

### 5.3 Version Pinning via Lockfile

ClawHub tracks installed skill versions in `.clawhub/lock.json` under your workspace directory. This lockfile records the exact version hash of each installed skill.

```bash
# View installed skills and versions
clawhub list

# Update a specific skill (after reviewing changelog)
clawhub update SKILL_NAME
```

**Why version pinning matters:** If you always pull `latest`, a compromised update is automatically installed. The ClawHavoc campaign exploited this exact vector. The lockfile ensures you upgrade consciously, on your timeline, after reviewing the changelog. Use `clawhub update SKILL_NAME` to update individual skills after reviewing their changelogs.

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
openclaw gateway restart
openclaw doctor
```

---

## Part 7 — Physical Network Isolation

**This is the layer that sits outside the entire software stack — and it's the one most home deployments never consider.**

In enterprise environments, lab and experiment workloads run on isolated network segments — separate VLANs, dedicated switches, firewall rules that prevent lateral movement into production. A personal AI agent running 24/7 on your home network deserves the same treatment. If the agent host is compromised, you don't want the attacker pivoting to your family's devices, your NAS, your smart home gear, or your primary workstation.

The solution is simple and nearly free: **use an old spare router to create a physically isolated network for the agent laptop.**

### 7.1 Architecture

```
Internet
   │
   ├── Primary Router (home network)
   │     ├── Family devices, phones, smart TV
   │     ├── Primary workstation
   │     └── NAS, printers, IoT
   │
   └── Old Spare Router (experiment network)
         └── OpenClaw agent laptop ← isolated here
```

The agent laptop connects to the internet through the spare router. It has full outbound connectivity (needed for Telegram API, Gemini API, system updates) but **cannot see or reach any device on your home network**. Your home network cannot see the agent laptop either. This is the same principle as a lab domain network at work — experiments stay contained.

### 7.2 Setup

1. **Factory reset your old router** — clear any stale config, firmware update if available
2. **Connect its WAN port to a LAN port on your primary router** — the spare router gets internet via your primary router but runs its own isolated subnet
3. **Configure the spare router's LAN subnet to a different range** — e.g. if your home network is `192.168.1.x`, set the spare router to `192.168.50.x` or `10.0.50.x`
4. **Disable UPnP and WPS on the spare router** — reduces attack surface
5. **Connect the agent laptop to the spare router only** — via ethernet for reliability (WiFi works but ethernet is more stable for a 24/7 agent)
6. **Disable any port forwarding** on the spare router — the agent only needs outbound HTTPS (port 443)

### 7.3 Verification

From the agent laptop:

```bash
# Confirm internet connectivity
curl -s https://api.telegram.org | head -1

# Confirm isolation — this should FAIL (timeout or unreachable)
ping -c 2 192.168.1.1          # Replace with your primary router's IP
ping -c 2 192.168.1.100        # Replace with any home device IP
```

If the pings to your home network succeed, the isolation isn't working — check that the spare router is running its own DHCP on a separate subnet.

### 7.4 Why This Matters

Software layers can be misconfigured, reverted, or bypassed. A physical network boundary cannot be crossed by a software bug. Even if every other security layer in this guide fails simultaneously — firewall disabled, gateway bound to 0.0.0.0, auth bypassed — the attacker is still trapped on an isolated network segment with nothing to pivot to except a single-purpose laptop.

**Cost: $0** (you already have the old router). **Effort: 15 minutes.** **Impact: eliminates lateral movement entirely.**

---

## Part 8 — Firewall Hardening (UFW)

UFW adds another independent network protection layer. Even if OpenClaw config is accidentally changed and the bind address reverts to 0.0.0.0, UFW blocks port 18789 at the kernel level regardless.

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
- Layer 1 (Physical): Isolated network — no lateral movement to home devices
- Layer 2 (Firewall): UFW blocks port 18789 at kernel level
- Layer 3 (Binding): Gateway bound to loopback — no external surface
- Layer 4 (Auth): Token required for all API calls

Any single layer failing does not compromise the system.

---

## Part 9 — Health Monitoring

### 9.1 Built-in Health Check

```bash
# Run after every config change
openclaw doctor

# Deep security audit
openclaw security audit --deep

# JSON output for scripting
openclaw health --json
```

### 9.2 External Monitoring with healthchecks.io

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

### 9.3 Gateway Service Management

```bash
# Check service status
openclaw gateway status

# Live logs
openclaw logs --follow

# Restart after config changes
openclaw gateway restart
```

> **Advanced:** If you need raw systemd access, the gateway runs as a user service. Use `systemctl --user status openclaw-gateway.service` and `journalctl --user -u openclaw-gateway.service -f`. The `openclaw gateway` commands are preferred as they are version-stable.

---

## Part 10 — CVE Patch Management

Stay current on security patches. OpenClaw has had critical vulnerabilities — including WebSocket-based remote code execution bugs — that were patched in prior releases. Instances without update alerts stayed vulnerable for weeks after public disclosure.

### 10.1 Subscribe to Security Advisories

1. Go to `github.com/openclaw-ai/openclaw`
2. Click **Watch** → **Custom** → tick **Security alerts**
3. Subscribe to: `github.com/openclaw-ai/openclaw/security/advisories`

### 10.2 Weekly Update Check

```bash
# Check for updates
openclaw update

# Review what's available
openclaw update status

# Automated weekly check (add to crontab)
crontab -e
# Add:
0 9 * * 1 openclaw update status
```

**Patch SLA:** Apply patches rated CVSS 7.0+ within 24 hours of advisory. CVSS 4.0–6.9 within 7 days.

---

## Security Checklist — Complete Verification

Run through this after full deployment:

```
PHYSICAL NETWORK
[ ] Agent laptop connected to dedicated spare router — not the home network
[ ] Spare router on a separate subnet from primary router
[ ] UPnP and WPS disabled on spare router
[ ] No port forwarding configured on spare router
[ ] Verified: agent laptop cannot ping home network devices
[ ] Verified: agent laptop has outbound internet (HTTPS/443)

NETWORK (SOFTWARE)
[ ] Gateway bind: "loopback" — verified with: ss -tlnp | grep 18789
[ ] UFW active: default deny incoming, default allow outgoing
[ ] Port 18789 blocked at UFW level
[ ] OPENCLAW_DISABLE_BONJOUR=1 set in ~/.bashrc

AUTHENTICATION
[ ] Gateway auth mode: "token"
[ ] Token generated with: openssl rand -hex 32
[ ] Telegram allowFrom contains ONLY your user ID (tg: prefix)
[ ] groupPolicy: allowlist set
[ ] dmPolicy: pairing set

CREDENTIALS
[ ] openclaw.json permissions: 600 (-rw-------)
[ ] auth-profiles.json permissions: 600 (-rw-------)
[ ] API spend cap set in Google AI Studio
[ ] No API key ever committed to git
[ ] CLAWHUB_DISABLE_TELEMETRY=1 in ~/.bashrc

SKILLS & TOOLS
[ ] All installed skills reviewed before install
[ ] Tool allow/deny lists configured (only needed tools enabled)
[ ] Sandbox mode enabled with Docker
[ ] Sandbox network: "none" (no exfiltration path)
[ ] Skill versions tracked via .clawhub/lock.json

DNS (WSL2 SPECIFIC — IF CONFIGURED)
[ ] generateResolvConf=false in /etc/wsl.conf
[ ] generateHosts=false in /etc/wsl.conf
[ ] /etc/resolv.conf is a real static file (not a symlink)
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

This deployment implements 10 independent security layers. Any single layer failing does not compromise the system:

```
Layer 1  — Network isolation:      Dedicated router — agent can't reach home network
Layer 2  — Firewall (UFW):         Default deny all inbound at kernel level
Layer 3  — Network binding:        Gateway loopback-only — zero external surface
Layer 4  — Authentication:         64-char cryptographically random token
Layer 5  — Channel allowlist:      DM pairing + owner ID only
Layer 6  — Tool policy:            Allow/deny lists — only permitted tools callable
Layer 7  — Sandbox isolation:      Docker container — no host access, no network
Layer 8  — DNS hardening:          Static resolv.conf (WSL2-specific, if configured)
Layer 9  — Credential hygiene:     chmod 600, spend caps, rotation protocol
Layer 10 — Supply chain:           Reviewed, version-tracked skills only
```

---

## Troubleshooting

### Agent not responding on Telegram

```bash
openclaw gateway status
openclaw logs --follow
curl -v https://api.telegram.org
cat /etc/resolv.conf          # Verify DNS hasn't been overwritten
```

### DNS overwritten after update

```bash
# Check if resolv.conf is still a real file (not a symlink)
ls -la /etc/resolv.conf

# If overwritten, recreate:
sudo rm /etc/resolv.conf
echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" | sudo tee /etc/resolv.conf
# Optionally re-apply immutable flag if your filesystem supports it:
sudo chattr +i /etc/resolv.conf
```

### Config validation failing

```bash
# Use OpenClaw's built-in doctor (supports JSON5 configs with comments)
openclaw doctor

# Do NOT use python3 -m json.tool — it rejects valid JSON5 features
# like comments and trailing commas
```

### Gateway not starting

```bash
ss -tlnp | grep 18789          # Check if port is already in use
openclaw gateway restart
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

*Built through real deployment. Every error in the troubleshooting section was real. Every fix was tested. Where the product has evolved since, both the historical and current-docs paths are shown.*
