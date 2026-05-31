#!/bin/bash
# service.sh — Manage the calendar-widget launchd service
#
# Usage:
#   ./service.sh enable    Install plist → LaunchAgents and start the service
#   ./service.sh disable   Stop the service and remove from LaunchAgents
#   ./service.sh start     Start (kick off an immediate run)
#   ./service.sh stop      Stop a currently-running job
#   ./service.sh restart   Stop then start
#   ./service.sh status    Show whether the service is loaded and last-run info
#   ./service.sh run       Run generate.sh right now (foreground, for testing)
#   ./service.sh logs      Tail the log file

set -euo pipefail

LABEL="com.tony.calendar-widget"
WIDGET_DIR="/Volumes/External_Projects/calendar_widget"
PLIST_SRC="$WIDGET_DIR/com.tony.calendar-widget.plist"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST_DEST="$LAUNCH_AGENTS/$LABEL.plist"
SCRIPT_DIR="$HOME/Library/Scripts/$LABEL"
DATA_DIR="$HOME/Library/Application Support/$LABEL"
LOG_DIR="$HOME/Library/Logs/$LABEL"
LOG="$LOG_DIR/generate.log"
UBERSICHT_WIDGETS="$HOME/Library/Application Support/Übersicht/widgets"
WIDGET_DEST="$UBERSICHT_WIDGETS/week-calendar.jsx"

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

ok()   { echo -e "${GREEN}✔${RESET} $*"; }
warn() { echo -e "${YELLOW}⚠${RESET}  $*"; }
err()  { echo -e "${RED}✘${RESET} $*" >&2; }
info() { echo -e "${CYAN}→${RESET} $*"; }

is_loaded() {
  launchctl list 2>/dev/null | grep -q "$LABEL"
}

# ── Commands ──────────────────────────────────────────────────────────────────
cmd_enable() {
  echo -e "${BOLD}Enabling calendar-widget service…${RESET}"

  if [[ ! -f "$PLIST_SRC" ]]; then
    err "Plist not found: $PLIST_SRC"; exit 1
  fi

  # Install generate.sh to a local path so launchd can read it
  # (macOS TCC blocks launchd agents from reading scripts on external volumes)
  mkdir -p "$SCRIPT_DIR" "$DATA_DIR" "$LOG_DIR" "$LAUNCH_AGENTS"
  cp "$WIDGET_DIR/generate.sh" "$SCRIPT_DIR/generate.sh"
  chmod 755 "$SCRIPT_DIR/generate.sh"
  ok "Installed generate.sh → $SCRIPT_DIR"

  # Substitute {HOME} placeholder in plist before installing
  sed "s|{HOME}|$HOME|g" "$PLIST_SRC" > "$PLIST_DEST"
  ok "Installed plist → $PLIST_DEST"

  chmod 644 "$PLIST_DEST"

  # Copy widget file directly — Übersicht cannot follow symlinks across volumes
  if [[ -d "$UBERSICHT_WIDGETS" ]]; then
    # Remove any existing symlink or stale copy first
    rm -f "$WIDGET_DEST"
    cp "$WIDGET_DIR/widget.jsx" "$WIDGET_DEST"
    ok "Copied widget.jsx → $WIDGET_DEST"
  else
    warn "Übersicht widgets folder not found at: $UBERSICHT_WIDGETS"
    warn "Copy widget.jsx there manually after installing Übersicht."
  fi

  if is_loaded; then
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
  fi

  launchctl load -w "$PLIST_DEST"
  ok "Service loaded (runs every hour + immediately at load)"
  cmd_status
}

cmd_disable() {
  echo -e "${BOLD}Disabling calendar-widget service…${RESET}"
  if is_loaded; then
    launchctl unload -w "$PLIST_DEST" 2>/dev/null && ok "Service unloaded" || warn "Could not unload"
  else
    warn "Service was not loaded"
  fi
  if [[ -f "$PLIST_DEST" ]]; then
    rm "$PLIST_DEST" && ok "Removed $PLIST_DEST"
  fi
}

cmd_start() {
  if ! is_loaded; then
    warn "Service not loaded — run './service.sh enable' first"; exit 1
  fi
  info "Kicking off an immediate run…"
  launchctl start "$LABEL" && ok "Job started" || err "launchctl start failed"
}

cmd_stop() {
  if ! is_loaded; then
    warn "Service not loaded"; exit 0
  fi
  launchctl stop "$LABEL" && ok "Job stopped" || warn "Job was not running"
}

cmd_restart() {
  cmd_stop
  sleep 1
  cmd_start
}

cmd_status() {
  echo -e "${BOLD}Service: $LABEL${RESET}"
  echo "  Plist installed : $([ -f "$PLIST_DEST" ] && echo -e "${GREEN}yes${RESET}" || echo -e "${RED}no${RESET}")"
  echo -n "  Loaded          : "
  if is_loaded; then
    echo -e "${GREEN}yes${RESET}"
    # Show PID and last exit code from launchctl list
    INFO=$(launchctl list "$LABEL" 2>/dev/null || true)
    PID=$(echo "$INFO"  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('PID','—'))" 2>/dev/null || echo "—")
    CODE=$(echo "$INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('LastExitStatus','—'))" 2>/dev/null || echo "—")
    echo "  PID             : $PID"
    echo "  Last exit code  : $CODE"
  else
    echo -e "${RED}no${RESET}"
  fi

  echo "  Data file       : $DATA_DIR/week-calendar.json"
  if [[ -f "$DATA_DIR/week-calendar.json" ]]; then
    UPDATED=$(python3 -c "import json; print(json.load(open('$DATA_DIR/week-calendar.json')).get('updated','?'))" 2>/dev/null || echo "?")
    MOD=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$DATA_DIR/week-calendar.json" 2>/dev/null || echo "?")
    echo "  Last updated    : $UPDATED (file modified $MOD)"
  else
    echo -e "  Data file       : ${RED}missing — run './service.sh run' to generate${RESET}"
  fi
}

cmd_run() {
  echo -e "${BOLD}Running generate.sh now (foreground)…${RESET}"
  if [[ -f "$SCRIPT_DIR/generate.sh" ]]; then
    bash "$SCRIPT_DIR/generate.sh"
  else
    warn "Local script not found — run './service.sh enable' first, or running from project dir…"
    bash "$WIDGET_DIR/generate.sh"
  fi
}

cmd_logs() {
  if [[ -f "$LOG" ]]; then
    tail -f "$LOG"
  else
    warn "No log file yet at $LOG"
  fi
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
case "${1:-}" in
  enable)  cmd_enable  ;;
  disable) cmd_disable ;;
  start)   cmd_start   ;;
  stop)    cmd_stop    ;;
  restart) cmd_restart ;;
  status)  cmd_status  ;;
  run)     cmd_run     ;;
  logs)    cmd_logs    ;;
  *)
    echo "Usage: $(basename "$0") {enable|disable|start|stop|restart|status|run|logs}"
    echo
    echo "  enable   Install and start the hourly launchd service"
    echo "  disable  Stop and remove the service"
    echo "  start    Trigger an immediate run (service must be enabled)"
    echo "  stop     Stop a currently-running job"
    echo "  restart  Stop then start"
    echo "  status   Show service state, PID, last exit code, data file age"
    echo "  run      Run generate.sh right now in the foreground (for testing)"
    echo "  logs     Tail the log file"
    exit 1
    ;;
esac
