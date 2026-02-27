---
layout: default
title: "Skills Guide"
nav_order: 3
---

# Safe Skill Installation Guide

> **Note:** The ClawHub CLI was originally distributed as `clawdhub` in earlier releases and has since been renamed to `clawhub`. This guide uses the current name. If you installed during the earlier period, both names should work.

## Before Installing Any Skill

1. **Search and review before installing:**
   ```bash
   clawhub search "SKILL_NAME"
   ```
   Check the skill page on [clawhub.ai](https://clawhub.ai) for community feedback, stars, and version history.

2. **Review the skill's source** — check the linked repository for recent activity, open issues, and maintainer reputation.

3. **Never install skills from unreviewed sources** — the ClawHavoc campaign demonstrated how easy it is to publish malicious skills.

> **Note on CLI commands:** The current documented ClawHub commands are `search`, `install`, `update`, `list`, `publish`, and `sync`. See [docs.openclaw.ai/tools/clawhub](https://docs.openclaw.ai/tools/clawhub) for the full reference. Other commands may exist in some versions but are not in the current public docs.

## Recommended Skills

| Skill | Purpose | Status |
|---|---|---|
| nano-pdf | Document analysis and PDF processing | Reviewed before install |
| playwright-mcp | Web automation and browsing | Reviewed before install |

## Installing

```bash
clawhub install nano-pdf
clawhub install playwright-mcp
```

## Version Tracking

ClawHub tracks installed skill versions in `.clawhub/lock.json` under your workspace directory. This lockfile records the exact version hash of each skill, ensuring reproducible installs.

```bash
# View installed skills and versions
clawhub list
```

Never rely on `latest` — a compromised update would be auto-installed. The lockfile ensures you upgrade consciously after reviewing changelogs.

## Updating Skills

```bash
# Update a specific skill (after reviewing changelog)
clawhub update SKILL_NAME

# Update all installed skills
clawhub update --all
```

Always review the changelog before updating. Update one skill at a time and verify agent behaviour after each update.

> **Note on `clawhub sync`:** The `sync` command scans local skills and publishes new or updated ones to the registry — it is a **publish/backup workflow**, not an update mechanism. To check for and apply upstream updates to installed skills, use `clawhub update`.
