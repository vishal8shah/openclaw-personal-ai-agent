# Troubleshooting

Every error below was encountered during real deployment. Every fix was tested. The observability section in particular captures lessons from the hardest parts of the build — not just what to do, but why things actually went wrong.

---

## Gateway & Agent Issues

### Agent not responding on Telegram

```bash
openclaw gateway status
openclaw logs --follow
curl -v https://api.telegram.org
cat /etc/resolv.conf
```

**Common causes:** DNS overwritten after WSL2 restart, gateway crashed silently, Telegram API resolving to IPv6.

---

### DNS overwritten after system update

WSL2 regenerates `/etc/resolv.conf` on every restart by default. After any system update or WSL restart, DNS resolution silently breaks — Telegram stops responding, OpenAI API calls fail.

```bash
# Confirm it's broken
ls -la /etc/resolv.conf

# Fix
sudo rm /etc/resolv.conf
echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" | sudo tee /etc/resolv.conf
sudo chattr +i /etc/resolv.conf
```

Verify that `/etc/wsl.conf` still contains `generateResolvConf = false` — this is the permanent fix. The `chattr +i` locks the file so WSL2 cannot overwrite it even after updates.

```bash
dig api.telegram.org          # Should resolve cleanly
dig api.openai.com            # Confirm both APIs reachable
```

---

### Config validation failing

```bash
openclaw doctor
```

!!! warning
    Do not use `python3 -m json.tool` for config validation. OpenClaw config is JSON5 (supports comments and trailing commas), which strict JSON parsers reject with misleading parse errors.

**Common cause:** Trailing comma or misplaced key after manual edit. Use `openclaw config set` for individual changes rather than editing `openclaw.json` directly.

---

### Gateway not starting

```bash
ss -tlnp | grep 18789
openclaw gateway restart
openclaw doctor
```

If doctor reports config errors, fix those before attempting to restart — the gateway will abort immediately on invalid config.

---

### Gateway binding on wrong interface

The gateway should only bind to loopback. If it binds to `0.0.0.0`, it is exposed on every network interface.

```bash
# Confirm loopback-only binding
ss -tlnp | grep 18789
# Expected: 127.0.0.1:18789
# Bad: 0.0.0.0:18789
```

If you see `0.0.0.0:18789`, check `openclaw.json` for a `gateway.host` setting overriding the default.

---

### Model config reverts after gateway restart

The gateway overwrites per-agent `models.json` on every start. Editing this file directly appears to work — then silently breaks again after the next restart.

```bash
# WRONG — overwritten on every gateway start
nano ~/.openclaw/agents/main/agent/models.json

# CORRECT — source of truth
nano ~/.openclaw/openclaw.json
# Set: agents.defaults.model.primary = "openai-codex/gpt-5.4"

openclaw gateway stop
# edit openclaw.json
openclaw gateway start
```

---

### Codex quota exhausted

```bash
# ChatGPT web → Codex → Settings → Usage
# Plus: 5 hrs/day | Pro: 25 hrs/day

openclaw gateway stop
sleep 5
openclaw gateway start

cat ~/.openclaw/openclaw.json | grep -A3 '"model"'
# Should show: "primary": "openai-codex/gpt-5.4"

openclaw models set openai-codex/gpt-5.4 --fallback openai-codex/gpt-4.1-mini
```

!!! note
    For API key users, set a hard monthly spend limit at platform.openai.com → Billing → Usage limits. This is your kill switch if a runaway cron job burns through quota.

---

## Docker & Sandbox Issues

### Docker permission denied

```bash
docker ps
sudo systemctl start docker
sudo usermod -aG docker $USER
```

!!! warning
    After `usermod`, log out and back in (or restart WSL2). `newgrp docker` only works for the current shell session — it does not persist.

---

### Sandbox containers failing to start

```bash
docker run hello-world
sudo systemctl restart docker
openclaw gateway restart
```

If `hello-world` fails, Docker itself has a problem — fix that before troubleshooting the sandbox layer.

---

## Observability Stack Issues

These issues were encountered building the full five-layer observability stack. They are documented here because they cost the most time and were the least obvious.

---

### Tempo: native histogram compatibility mismatch

**Symptom:** Tempo logs flooded with `native histograms are disabled`, readiness endpoint returning errors, repeated failed remote-writes to Prometheus.

**Root cause:** Tempo config contained `generate_native_histograms: both`, but Prometheus was not configured to accept native histograms. The mismatch caused partial failures — traces were still partially flowing, making it easy to think the stack was healthy and move on too early.

```bash
# Find the bad config
sudo grep -n "native_histograms" /etc/tempo/config.yml

# Fix: change 'both' to 'none'
sudo sed -i 's/generate_native_histograms: both/generate_native_histograms: none/' /etc/tempo/config.yml

sudo systemctl restart tempo
journalctl -u tempo --no-pager -n 30
# Confirm: no more histogram errors, ready endpoint healthy
```

**Lesson:** A partially-working stack is more dangerous than a fully-broken one. Always verify readiness *and* error logs — not just whether data appears in dashboards.

---

### Tempo: remote-write failing with DNS error

**Symptom:** `lookup prometheus: no such host` in Tempo logs.

**Root cause:** Tempo config used a Docker-style hostname (`prometheus`) instead of `localhost`. This is a copy-paste artefact from Docker Compose examples — it works in Docker networking but breaks in a local WSL2 setup where everything is on localhost.

```bash
sudo grep -n "remote_write" /etc/tempo/config.yml
# Bad:  url: http://prometheus:9090/api/v1/write
# Good: url: http://localhost:9090/api/v1/write

sudo nano /etc/tempo/config.yml
# Fix the hostname, save, restart

sudo systemctl restart tempo
journalctl -u tempo --no-pager -n 20
# Confirm: no more "lookup prometheus" errors
```

---

### Prometheus not scraping all targets

**Symptom:** Node Exporter metrics absent from Grafana despite `node_exporter` running on port 9100.

**Root cause:** Prometheus config only had scrape jobs for itself and OpenClaw. The Node Exporter job was never added.

```bash
# Check what Prometheus is actually scraping
curl -s http://127.0.0.1:9090/api/v1/targets

# Add missing scrape job — use nano or tee, NOT heredoc
# (multiline terminal pastes corrupt YAML indentation — see below)
sudo nano /etc/prometheus/prometheus.yml
```

Add:

```yaml
  - job_name: node
    static_configs:
      - targets: ['localhost:9100']

  - job_name: openclaw-usage
    static_configs:
      - targets: ['localhost:9479']
```

```bash
# Always validate before restart
promtool check config /etc/prometheus/prometheus.yml

sudo systemctl restart prometheus

# Confirm targets are up
curl -s http://127.0.0.1:9090/api/v1/targets | python3 -m json.tool | grep -E '"job"|"health"'
```

---

### YAML config silently corrupted by terminal paste

This was one of the most time-consuming issues during the entire build. Multiline pastes into the WSL2 terminal repeatedly corrupted:

- YAML indentation (leading spaces stripped)
- Heredocs (closing token pasted mid-block)
- Python inline file writes
- Shell command blocks

**Effect:** The resulting files looked almost correct but failed validation. It created a false impression that Prometheus, Grafana, or the YAML itself was broken — when the real problem was the terminal mangling whitespace.

**Fix — use `tee` or `nano` instead of paste:**

```bash
# WRONG — redirect + multiline paste = corrupted indentation
sudo printf 'global:\n  scrape_interval: 15s\n' > /etc/prometheus/prometheus.yml

# ALSO WRONG — sudo doesn't own the redirect
sudo printf '...' > /etc/prometheus/prometheus.yml

# CORRECT option 1 — use nano (no paste corruption)
sudo nano /etc/prometheus/prometheus.yml

# CORRECT option 2 — write to /tmp first, then move
cat > /tmp/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
EOF
sudo mv /tmp/prometheus.yml /etc/prometheus/prometheus.yml
sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml

# Always validate after every edit
promtool check config /etc/prometheus/prometheus.yml
```

**Lesson:** Always validate config files with their own tool (`promtool`, `yamllint`, `openclaw doctor`) immediately after writing them — before restarting any service.

---

### OTel runtime metrics ≠ cost/economics data

**Symptom:** OTEL traces and Alloy metrics flowing, but no useful cost or token data in Grafana.

**Root cause:** Runtime telemetry (spans, traces, exporter health) tells you the pipeline is alive. It does not tell you how much each session cost, how many tokens were used, or which model is burning the most quota. These are fundamentally different data sources.

```
Runtime telemetry (OTEL/Alloy/Tempo):
  ✅ Is the pipeline healthy?
  ✅ Receiver latency p50/p95/p99
  ✅ Span acceptance rate
  ❌ Cost in USD
  ❌ Token usage
  ❌ Per-session economics

Native OpenClaw usage RPCs:
  ✅ Cost today (USD)
  ✅ Token totals
  ✅ Per-session cost/token breakdown
  ✅ Model/channel/provider breakdown
  ❌ Infrastructure health
```

**Fix:** Use the native OpenClaw usage exporter (`usage_exporter.py`) to scrape the usage RPCs and expose them as Prometheus metrics. OTEL handles runtime; native usage RPCs handle economics.

```bash
# Verify the usage exporter is running
curl -s http://127.0.0.1:9479/metrics | grep openclaw_cost

# Check Prometheus is scraping it
curl -s 'http://127.0.0.1:9090/api/v1/query?query=up{job="openclaw-usage"}'
```

---

### Usage exporter: date format rejection

**Symptom:** Usage exporter returns errors on startup; no metrics exposed on port 9479.

**Root cause:** The initial exporter implementation passed full ISO timestamps to the usage API. The API expected plain dates only: `YYYY-MM-DD`.

```python
# WRONG
start_date = datetime.utcnow().isoformat()          # "2026-03-13T00:00:00"

# CORRECT
start_date = datetime.utcnow().strftime("%Y-%m-%d")  # "2026-03-13"
```

**Lesson:** When an exporter or API integration fails on startup, confirm the contract first — parameter format, field names, payload shape — before assuming the exporter logic itself is wrong.

---

### Grafana provisioning not loading dashboards

**Symptom:** Dashboards not appearing in Grafana despite placing JSON files in the provisioning directory.

**Root cause:** Two simultaneous problems — the dashboard directory was empty (file copy step missed), *and* the provider YAML had broken indentation from terminal paste corruption.

```bash
# Check if the dashboard files actually landed
ls -la /etc/grafana/provisioning/dashboards/

# Check provider YAML is valid
cat /etc/grafana/provisioning/dashboards/dashboards.yaml
# Should be properly indented YAML — not a flat string

# Check Grafana logs for provisioning errors
journalctl -u grafana-server --no-pager -n 40 | grep -i provision
```

**Fastest reliable fix:** Manual import via Grafana UI (Dashboards → Import → Upload JSON). This bypasses the provisioning layer entirely and works immediately.

```
Grafana UI → Dashboards → Import → Upload JSON file
```

**Lesson:** When the environment has repeated tooling friction (paste corruption, YAML issues), manual import is not a workaround — it is the right engineering decision.

---

### Grafana dashboard panels showing "No data"

**Symptom:** Dashboard loads but panels show "No data" or nonsensical percentages.

**Root cause:** Early dashboards were built against assumed metric names rather than confirmed ones. PromQL queries referenced metrics that did not exist in the actual scrape targets.

```bash
# Inventory what metrics actually exist
curl -s http://127.0.0.1:9479/metrics | grep '^openclaw' | awk -F'{' '{print $1}' | sort -u
curl -s http://127.0.0.1:9100/metrics | grep '^node_' | awk -F'{' '{print $1}' | sort -u | head -30
curl -s http://127.0.0.1:3200/metrics | grep -v '^#' | awk -F'{' '{print $1}' | sort -u | head -20

# Test a specific PromQL query before building a panel
curl -s 'http://127.0.0.1:9090/api/v1/query?query=openclaw_cost_total_usd' | python3 -m json.tool
```

**Workflow:** Always inventory real metrics first → build PromQL queries in Prometheus Explore → only then build a Grafana panel.

---

### Prometheus alert thresholds fire immediately

**Symptom:** Alerts move to `pending` immediately after rules load, before any real event occurs.

**Root cause:** Initial thresholds were set too low without baselining from real usage data. For example:

- `openclaw_daily_cost_high` threshold of $10 — hit during normal main-session usage
- `openclaw_session_cost_spike` threshold of $5 — exceeded by a single long session
- Token burn threshold — too sensitive for background cron job activity

```bash
# Check what alerts are currently pending/firing
curl -s http://127.0.0.1:9090/api/v1/alerts | python3 -m json.tool

# Check current actual values to calibrate thresholds
curl -s 'http://127.0.0.1:9090/api/v1/query?query=openclaw_cost_total_usd' | python3 -m json.tool
curl -s 'http://127.0.0.1:9090/api/v1/query?query=openclaw_tokens_total' | python3 -m json.tool
```

After baselining from 3–5 days of real usage:

```yaml
# Example calibrated thresholds (adjust to your actual usage pattern)
- alert: OpenClawDailyCostHigh
  expr: openclaw_cost_total_usd > 15       # was 10 — too low
  for: 5m

- alert: OpenClawSessionCostSpike
  expr: openclaw_session_cost_usd_max > 8  # was 5 — too low
  for: 1m
```

**Lesson:** The first alert thresholds are almost always wrong. You do not learn the right values in theory — you learn them from real system behaviour.

---

## Health Monitoring

### healthchecks.io not receiving pings

```bash
curl -fsS https://hc-ping.com/YOUR_UUID
crontab -l
openclaw health --json
```

Confirm the cron entry uses the full binary path:

```bash
crontab -e
# */5 * * * * /usr/local/bin/openclaw health --quiet && curl -fsS https://hc-ping.com/YOUR_UUID
```

---

## Related Guides

- [Security Guide](security.md) — hardening, config reference, security checklist
- [Observability Guide](observability.md) — Prometheus, Grafana, Tempo, cost monitoring
- [Skills Guide](skills.md) — safe skill installation and version pinning
