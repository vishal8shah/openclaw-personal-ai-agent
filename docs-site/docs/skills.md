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

3. **Never install from unreviewed sources** — the ClawHavoc campaign demonstrated how easy it is to publish malicious skills.

---

## Recommended Skills

| Skill | Purpose |
|:------|:--------|
| nano-pdf | Document analysis and PDF processing |
| playwright-mcp | Web automation and browsing |

---

## Installing

```bash
clawhub install nano-pdf
clawhub install playwright-mcp
```

---

## Version Tracking

ClawHub tracks installed skill versions in `.clawhub/lock.json`. Never rely on `latest` — a compromised update would be auto-installed.

```bash
clawhub list
```

---

## Updating Skills

```bash
clawhub update SKILL_NAME
clawhub update --all
```

Always review the changelog before updating. Update one skill at a time and verify agent behaviour after each update.

!!! warning
    `clawhub sync` publishes local skills to the registry — it is a publish/backup workflow, not an update mechanism.
