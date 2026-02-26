---
layout: default
title: "Skills Guide"
nav_order: 3
---

# Safe Skill Installation Guide

## Before Installing Any Skill

1. **Check verification status:**
   ```bash
   clawdhub info SKILL_NAME
   ```
   Look for `Verified: true` and `ClawHavoc: clean` in the output.

2. **Review the skill's source** — check the linked repository for recent activity, open issues, and maintainer reputation.

3. **Never install skills from unverified sources** — the ClawHavoc campaign demonstrated how easy it is to publish malicious skills.

## Recommended Skills

| Skill | Purpose | Verified |
|---|---|---|
| nano-pdf | Document analysis and PDF processing | ✅ |
| playwright-mcp | Web automation and browsing | ✅ |

## Installing

```bash
clawdhub install nano-pdf
clawdhub install playwright-mcp
```

## Version Pinning

After installation, pin the exact version in your `openclaw.json`:

```bash
clawdhub list --installed    # Note version numbers
```

Update the `skills` section of your config with the exact versions. Never use `latest` — a compromised update would be auto-installed on next restart.

## Updating Skills

```bash
# Check for updates
clawdhub outdated

# Review changelog before updating
clawdhub info SKILL_NAME --changelog

# Update specific skill
clawdhub update SKILL_NAME

# Re-pin the new version in openclaw.json
```

Always review the changelog before updating. Update one skill at a time and verify agent behaviour after each update.
