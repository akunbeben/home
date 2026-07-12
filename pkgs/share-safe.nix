{ pkgs }:
pkgs.writeShellScriptBin "share-safe" ''
  set -euo pipefail

  AEROSPACE=$(command -v aerospace || true)
  if [ -z "$AEROSPACE" ] && [ -x /opt/homebrew/bin/aerospace ]; then
    AEROSPACE=/opt/homebrew/bin/aerospace
  fi

  if [ -z "$AEROSPACE" ]; then
    echo "Error: aerospace command not found" >&2
    exit 1
  fi

  STATE_DIR="''${TMPDIR:-/tmp}/share-safe-$UID"
  PID_FILE="$STATE_DIR/watchdog.pid"
  SAFE_WORKSPACE_FILE="$STATE_DIR/last-safe-workspace"
  EVENT_PIPE="$STATE_DIR/events"
  LOG_FILE="$STATE_DIR/watchdog.log"

  notify() {
    /usr/bin/osascript -e "display notification \"$1\" with title \"Share Safe\"" \
      >/dev/null 2>&1 || true
  }

  current_workspace() {
    "$AEROSPACE" list-workspaces --focused
  }

  current_mode() {
    "$AEROSPACE" list-modes --current
  }

  watchdog_running() {
    [ -f "$PID_FILE" ] || return 1
    pid=$(<"$PID_FILE")
    kill -0 "$pid" 2>/dev/null
  }

  start_guard() {
    mkdir -p "$STATE_DIR"

    workspace=$(current_workspace)
    case "$workspace" in
      1|2|3|4)
        safe_workspace=$workspace
        ;;
      *)
        safe_workspace=1
        "$AEROSPACE" workspace "$safe_workspace"
        ;;
    esac
    printf '%s\n' "$safe_workspace" > "$SAFE_WORKSPACE_FILE"

    "$AEROSPACE" mode present

    if watchdog_running; then
      echo "Share Safe is already on (workspace $safe_workspace)"
      exit 0
    fi

    /usr/bin/nohup "$0" _watch > "$LOG_FILE" 2>&1 &
    watchdog_pid=$!
    printf '%s\n' "$watchdog_pid" > "$PID_FILE"

    echo "Share Safe is on; workspaces 1-4 are shareable"
    notify "On — workspaces 5-8 are blocked"
  }

  stop_guard() {
    if watchdog_running; then
      pid=$(<"$PID_FILE")
      kill "$pid" 2>/dev/null || true
    fi

    rm -f "$PID_FILE" "$SAFE_WORKSPACE_FILE" "$EVENT_PIPE"
    "$AEROSPACE" mode main

    echo "Share Safe is off"
    notify "Off"
  }

  watch_guard() {
    mkdir -p "$STATE_DIR"
    rm -f "$EVENT_PIPE"
    /usr/bin/mkfifo "$EVENT_PIPE"

    subscriber_pid=
    cleanup() {
      if [ -n "$subscriber_pid" ]; then
        kill "$subscriber_pid" 2>/dev/null || true
      fi
      if [ -f "$PID_FILE" ] && [ "$(<"$PID_FILE")" = "$$" ]; then
        rm -f "$PID_FILE"
      fi
      rm -f "$EVENT_PIPE"
    }
    trap cleanup EXIT
    trap 'exit 0' HUP INT TERM

    "$AEROSPACE" subscribe --no-send-initial focus-changed mode-changed > "$EVENT_PIPE" &
    subscriber_pid=$!

    while IFS= read -r event; do
      case "$event" in
        *'"_event":"focus-changed"'*)
          workspace=$(printf '%s\n' "$event" | /usr/bin/sed -n \
            's/.*"workspace"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
          case "$workspace" in
            1|2|3|4)
              printf '%s\n' "$workspace" > "$SAFE_WORKSPACE_FILE"
              ;;
            "")
              ;;
            *)
              safe_workspace=$(<"$SAFE_WORKSPACE_FILE")
              notify "Blocked workspace $workspace"
              "$AEROSPACE" workspace "$safe_workspace" || "$AEROSPACE" workspace 1
              ;;
          esac
          ;;
        *'"_event":"mode-changed"'*)
          mode=$(printf '%s\n' "$event" | /usr/bin/sed -n \
            's/.*"mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
          [ "$mode" = present ] || break
          ;;
      esac
    done < "$EVENT_PIPE"

    if [ "$(current_mode)" = present ]; then
      notify "Warning — watchdog stopped"
    fi
  }

  show_status() {
    mode=$(current_mode)
    workspace=$(current_workspace)
    if watchdog_running; then
      echo "Share Safe: on (workspace $workspace, mode $mode)"
    elif [ "$mode" = present ]; then
      echo "Share Safe: degraded (watchdog stopped, mode $mode)"
    else
      echo "Share Safe: off (workspace $workspace, mode $mode)"
    fi
  }

  case "''${1:-}" in
    on)
      start_guard
      ;;
    off)
      stop_guard
      ;;
    status)
      show_status
      ;;
    _watch)
      watch_guard
      ;;
    *)
      echo "Usage: share-safe {on|off|status}" >&2
      exit 1
      ;;
  esac
''
