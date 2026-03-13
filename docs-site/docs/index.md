# 🦞 OpenClaw Personal AI Agent

A security-hardened, defence-in-depth deployment guide for a self-hosted AI agent on WSL2 Ubuntu — with a five-layer observability stack.

**What you get:** A 24/7 personal AI agent running on a recycled laptop for ~$0/month, connected via Telegram, powered by **OpenAI Codex (GPT-5.4)**, locked down with 10 independent security layers — and fully instrumented for host health, pipeline health, runtime health, and cost economics.

!!! note
    This repo is transparent about what was actually used during setup, while pointing to the current official docs for anything version-sensitive.

---

## Quick Navigation

| Guide | What You Get |
|:------|:-------------|
| [Security Guide](security.md) | End-to-end hardening walkthrough — WSL2 to production |
| [Observability](observability.md) | Five-layer monitoring: host, pipeline, runtime, economics |
| [Troubleshooting](troubleshooting.md) | Every real error encountered + verified fix |
| [Skills Guide](skills.md) | Safe skill installation with version pinning |

---

## Defence-in-Depth Architecture

```
Layer 1  — Network isolation     Dedicated router — isolated from home
Layer 2  — Firewall (UFW)        Default deny all inbound
Layer 3  — Network binding       Loopback-only gateway
Layer 4  — Authentication        64-char cryptographic token
Layer 5  — Channel allowlist     DM pairing + owner-only access
Layer 6  — Tool policy           Allow/deny list tool execution
Layer 7  — Sandbox isolation     Docker — no host, no network
Layer 8  — DNS hardening         Static DNS config (WSL2-specific)
Layer 9  — Credential hygiene    chmod 600 + spend caps
Layer 10 — Supply chain          Reviewed, version-tracked skills
```

## Observability Architecture

```
Layer 1  — Host health           Node Exporter → Prometheus → Grafana
Layer 2  — Infra + Agent         Combined host + OpenClaw runtime (single triage view)
Layer 3  — Telemetry pipeline    OTel / Alloy / Tempo + OTLP latency p50/p95/p99
Layer 4  — Agent runtime         Queue depth, stuck sessions, message throughput
Layer 5  — Economics             Cost + token RPCs → Prometheus → Grafana
```

---

*Built through real deployment. Every error was real. Every fix was tested.*
