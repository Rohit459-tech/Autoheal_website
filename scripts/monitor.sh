#!/usr/bin/env bash
set -euo pipefail

# Beginner-friendly defaults (override via env vars in cron if needed)
APP_URL="${APP_URL:-http://127.0.0.1/health}"   # if container maps to port 80 on the host
CONTAINER_NAME="${CONTAINER_NAME:-autoheal-flask}"
IMAGE_NAME="${IMAGE_NAME:-autoheal-flask:latest}"

timestamp() { date "+%Y-%m-%d %H:%M:%S"; }

log() {
  echo "[$(timestamp)] $*"
}

is_healthy() {
  # -f: fail on HTTP >= 400
  # --max-time: prevent hanging forever
  curl -fsS --max-time 3 "$APP_URL" >/dev/null 2>&1
}

ensure_running() {
  # If container exists but is stopped, start it. If it doesn't exist, create it.
  if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
    if docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
      return 0
    fi
    log "Container exists but is stopped. Starting: $CONTAINER_NAME"
    docker start "$CONTAINER_NAME" >/dev/null
  else
    log "Container not found. Creating: $CONTAINER_NAME from $IMAGE_NAME"
    docker run -d --name "$CONTAINER_NAME" -p 80:5000 "$IMAGE_NAME" >/dev/null
  fi
}

restart_container() {
  log "Restarting container: $CONTAINER_NAME"
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  docker run -d --name "$CONTAINER_NAME" -p 80:5000 "$IMAGE_NAME" >/dev/null
}

main() {
  # Make sure the container is at least running
  ensure_running

  if is_healthy; then
    log "Health OK ($APP_URL)"
    exit 0
  fi

 log "Health FAILED ($APP_URL). Attempting auto-heal..."
 restart_container

 # Re-check once after restart so logs are meaningful
 if is_healthy; then
   log "Auto-heal SUCCESS. Health OK after restart."
   exit 0
 fi

 log "Auto-heal attempted but health still failing. Check 'docker logs $CONTAINER_NAME'."
 exit 1
}

main "$@"

