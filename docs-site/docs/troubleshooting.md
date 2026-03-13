# Troubleshooting

Every error below was encountered during real deployment. Every fix was tested.

---

## Agent not responding on Telegram

```bash
openclaw gateway status
openclaw logs --follow
curl -v https://api.telegram.org
cat /etc/resolv.conf
```

**Common causes:** DNS overwritten after WSL2 restart, gateway crashed silently, Telegram API resolving to IPv6.

---

## DNS overwritten after system update

```bash
ls -la /etc/resolv.conf

sudo rm /etc/resolv.conf
echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" | sudo tee /etc/resolv.conf
sudo chattr +i /etc/resolv.conf
```

Verify that `/etc/wsl.conf` still contains `generateResolvConf = false` — this is the primary permanent fix.

---

## Config validation failing

```bash
openclaw doctor
```

!!! warning
    Do not use `python3 -m json.tool` for config validation. OpenClaw config is JSON5 (supports comments and trailing commas), which strict JSON parsers will reject.

**Common cause:** Trailing comma or misplaced key after manual edit. Use `openclaw config set` for individual changes.

---

## Gateway not starting

```bash
ss -tlnp | grep 18789
openclaw gateway restart
openclaw doctor
```

---

## Docker permission denied

```bash
docker ps
sudo systemctl start docker
sudo usermod -aG docker $USER
```

!!! warning
    After `usermod`, log out and back in (or restart WSL2). `newgrp docker` only works for the current shell session.

---

## Sandbox containers failing to start

```bash
docker run hello-world
sudo systemctl restart docker
openclaw gateway restart
```

---

## Codex quota exhausted

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
    The gateway overwrites per-agent `models.json` on every start. Set the model in `~/.openclaw/openclaw.json` — not the per-agent cache file.

---

## Model config reverts after gateway restart

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

## healthchecks.io not receiving pings

```bash
curl -fsS https://hc-ping.com/YOUR_UUID
crontab -l
openclaw health --json
```

---

## Related Guides

- [Security Guide](security.md) — hardening, config reference, security checklist
- [Observability Guide](observability.md) — Prometheus, Grafana, Tempo, cost monitoring
- [Skills Guide](skills.md) — safe skill installation and version pinning
