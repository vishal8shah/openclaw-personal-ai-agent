# Safe Skill Installation Guide

Version-pinned, reviewed-before-install. The ClawHavoc campaign showed why this matters.

!!! note
    The ClawHub CLI was originally distributed as `clawdhub` and has since been renamed to `clawhub`. Both names work if you installed during the earlier period.

---

## Before Installing Any Skill

1. **Search and review before installing:**
   ```bash
   clawhub search "SKILL_NAME"
   ```
   Check the skill page on [clawhub.ai](https://clawhub.ai) for community feedback, stars, and version history.

2. **Review the skill’s source** — check the linked repository for recent activity, open issues, and maintainer reputation.

3. **Never install skills from unreviewed sources** — the ClawHavoc campaign demonstrated how easy it is to publish malicious skills.

!!! note
    Current documented commands are `search`, `install`, `update`, `list`, `publish`, and `sync`. See [docs.openclaw.ai/tools/clawhub](https://docs.openclaw.ai/tools/clawhub) for the full reference.

---

## Recommended Skills

| Skill | Purpose | Status |
|:------|:--------|:-------|
| nano-pdf | Document analysis and PDF processing | Reviewed before install |
| playwright-mcp | Web automation and browsing | Reviewed before install |

---

## Installing

```bash
clawhub install nano-pdf
clawhub install playwright-mcp
```

---

## Version Tracking

ClawHub tracks installed skill versions in `.clawhub/lock.json`. This lockfile records the exact version hash of each skill.

```bash
clawhub list
```

Never rely on `latest` — a compromised update would be auto-installed. The lockfile ensures you upgrade consciously.

---

## Updating Skills

```bash
clawhub update SKILL_NAME
clawhub update --all
```

Always review the changelog before updating. Update one skill at a time and verify agent behaviour after each update.

!!! warning
    `clawhub sync` publishes local skills to the registry — it is a publish/backup workflow, not an update mechanism.

---

## Related Guides

- [Security Guide](security.md) — full hardening walkthrough including skill security (Part 5)
- [Observability Guide](observability.md) — monitor agent health and cost after adding skills
- [Troubleshooting](troubleshooting.md) — Docker, gateway, and Codex quota fixes
