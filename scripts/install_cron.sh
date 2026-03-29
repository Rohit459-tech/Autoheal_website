#!/usr/bin/env bash
set -euo pipefail

# Installs a cron entry to run monitor.sh every minute.
# Usage (on EC2): sudo bash scripts/install_cron.sh

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MONITOR="$PROJECT_DIR/scripts/monitor.sh"
LOG_FILE="/var/log/autoheal-monitor.log"

if [[ ! -x "$MONITOR" ]]; then
  echo "ERROR: $MONITOR is not executable. Run: chmod +x $MONITOR"
  exit 1
fi

CRON_LINE="* * * * * APP_URL=http://127.0.0.1/health CONTAINER_NAME=autoheal-flask IMAGE_NAME=autoheal-flask:latest $MONITOR >> $LOG_FILE 2>&1"

# Write root crontab (recommended because Docker usually requires root, unless you've configured docker group)
tmp="$(mktemp)"
sudo crontab -l 2>/dev/null | grep -v "scripts/monitor.sh" > "$tmp" || true
echo "$CRON_LINE" >> "$tmp"
sudo crontab "$tmp"
rm -f "$tmp"

echo "Installed cron:"
sudo crontab -l | grep "scripts/monitor.sh" || true
echo "Logs will be written to: $LOG_FILE"

