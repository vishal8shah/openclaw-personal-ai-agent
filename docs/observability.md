---
layout: default
title: Observability
---

# Observability — Monitoring Your OpenClaw Agent

This guide covers the full observability stack built on top of the OpenClaw personal agent deployment. It is a companion to the [Security Guide](security) and assumes the agent is already running.

---

## Why observability matters for a personal AI agent

Infrastructure health tells you the machine is alive. It does not tell you whether your agent is healthy, how much it is spending, or which sessions are driving cost.

This guide separates those concerns into five distinct layers — each with its own data source, dashboard, and purpose.

> **Key architectural insight:** Runtime telemetry and economics telemetry are not the same thing. OpenTelemetry signals give you pipeline health and trace flow. Cost and token data lives in OpenClaw's native usage RPCs. Neither replaces the other.

---

## Stack components

| Component | Role |
|---|---|
| **Node Exporter** | Host metrics — CPU, memory, disk, network |
| **Grafana Alloy** | OpenTelemetry collector — routes spans and metrics |
| **Tempo** | Trace backend — stores distributed traces |
| **Prometheus** | Metrics store — scrapes all exporters |
| **Grafana** | Visualisation — all dashboards live here |
| **usage_exporter.py** | Custom exporter — pulls OpenClaw usage RPCs, exposes Prometheus metrics on `:9479` |

### Target architecture

```
WSL2 Host Metrics     → Node Exporter  → Prometheus → Grafana
OpenClaw Metrics      → Alloy metrics  → Prometheus → Grafana
OTel / Trace Signals  → Alloy          → Tempo      → Grafana Explore
Tempo Metrics Gen     → Tempo remote_write → Prometheus
OpenClaw Usage RPCs   → usage_exporter → Prometheus → Grafana
```

---

## Layer 1 — WSL2 Host + Network Health

**Dashboard:** `wsl2-host-network-health.json`  
**Purpose:** Infrastructure baseline. Eliminates the host as a suspect before investigating the agent stack.

| Panel | Signal |
|---|---|
| CPU Used % | `node_cpu_seconds_total{mode="idle"}` |
| Memory Used % | `node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes` |
| Root Disk Used % | `node_filesystem_avail_bytes / node_filesystem_size_bytes` |
| Targets Down | `sum(1 - up{job=~"prometheus|openclaw|node"})` |
| Network Throughput | RX / TX bytes/sec, excluding loopback and veth |
| Connection Pressure | TCP established + conntrack entries |
| Network Errors / Drops | RX/TX drops and errors per second |
| Uptime & Load | `node_load1`, `node_load5`, uptime seconds |

---

## Layer 2 — Infra + AI Runtime Combined

**Dashboard:** `infra-plus-aiops-dashboard.json`  
**Purpose:** One view bridging machine health and agent activity. The fastest triage starting point.

| Panel | Signal |
|---|---|
| Host CPU / Memory / Disk | node_exporter fundamentals |
| Failed Targets | `sum(up{job=~"prometheus|openclaw|node"} == 0)` |
| Network Throughput | Host RX/TX |
| Host Uptime | `node_time_seconds - node_boot_time_seconds` |
| OpenClaw Throughput | `claw_messages_processed_total` |
| AI Runtime Pressure | `claw_queue_depth`, `claw_session_stuck_total` |

---

## Layer 3 — Telemetry Pipeline Health

Two dashboards cover this layer.

### OTel Pipeline Health

**Dashboard:** `otel-pipeline-health.json`  
**Purpose:** Health of the Alloy → Tempo collection pipeline.

| Panel | Signal |
|---|---|
| Alloy Config Healthy | `alloy_config_last_load_successful` |
| Healthy Alloy Components | `alloy_component_controller_running_components{health_type="healthy"}` |
| Alloy Eval Queue | `alloy_component_evaluation_queue_size` |
| Accepted Spans/sec | `rate(otelcol_receiver_accepted_spans_total[5m])` |
| OTLP Receiver Span Flow | accepted / refused / failed spans |
| Exporter Health & Backpressure | sent / send failed / queue size |
| Telemetry Process Memory | Alloy + Tempo resident memory (bytes) |
| Tempo Ingest Signals | distributor spans / receiver accepted / discarded |

### OpenClaw Observability Hero

**Dashboard:** `openclaw-observability-hero.json`  
**Purpose:** Telemetry-pipeline-level observability for OpenClaw specifically — watching the watcher.

| Panel | Signal |
|---|---|
| Telemetry Config Healthy | Alloy config load success |
| Alloy Evaluation Queue | Queue depth |
| Accepted / Sent Spans/sec | Receiver + exporter throughput |
| OTLP Receiver Span Flow | accepted / refused / failed |
| Exporter Health & Backpressure | sent / send failed / queue |
| **OTLP HTTP Requests by Status** | `http_server_request_duration_seconds` by status code |
| **OTLP Receiver Latency** | p50 / p95 / p99 |
| Tempo Ingest Signals | distributor / receiver / discarded |
| Collector Resource Footprint | Alloy resident + virtual memory, host RX/TX |

> If the collector or export path is broken, your observability is an illusion. This dashboard is where you detect that.

---

## Layer 4 — Agent Runtime Observability

**Dashboard:** `openclaw-runtime-dashboard.json`  
**Purpose:** Operational health of the agent itself — not just "is it alive" but "is it healthy".

| Panel | Signal |
|---|---|
| Stuck Sessions | `claw_session_stuck_total` |
| Queue Depth | `claw_queue_depth` |
| Messages/sec (5m) | `rate(claw_messages_processed_total[5m])` |
| Queue Wait p95 | 95th percentile queue wait time |
| Message Throughput by Kind | Split by message kind |
| Queue Depth by Session Kind | Split by session kind |
| **Queue Wait Quantiles** | p50 / p95 / p99 — `claw_queue_wait_seconds` |

> The p50/p95/p99 latency panels are the signal that tells you whether the agent is degraded before your users notice.

---

## Layer 5 — Economics (Cost + Token Monitoring)

### Architecture

```
OpenClaw usage RPCs  →  usage_exporter.py (:9479)  →  Prometheus  →  Grafana v3 dashboard
                                                                    ↓
                                                            Alert rules (5 rules)
```

### Key metrics

| Metric | Description |
|---|---|
| `openclaw_usage_range_totalCost` | Total cost for the day (USD) |
| `openclaw_usage_range_totalTokens` | Total tokens for the day |
| `openclaw_session_total_cost_usd` | Per-session total cost |
| `openclaw_session_total_tokens` | Per-session total tokens |
| `openclaw_usage_model_totalCost` | Cost split by model |
| `openclaw_usage_channel_totalCost` | Cost split by channel |

### Dashboard evolution — v1 → v3

| Version | State |
|---|---|
| v1 | Functional — data present, panels unfiltered, noisy |
| v2 | Cleaner panels, channel splits added, cron noise reduced |
| v3 | Ship-worthy — cron/unknown sessions filtered from user-facing tables, Telegram cost share fixed, human-readable |

**Final dashboard file:** `openclaw-usage-cost-dashboard-v3.json`

### Prometheus scrape job

```yaml
- job_name: 'openclaw_usage'
  static_configs:
    - targets: ['localhost:9479']
```

Validate and apply:

```bash
promtool check config /etc/prometheus/prometheus.yml
sudo systemctl restart prometheus
curl -s 'http://localhost:9090/api/v1/query?query=up{job="openclaw_usage"}'
```

### Alert rules

| Rule | Threshold |
|---|---|
| `OpenClawDailyCostHigh` | Daily cost > $10 |
| `OpenClawDailyCostCritical` | Daily cost > $20 |
| `OpenClawSingleSessionCostSpike` | Any session > $5 |
| `OpenClawTokenBurnHigh` | > 1.5M tokens in 30 min |
| `OpenClawExporterDown` | Exporter unhealthy |

> **Calibration note:** Thresholds that look sensible on paper will fire immediately against real usage. One active direct session alone can exceed the $10 daily threshold. Calibrate against at least one full day of live traffic before treating these as pages.

---

## Troubleshooting

### Tempo native histogram mismatch

**Symptom:** Tempo logs show `native histograms are disabled`; repeated failed remote writes to Prometheus.

**Cause:** `generate_native_histograms: both` in `/etc/tempo/config.yml` while Prometheus native histograms are disabled.

**Fix:**
```yaml
generate_native_histograms: none
```
Restart Tempo and verify `/ready` returns 200.

---

### Prometheus not scraping usage exporter

**Symptom:** `up{job="openclaw_usage"}` returns empty or 0.

1. Is `usage_exporter.py` running? → `curl http://localhost:9479/healthz`
2. Is the scrape job in `prometheus.yml`?
3. Did you run `promtool check config` and restart?

---

### YAML indentation corruption

**Symptom:** Prometheus or Grafana provisioning breaks after a config edit.

**Cause:** Multiline terminal paste silently mangles leading whitespace.

**Rule:** Always run `promtool check config` before restarting. Use `sudo tee` not `sudo >` for privileged writes. Write configs with a real editor, not shell paste.

---

### Grafana provisioning fails / panels blank

**Practical path:** Skip file provisioning. Import dashboard JSON manually via Grafana UI → Dashboards → Import. More reliable than provisioning when the environment is fragile.

---

## Operational checklist

```
[ ] usage_exporter.py running on :9479
[ ] Prometheus scraping openclaw_usage job (up = 1)
[ ] All 5 alert rules loaded and evaluating
[ ] All 8 dashboard JSONs imported into Grafana
[ ] Tempo /ready returning 200
[ ] Alloy config loaded successfully (alloy_config_last_load_successful = 1)
[ ] No persistent exporter backpressure errors in Alloy logs
[ ] Alert thresholds calibrated against at least one full day of live traffic
```

---

## Key lessons

1. **Installed ≠ wired** — open port does not mean healthy pipeline
2. **Validate config before restart** — `promtool check config` is non-negotiable
3. **Docker hostnames break outside Docker** — use `localhost`, not service names in WSL2
4. **Use real metric inventory before building dashboards** — build against confirmed metrics only
5. **Runtime telemetry ≠ economics telemetry** — different sources, different purposes
6. **Alert thresholds need calibration** — one real session breaks every naive threshold
7. **v3 > v1** — a dashboard that humans can read in 5 seconds is not the first one you build
