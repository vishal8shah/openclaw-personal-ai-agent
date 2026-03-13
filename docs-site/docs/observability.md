# Observability — Monitoring Your OpenClaw Agent

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
**Purpose:** Infrastructure baseline. Eliminates the host as a suspect before investigating the agent stack.

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
**Purpose:** One view bridging machine health and agent activity. The fastest triage starting point.

| Panel | Signal |
|:------|:-------|
| Host CPU / Memory / Disk | node_exporter fundamentals |
| Failed Targets | `sum(up{job=~"prometheus|openclaw|node"} == 0)` |
| Network Throughput | Host RX/TX |
| Host Uptime | `node_time_seconds - node_boot_time_seconds` |
| OpenClaw Throughput | `claw_messages_processed_total` |
| AI Runtime Pressure | `claw_queue_depth`, `claw_session_stuck_total` |

---

## Layer 3 — Telemetry Pipeline Health

Two dashboards cover this layer.

=== "OTel Pipeline Health"
    **Dashboard:** `otel-pipeline-health.json`

    | Panel | Signal |
    |:------|:-------|
    | Alloy Config Healthy | `alloy_config_last_load_successful` |
    | Healthy Alloy Components | `alloy_component_controller_running_components` |
    | Alloy Eval Queue | `alloy_component_evaluation_queue_size` |
    | Accepted Spans/sec | `rate(otelcol_receiver_accepted_spans_total[5m])` |
    | OTLP Receiver Span Flow | accepted / refused / failed spans |
    | Exporter Health & Backpressure | sent / send failed / queue size |
    | Telemetry Process Memory | Alloy + Tempo resident memory |
    | Tempo Ingest Signals | distributor spans / receiver accepted / discarded |

=== "OpenClaw Observability Hero"
    **Dashboard:** `openclaw-observability-hero.json`  
    **Purpose:** Telemetry-pipeline-level observability for OpenClaw specifically — watching the watcher.

    | Panel | Signal |
    |:------|:-------|
    | Telemetry Config Healthy | Alloy config load success |
    | Alloy Evaluation Queue | Queue depth |
    | Accepted / Sent Spans/sec | Receiver + exporter throughput |
    | OTLP HTTP Requests by Status | `http_server_request_duration_seconds` by status code |
    | OTLP Receiver Latency | p50 / p95 / p99 |
    | Collector Resource Footprint | Alloy resident + virtual memory, host RX/TX |

!!! warning
    If the collector or export path is broken, your observability is an illusion. This dashboard is where you detect that.

---

## Layer 4 — Agent Runtime Observability

**Dashboard:** `openclaw-runtime-dashboard.json`  
**Purpose:** Operational health of the agent itself — not just “is it alive” but “is it healthy”.

| Panel | Signal |
|:------|:-------|
| Stuck Sessions | `claw_session_stuck_total` |
| Queue Depth | `claw_queue_depth` |
| Messages/sec (5m) | `rate(claw_messages_processed_total[5m])` |
| Queue Wait p95 | 95th percentile queue wait time |
| Message Throughput by Kind | Split by message kind |
| Queue Wait Quantiles | p50 / p95 / p99 — `claw_queue_wait_seconds` |

!!! tip
    The p50/p95/p99 latency panels are the signal that tells you whether the agent is degraded before your users notice.

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
|:-------|:------------|
| `openclaw_usage_range_totalCost` | Total cost for the day (USD) |
| `openclaw_usage_range_totalTokens` | Total tokens for the day |
| `openclaw_session_total_cost_usd` | Per-session total cost |
| `openclaw_session_total_tokens` | Per-session total tokens |
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

## Troubleshooting

### Tempo native histogram mismatch

**Symptom:** Tempo logs show `native histograms are disabled`.

**Fix:** Set `generate_native_histograms: none` in `/etc/tempo/config.yml`. Restart Tempo.

### Prometheus not scraping usage exporter

**Symptom:** `up{job="openclaw_usage"}` returns empty or 0.

1. `curl http://localhost:9479/healthz` — is the exporter running?
2. Is the scrape job in `prometheus.yml`?
3. Did you run `promtool check config` and restart?

### YAML indentation corruption

**Rule:** Always run `promtool check config` before restarting. Use `sudo tee` not `sudo >` for privileged writes.

### Grafana provisioning fails / panels blank

**Practical path:** Import dashboard JSON manually via Grafana UI → Dashboards → Import.

---

## Operational Checklist

- [ ] `usage_exporter.py` running on `:9479`
- [ ] Prometheus scraping `openclaw_usage` job (`up = 1`)
- [ ] All 5 alert rules loaded and evaluating
- [ ] All 8 dashboard JSONs imported into Grafana
- [ ] Tempo `/ready` returning 200
- [ ] Alloy config loaded successfully
- [ ] No persistent exporter backpressure errors in Alloy logs
- [ ] Alert thresholds calibrated

---

## Related Guides

- [Security Guide](security.md) — harden the agent before instrumenting it
- [Troubleshooting](troubleshooting.md) — OpenClaw errors, DNS, Docker, Codex quota
- [Skills Guide](skills.md) — safe skill installation
