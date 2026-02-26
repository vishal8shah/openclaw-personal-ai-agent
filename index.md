---
layout: default
title: Home
---

# 🦞 OpenClaw Personal AI Agent

## Security-Hardened Deployment Guide

A production-grade, defence-in-depth deployment guide for self-hosted AI agents on WSL2 Ubuntu.

**What you get:** A 24/7 personal AI agent running on a recycled laptop for ~$0/month, connected via Telegram, powered by Google Gemini 3.1 Flash, and locked down with 10 independent security layers.

---

### Start Here

📖 **[Complete Setup & Security Guide](docs/security)** — The full walkthrough from WSL2 to production

🔧 **[Troubleshooting](docs/troubleshooting)** — Every real error encountered + verified fixes

🧩 **[Skills Guide](docs/skills)** — Safe skill installation with version pinning

📦 **[GitHub Repository](https://github.com/vishal8shah/openclaw-personal-ai-agent)** — Clone the config templates and scripts

---

### Defence-in-Depth Architecture

```
Layer 1  — Network isolation          Dedicated router — isolated from home
Layer 2  — Firewall (UFW)             Default deny all inbound
Layer 3  — Network binding             Loopback-only gateway
Layer 4  — Authentication              64-char cryptographic token
Layer 5  — Channel allowlist           Telegram owner-only access
Layer 6  — Tool policy                 Allowlist-only tool execution
Layer 7  — Sandbox isolation           Docker — no host, no network
Layer 8  — DNS hardening               Static, immutable DNS config
Layer 9  — Credential hygiene          chmod 600 + spend caps
Layer 10 — Supply chain                Verified, version-pinned skills
```

---

*Built through real deployment. Every error was real. Every fix was tested.*
