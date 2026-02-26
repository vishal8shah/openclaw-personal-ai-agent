# 🦞 OpenClaw Personal AI Agent — Security-Hardened Deployment

> **A production-grade, defence-in-depth deployment guide for self-hosted AI agents on WSL2 Ubuntu**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: WSL2](https://img.shields.io/badge/Platform-WSL2%20Ubuntu-orange.svg)](#prerequisites)
[![Security: 10-Layer](https://img.shields.io/badge/Security-10%20Layer%20Defence-green.svg)](#defence-in-depth-architecture)

---

## What This Is

A complete, battle-tested guide to deploying [OpenClaw](https://openclaw.ai) as a personal AI agent that:

- Runs 24/7 on a recycled laptop (~$0/month ongoing cost)
- Connects via Telegram for on-demand briefings (ASX, MAG7, AUD/USD, and more)
- Uses Google Gemini 3.1 Flash as the AI backbone
- Is locked down with **10 independent security layers** — not as an afterthought, but as the foundation

This isn't a quickstart. It's what a secure deployment actually looks like.

---

## Why This Exists

Most OpenClaw deployment guides optimise for speed. Get it running, worry about security later. The problem is that "later" never comes — and in early 2026, security researchers found tens of thousands of publicly accessible OpenClaw instances running with default configurations: authentication bypassed, gateways exposed on every network interface, no encryption at rest.

This guide was built the hard way — through real deployment, real errors, and real fixes — so you don't have to repeat them.

---

## What's Inside

| Section | What You Get |
|---|---|
| [Full Setup Guide](docs/security.md) | End-to-end walkthrough from WSL2 to production |
| [Network Isolation](docs/security.md#part-7--physical-network-isolation) | Dedicated router setup for experiment network |
| [Security Hardening](docs/security.md#part-3--security-configuration) | Every setting explained with threat context |
| [DNS Hardening](docs/security.md#13-wsl2-dns-hardening--the-step-most-guides-skip) | The WSL2 DNS fix most guides skip entirely |
| [Sandbox Isolation](docs/security.md#part-6--sandbox-mode-docker) | Docker-based tool execution with zero network |
| [Credential Security](docs/security.md#part-4--credential-security) | File permissions, spend caps, rotation protocol |
| [Health Monitoring](docs/security.md#part-9--health-monitoring) | External alerting via healthchecks.io |
| [Troubleshooting](docs/security.md#troubleshooting) | Every real error encountered + verified fix |
| [Security Checklist](docs/security.md#security-checklist--complete-verification) | Complete verification checklist for auditing |

---

## Defence-in-Depth Architecture

This deployment implements 10 independent security layers. Any single layer failing does not compromise the system:

```
Layer 1  — Network isolation          Dedicated router — agent can't reach home network
Layer 2  — Firewall (UFW)             Default deny all inbound at kernel level
Layer 3  — Network binding             Gateway loopback-only — zero external surface
Layer 4  — Authentication              64-char cryptographically random token
Layer 5  — Channel allowlist           Telegram denyByDefault + owner ID only
Layer 6  — Tool policy                 Allowlist — only permitted tools callable
Layer 7  — Sandbox isolation           Docker container — no host access, no network
Layer 8  — DNS hardening               Static resolv.conf — no race condition, no MITM
Layer 9  — Credential hygiene          chmod 600, spend caps, rotation protocol
Layer 10 — Supply chain                Verified, version-pinned skills only
```

---

## Prerequisites

- Windows 10/11 machine (a spare laptop works perfectly)
- Google account (for Gemini API key via [Google AI Studio](https://aistudio.google.com))
- Telegram account (for bot creation via @BotFather)
- Basic comfort with a Linux terminal

---

## Quick Start

> **Full guide:** [docs/security.md](docs/security.md)

```bash
# 1. Enable WSL2 (PowerShell as Admin)
wsl --install
wsl --set-default-version 2

# 2. Update Ubuntu
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git nano ufw

# 3. Install OpenClaw (review the script before running)
curl -fsSL https://get.openclaw.ai -o install.sh
less install.sh
bash install.sh
source ~/.bashrc

# 4. Run setup wizard
openclaw onboard

# 5. Apply hardened config — see docs/security.md for full walkthrough
# 6. Run security audit
openclaw doctor
openclaw security audit --deep
```

**Do not skip the security configuration.** The default config is optimised for getting started fast, not for safety. The [full guide](docs/security.md) walks through every setting with threat context.

---

## Repository Structure

```
openclaw-personal-ai-agent/
├── README.md                              You are here
├── LICENSE                                MIT
├── .gitignore                             Blocks all credential files
├── _config.yml                            GitHub Pages configuration
├── Gemfile                                Jekyll dependencies
├── config/
│   ├── openclaw.json.example              Sanitised config — no real tokens
│   ├── auth-profiles.json.example         Structure only, placeholder keys
│   └── wsl.conf.example                   DNS hardening config
├── scripts/
│   ├── setup.sh                           Automated install script
│   └── healthcheck.sh                     Wraps openclaw doctor + healthchecks.io ping
├── docs/
│   ├── security.md                        Complete hardening guide (the main event)
│   ├── troubleshooting.md                 Every real error + fix
│   └── skills.md                          Safe skill installation guide
└── workspace/
    └── boot.md.example                    Template with placeholders
```

---

## Security Notice

This repository contains **no real credentials, API keys, or tokens**. All configuration files use placeholder values. If you find anything that looks like a real credential, please [open an issue](https://github.com/vishal8shah/openclaw-personal-ai-agent/issues) immediately.

**Before every commit:**
```bash
git add -p                    # Review every change before staging
grep -r "AIza" .              # Scan for Google API key pattern
grep -r "bot[0-9]" .          # Scan for Telegram token pattern
```

---

## Tech Stack

| Component | Choice | Why |
|---|---|---|
| AI Model | Google Gemini 3.1 Flash | Fast inference, token-efficient, low cost |
| Agent Framework | OpenClaw | Self-hosted, extensible, Telegram-native |
| Platform | WSL2 + Ubuntu | Full Linux kernel with Windows host isolation |
| Sandbox | Docker | Kernel-level tool execution isolation |
| Firewall | UFW | Defence-in-depth network layer |
| Monitoring | healthchecks.io | External crash detection with 5-min alerting |

> **Note on model choice:** This deployment started on Gemini 3.1 Pro but was switched to Gemini 3.1 Flash for faster inference and better token efficiency during extended use. Flash handles the personal agent workload comfortably at a fraction of the cost.

---

## Contributing

Found a security gap? Better hardening technique? Real-world edge case?

1. Fork the repo
2. Create a branch (`git checkout -b fix/your-improvement`)
3. Use `git add -p` (not `git add .`) — review every change
4. Run a secret scan before pushing
5. Open a PR with context on the threat or improvement

---

## License

[MIT](LICENSE) — use it, fork it, harden it further.

---

## Author

**Vishal Shah**
Delivery Lead | Observability | Agentic AI | SRE | ServiceNow

Built through real deployment. Every error in the troubleshooting section was real. Every fix was tested.

---

<p align="center">
  <i>Most people rushing to deploy AI agents treat security as optional.<br/>This guide treats it as the foundation.</i>
</p>
