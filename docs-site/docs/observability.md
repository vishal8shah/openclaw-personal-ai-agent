# Observability — Five-Layer Monitoring

Five-layer monitoring stack covering host health, telemetry pipeline, agent runtime, and cost economics.

This guide is a companion to the [Security Guide](security.md). The agent should be hardened before instrumenting it.

---

## Why observability matters for a personal AI agent

Infrastructure health tells you the machine is alive. It does not tell you whether your agent is healthy, how much it is spending, or which sessions are driving cost.

This guide separates those concerns into five distinct layers — each with its own data source, dashboard, and purpose.

!!! important
    Runtime telemetry and economics telemetry are not the same thing. OpenTelemetry signals give you pipeline health and trace flow. Cost and token data lives in OpenClaw’s native usage RPCs. Neither replaces the other.

---

## Stack Components

| Component | Role |
|:----------|:-----|
| **Node Exporter** | Host metrics — CPU, memory, disk, network |
| **Grafana Alloy** | OpenTelemetry collector — routes spans and metrics |
| **Tempo** | Trace backend — stores distributed traces |
| **Prometheus** | Metrics store — scrapes all exporters |
| **Grafana** | Visualisation — all dashboards live here |
| **usage_exporter.py** | Custom exporter — pulls OpenClaw usage RPCs, exposes on `:9479` |

### Target architecture

```
WSL2 Host Metrics     → Node Exporter      → Prometheus → Grafana
OpenClaw Metrics      → Alloy metrics      → Prometheus → Grafana
OTel / Trace Signals  → Alloy              → Tempo      → Grafana Explore
Tempo Metrics Gen     → Tempo remote_write → Prometheus
OpenClaw Usage RPCs   → usage_exporter     → Prometheus → Grafana
```

---

## Layer 1 — WSL2 Host + Network Health

**Dashboard:** `wsl2-host-network-health.json`

| Panel | Signal |
|:------|:-------|
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

| Panel | Signal |
|:------|:-------|
| Host CPU / Memory / Disk | node_exporter fundamentals |
| Failed Targets | `sum(up{job=~"prometheus|openclaw|node"} == 0)` |
| Network Throughput | Host RX/TX |
| OpenClaw Throughput | `claw_messages_processed_total` |
| AI Runtime Pressure | `claw_queue_depth`, `claw_session_stuck_total` |

---

## Layer 3 — Telemetry Pipeline Health

=== "OTel Pipeline Health"
    **Dashboard:** `otel-pipeline-health.json`

    | Panel | Signal |
    |:------|:-------|
    | Alloy Config Healthy | `alloy_config_last_load_successful` |
    | Healthy Alloy Components | `alloy_component_controller_running_components` |
    | Accepted Spans/sec | `rate(otelcol_receiver_accepted_spans_total[5m])` |
    | OTLP Receiver Span Flow | accepted / refused / failed spans |
    | Exporter Health & Backpressure | sent / send failed / queue size |

=== "OpenClaw Hero Dashboard"
    **Dashboard:** `openclaw-observability-hero.json`

    | Panel | Signal |
    |:------|:-------|
    | Telemetry Config Healthy | Alloy config load success |
    | Accepted / Sent Spans/sec | Receiver + exporter throughput |
    | OTLP HTTP Requests by Status | by status code |
    | OTLP Receiver Latency | p50 / p95 / p99 |
    | Collector Resource Footprint | Alloy resident + virtual memory |

---

## Layer 4 — Agent Runtime

**Dashboard:** `openclaw-runtime-dashboard.json`

| Panel | Signal |
|:------|:-------|
| Stuck Sessions | `claw_session_stuck_total` |
| Queue Depth | `claw_queue_depth` |
| Messages/sec (5m) | `rate(claw_messages_processed_total[5m])` |
| Queue Wait p95 | 95th percentile queue wait time |
| Queue Wait Quantiles | p50 / p95 / p99 — `claw_queue_wait_seconds` |

!!! tip
    The p50/p95/p99 latency panels are the signal that tells you whether the agent is degraded before your users notice.

---

## Layer 5 — Economics (Cost + Token Monitoring)

### Architecture

```
OpenClaw usage RPCs  →  usage_exporter.py (:9479)  →  Prometheus  →  Grafana
                                                                   ↓
                                                           Alert rules (5 rules)
```

### Key metrics

| Metric | Description |
|:-------|:------------|
| `openclaw_usage_range_totalCost` | Total cost for the day (USD) |
| `openclaw_usage_range_totalTokens` | Total tokens for the day |
| `openclaw_session_total_cost_usd` | Per-session total cost |
| `openclaw_usage_model_totalCost` | Cost split by model |
| `openclaw_usage_channel_totalCost` | Cost split by channel |

### Alert rules

| Rule | Threshold |
|:-----|:----------|
| `OpenClawDailyCostHigh` | Daily cost > $10 |
| `OpenClawDailyCostCritical` | Daily cost > $20 |
| `OpenClawSingleSessionCostSpike` | Any session > $5 |
| `OpenClawTokenBurnHigh` | > 1.5M tokens in 30 min |
| `OpenClawExporterDown` | Exporter unhealthy |

!!! warning
    Thresholds that look sensible on paper will fire immediately against real usage. Calibrate against at least one full day of live traffic before treating these as pages.

---

## Operational Checklist

- [ ] `usage_exporter.py` running on `:9479`
- [ ] Prometheus scraping `openclaw_usage` job (`up = 1`)
- [ ] All 5 alert rules loaded and evaluating
- [ ] All 8 dashboard JSONs imported into Grafana
- [ ] Tempo `/ready` returning 200
- [ ] Alloy config loaded successfully
- [ ] Alert thresholds calibrated
