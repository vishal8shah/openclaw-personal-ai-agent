# Patch v3 — Two-Lane Editorial Pass

## Philosophy

This patch applies a **two-lane editorial approach**: every version-sensitive section now clearly separates **what was actually used during setup** (historical/tested) from **what readers should use today** (current-docs recommendation). This makes the guide technically honest, current enough to be credible, and safe to attach to your name on LinkedIn.

## Changes by Category

### Transparency Framing (new in v3)
- Added transparency note in About section across security.md, README.md, and index.md
- Closing taglines updated to reference "both paths shown" framing
- All files carry the same editorial voice

### 1. Install Path — Two-Lane Treatment
- **Primary copy-paste block** now uses `https://openclaw.ai/install.sh` (current official docs)
- **Historical note** preserves `get.openclaw.ai` as "what I used" in a clearly labelled blockquote
- README quick-start updated to current URL

### 2. Config Schema — Current Docs Alignment
Seven specific schema fixes applied to match current [configuration reference](https://docs.openclaw.ai/gateway/configuration-reference):

| Item | Old (tested) | New (current docs) |
|---|---|---|
| Tool policy location | `agents.defaults.tools.allow/deny` | Top-level `tools.allow/deny` |
| Telegram allowFrom | `["123456789"]` | `["tg:123456789"]` |
| Streaming | `false` (boolean) | `"off"` (string) |
| Telegram network | `autoSelectFamily` only | Added `dnsResultOrder: "ipv4first"` |
| mDNS disable | `gateway.mDNS.enabled: false` | `OPENCLAW_DISABLE_BONJOUR=1` env var |
| `denyByDefault` | Present | Removed (not in current docs) |
| `gateway.mode` | `"local"` | Removed (not in current docs) |

- Config block now uses `json5` syntax highlighting (comments are valid)
- "What I tested" note explains all differences for users on older versions
- `config/openclaw.json.example` updated to match

### 3. Skills Guide — Trust Language + Documented Commands
- `clawhub info` removed (not in current [ClawHub docs](https://docs.openclaw.ai/tools/clawhub))
- Replaced with `clawhub search` (documented)
- "verified clean" → "reviewed before install"
- "Both are verified clean" → "Both were reviewed before install and deliberately version-tracked"
- Skills table column changed from "Verified" to "Status"
- Added note about documented vs. undocumented CLI commands

### 4. DNS Section — Reframed as Optional
- "The Step Most Guides Skip" → "Optional but Recommended"
- Added context note explaining this reflects personal troubleshooting experience
- Layer 8 summary softened to "WSL2-specific, if configured"
- Checklist section labelled "IF CONFIGURED"

### 5. mDNS Disable — Env Var Approach
- Replaced `gateway.mDNS.enabled: false` with `OPENCLAW_DISABLE_BONJOUR=1`
- Added to Part 4 (Credential Security) alongside telemetry disable
- Added to setup.sh automated script
- Security table updated
- Checklist updated

### 6. Layer Summaries — Consistent Across All Files
All three files (security.md, README.md, index.md) now have consistent layer descriptions:
- Layer 5: "DM pairing + owner ID only" (was "denyByDefault + owner ID only")
- Layer 8: "WSL2-specific, if configured" (was "no race condition, no MITM")
- Layer 10: "Reviewed, version-tracked" (was "Verified, version-tracked")

## Files Changed
- `docs/security.md` — All categories
- `docs/skills.md` — Categories 3, 4
- `docs/troubleshooting.md` — Unchanged (already correct from v2)
- `README.md` — Categories 1, 4, 6, transparency framing
- `index.md` — Categories 4, 6, transparency framing
- `config/openclaw.json.example` — Category 2
- `scripts/setup.sh` — Category 5

## Suggested Git Commit

```
docs: apply two-lane editorial pass (v3)

Separates "what I actually used" from "what readers should use today"
for all version-sensitive sections. Aligns config schema, install path,
CLI commands, and trust language with current official OpenClaw docs.
Reframes DNS section as optional. Adds OPENCLAW_DISABLE_BONJOUR env var.

Refs: docs.openclaw.ai/install, docs.openclaw.ai/gateway/configuration-reference,
      docs.openclaw.ai/tools/clawhub
```
