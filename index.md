---
layout: default
title: Home
nav_order: 0
---

# 🦞 OpenClaw Personal AI Agent

## Security-Hardened Deployment + Observability Guide

A security-hardened, defence-in-depth deployment guide for a self-hosted AI agent on WSL2 Ubuntu.

**What you get:** A 24/7 personal AI agent running on a recycled laptop for ~$0/month, connected via Telegram, powered by **OpenAI Codex (GPT-5.4)**, locked down with 10 independent security layers — and instrumented with a five-layer observability stack covering host health, telemetry pipeline health, runtime health, and real usage economics.

> This repo is transparent about what was actually used during setup, while pointing readers to the current official docs for anything version-sensitive.

---

### Start Here

📖 **[Complete Setup & Security Guide](docs/security)** — Full walkthrough from WSL2 to a hardened personal deployment

📊 **[Observability Guide](docs/observability)** — Five-layer monitoring stack: host, infra + agent, telemetry pipeline, runtime, and cost/token economics

🔧 **[Troubleshooting](docs/troubleshooting)** — Every real error encountered + verified fixes

🧩 **[Skills Guide](docs/skills)** — Safe skill installation with version pinning

📦 **[GitHub Repository](https://github.com/vishal8shah/openclaw-personal-ai-agent)** — Clone the config templates and scripts

---

### Defence-in-Depth Architecture

```
Layer 1  — Network isolation     Dedicated router — isolated from home
Layer 2  — Firewall (UFW)        Default deny all inbound
Layer 3  — Network binding       Loopback-only gateway
Layer 4  — Authentication        64-char cryptographic token
Layer 5  — Channel allowlist     DM pairing + owner-only access
Layer 6  — Tool policy           Allow/deny list tool execution
Layer 7  — Sandbox isolation     Docker — no host, no network
Layer 8  — DNS hardening         Static DNS config (WSL2-specific, if configured)
Layer 9  — Credential hygiene    chmod 600 + spend caps
Layer 10 — Supply chain          Reviewed, version-tracked skills
```

### Observability Architecture

```
Layer 1  — Host health           WSL2 Host + Network Health (Node Exporter → Prometheus → Grafana)
Layer 2  — Infra + Agent         Combined host + OpenClaw runtime signals (single triage view)
Layer 3  — Telemetry pipeline    OTel / Alloy / Tempo health + OTLP receiver latency p50/p95/p99
Layer 4  — Agent runtime         Queue depth, stuck sessions, message throughput, wait quantiles
Layer 5  — Economics             Cost + token monitoring via native usage RPCs → Prometheus → Grafana
```

---

*Built through real deployment. Every error was real. Every fix was tested. Where the product has evolved since, both paths are shown.*
