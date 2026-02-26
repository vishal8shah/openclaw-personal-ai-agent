---
layout: default
title: Home
---

# 🦞 OpenClaw Personal AI Agent

## Security-Hardened Deployment Guide

A production-grade, defence-in-depth deployment guide for self-hosted AI agents on WSL2 Ubuntu.

**What you get:** A 24/7 personal AI agent running on a recycled laptop for ~$0/month, connected via Telegram, powered by Google Gemini 3.1 Flash, and locked down with 9 independent security layers.

---

### Start Here

📖 **[Complete Setup & Security Guide](docs/security.md)** — The full walkthrough from WSL2 to production

🔧 **[Troubleshooting](docs/troubleshooting.md)** — Every real error encountered + verified fixes

🧩 **[Skills Guide](docs/skills.md)** — Safe skill installation with version pinning

📦 **[GitHub Repository](https://github.com/YOUR_USERNAME/openclaw-personal-ai-agent)** — Clone the config templates and scripts

---

### Defence-in-Depth Architecture

```
Layer 1 — Firewall (UFW)          Default deny all inbound
Layer 2 — Network binding          Loopback-only gateway
Layer 3 — Authentication           64-char cryptographic token
Layer 4 — Channel allowlist        Telegram owner-only access
Layer 5 — Tool policy              Allowlist-only tool execution
Layer 6 — Sandbox isolation        Docker — no host, no network
Layer 7 — DNS hardening            Static, immutable DNS config
Layer 8 — Credential hygiene       chmod 600 + spend caps
Layer 9 — Supply chain             Verified, version-pinned skills
```

---

*Built through real deployment. Every error was real. Every fix was tested.*
