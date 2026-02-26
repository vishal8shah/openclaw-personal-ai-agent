#!/bin/bash
# OpenClaw Health Check + External Ping
# Usage: bash healthcheck.sh [HEALTHCHECKS_IO_UUID]
# Crontab: */5 * * * * /path/to/healthcheck.sh YOUR_UUID

set -euo pipefail

UUID="${1:-}"

# Run OpenClaw health check
if openclaw health --json > /dev/null 2>&1; then
    # Agent healthy — ping healthchecks.io if UUID provided
    if [ -n "$UUID" ]; then
        curl -fsS --retry 3 "https://hc-ping.com/$UUID" > /dev/null 2>&1
    fi
    exit 0
else
    # Agent unhealthy — ping failure endpoint
    if [ -n "$UUID" ]; then
        curl -fsS --retry 3 "https://hc-ping.com/$UUID/fail" > /dev/null 2>&1
    fi
    exit 1
fi
