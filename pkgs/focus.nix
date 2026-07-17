{ pkgs }:
pkgs.writeShellScriptBin "focus" ''
  set -euo pipefail

  STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/focus"
  CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/focus"
  SESSION_FILE="$STATE_DIR/session"
  PID_FILE="$STATE_DIR/worker.pid"
  SITES_FILE="$STATE_DIR/sites"
  TICK_FILE="$STATE_DIR/ticking"
  ROOT_LOG="$STATE_DIR/blocker.log"
  WORKER_LOG="$STATE_DIR/worker.log"
  START_SOUND="/System/Library/Sounds/Glass.aiff"
  END_SOUND="/System/Library/Sounds/Hero.aiff"
  TICK_SOUND="${../tick.mp3}"

  usage() {
    echo "Usage: focus [start [minutes]|stop|status|sound|silent]" >&2
  }

  now() {
    /bin/date +%s
  }

  format_remaining() {
    local total=$1
    printf '%02d:%02d\n' "$((total / 60))" "$((total % 60))"
  }

  valid_minutes() {
    local value=$1
    [[ "$value" =~ ^[0-9]{1,4}$ ]] || return 1
    value=$((10#$value))
    ((value >= 1 && value <= 1440))
  }

  valid_token() {
    [[ "$1" =~ ^[0-9]+-[0-9]+-[0-9]+$ ]]
  }

  load_session() {
    [ -r "$SESSION_FILE" ] || return 1
    read -r SESSION_TOKEN SESSION_END < "$SESSION_FILE"
    valid_token "$SESSION_TOKEN" || return 1
    [[ "$SESSION_END" =~ ^[0-9]{1,12}$ ]]
  }

  clear_state() {
    /bin/rm -f "$SESSION_FILE" "$PID_FILE" "$SITES_FILE" "$TICK_FILE"
  }

  play_sound() {
    /usr/bin/afplay "$1" >/dev/null 2>&1 &
  }

  current_hosts_token() {
    /usr/bin/awk '/^# focus:block:start / { token = $3 } END { print token }' /etc/hosts
  }

  write_sites() {
    /bin/mkdir -p "$STATE_DIR"
    if [ -f "$CONFIG_DIR/sites" ]; then
      /bin/cp "$CONFIG_DIR/sites" "$SITES_FILE"
      return
    fi

    # ponytail: hosts files need explicit domains; use a Network Extension for wildcard blocking.
    printf '%s\n' \
      youtube.com www.youtube.com m.youtube.com youtu.be \
      netflix.com www.netflix.com \
      twitch.tv www.twitch.tv \
      reddit.com www.reddit.com old.reddit.com \
      x.com www.x.com twitter.com www.twitter.com \
      instagram.com www.instagram.com \
      facebook.com www.facebook.com \
      tiktok.com www.tiktok.com \
      primevideo.com www.primevideo.com \
      disneyplus.com www.disneyplus.com \
      open.spotify.com > "$SITES_FILE"
  }

  strip_focus_block() {
    /usr/bin/awk '
      /^# focus:block:start / { blocked = 1; next }
      /^# focus:block:end / { blocked = 0; next }
      !blocked { print }
    ' /etc/hosts > "$1"
  }

  install_hosts() {
    local file=$1
    /usr/sbin/chown root:wheel "$file"
    /bin/chmod 0644 "$file"
    /bin/mv "$file" /etc/hosts
    /usr/bin/dscacheutil -flushcache
    /usr/bin/killall -HUP mDNSResponder >/dev/null 2>&1 || true
  }

  hosts_on() {
    local token=$1
    local sites=$2
    local domain count=0
    local -a domains=()

    valid_token "$token" || { echo "Error: invalid focus token" >&2; return 1; }
    [ -f "$sites" ] || { echo "Error: sites file not found" >&2; return 1; }

    while IFS= read -r domain || [ -n "$domain" ]; do
      case "$domain" in
        ""|\#*) continue ;;
      esac
      if ! printf '%s\n' "$domain" | /usr/bin/grep -Eq '^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$' \
        || [[ "$domain" == *'..'* ]]; then
        echo "Error: invalid domain in $sites: $domain" >&2
        return 1
      fi
      count=$((count + 1))
      ((count <= 200)) || { echo "Error: sites file exceeds 200 domains" >&2; return 1; }
      domains+=("$domain")
    done < "$sites"
    ((count > 0)) || { echo "Error: sites file is empty" >&2; return 1; }

    local tmp
    tmp=$(/usr/bin/mktemp /etc/hosts.focus.XXXXXX)
    strip_focus_block "$tmp"
    {
      printf '\n# focus:block:start %s\n' "$token"
      for domain in "''${domains[@]}"; do
        printf '0.0.0.0 %s\n::1 %s\n' "$domain" "$domain"
      done
      printf '# focus:block:end %s\n' "$token"
    } >> "$tmp"
    install_hosts "$tmp"
  }

  hosts_off() {
    local token=$1
    valid_token "$token" || { echo "Error: invalid focus token" >&2; return 1; }
    [ "$(current_hosts_token)" = "$token" ] || return 0

    local tmp
    tmp=$(/usr/bin/mktemp /etc/hosts.focus.XXXXXX)
    strip_focus_block "$tmp"
    install_hosts "$tmp"
  }

  root_guard() {
    local token=$1
    local end=$2
    local sites=$3
    [ "$EUID" -eq 0 ] || { echo "Error: blocker must run as root" >&2; exit 1; }
    valid_token "$token" || { echo "Error: invalid focus token" >&2; exit 1; }
    [[ "$end" =~ ^[0-9]{1,12}$ ]] || { echo "Error: invalid end time" >&2; exit 1; }

    trap 'hosts_off "$token" || true' EXIT
    trap 'exit 0' HUP INT TERM
    hosts_on "$token" "$sites"

    local remaining=$((end - $(now)))
    if ((remaining > 0)); then
      /bin/sleep "$remaining"
    fi
  }

  finish_session() {
    local token=$1
    local end=$2
    local remaining

    remaining=$((end - $(now)))
    if ((remaining > 0)); then
      /bin/sleep "$remaining"
    fi
    while [ "$(now)" -lt "$end" ]; do
      /bin/sleep 1
    done

    load_session || exit 0
    [ "$SESSION_TOKEN" = "$token" ] || exit 0
    clear_state
    play_sound "$END_SOUND"
  }

  tick_session() {
    local token=$1
    local end=$2
    local audio_pid
    while [ -e "$TICK_FILE" ]; do
      load_session || break
      [ "$SESSION_TOKEN" = "$token" ] || break
      [ "$(now)" -lt "$end" ] || break
      /usr/bin/afplay "$TICK_SOUND" >/dev/null 2>&1 &
      audio_pid=$!
      while kill -0 "$audio_pid" 2>/dev/null; do
        if [ ! -e "$TICK_FILE" ] || ! load_session \
          || [ "$SESSION_TOKEN" != "$token" ] || [ "$(now)" -ge "$end" ]; then
          kill "$audio_pid" 2>/dev/null || true
          wait "$audio_pid" 2>/dev/null || true
          return
        fi
        /bin/sleep 0.2
      done
      wait "$audio_pid" 2>/dev/null || true
    done
  }

  sound_on() {
    if ! load_session || [ "$SESSION_END" -le "$(now)" ]; then
      echo "Error: focus is inactive" >&2
      exit 1
    fi
    if [ -e "$TICK_FILE" ]; then
      echo "Clock ticking is already on"
      return
    fi

    printf '%s\n' "$SESSION_TOKEN" > "$TICK_FILE"
    /usr/bin/nohup "$0" _tick "$SESSION_TOKEN" "$SESSION_END" >/dev/null 2>&1 &
    echo "Clock ticking on"
  }

  sound_off() {
    /bin/rm -f "$TICK_FILE"
    echo "Clock ticking off"
  }

  start_session() {
    local minutes=$1
    valid_minutes "$minutes" || {
      echo "Error: minutes must be between 1 and 1440" >&2
      exit 1
    }
    minutes=$((10#$minutes))

    if load_session && [ "$SESSION_END" -gt "$(now)" ]; then
      echo "Focus is already active ($(format_remaining "$((SESSION_END - $(now)))") remaining)" >&2
      exit 1
    fi

    clear_state
    write_sites

    local started end token guard_pid="" ready=0 setup_complete=0
    started=$(now)
    end=$((started + minutes * 60))
    token="$started-$$-$RANDOM"

    cleanup_start() {
      [ "$setup_complete" -eq 0 ] || return
      if [ -n "$guard_pid" ] && kill -0 "$guard_pid" 2>/dev/null; then
        kill "$guard_pid" 2>/dev/null || true
        wait "$guard_pid" 2>/dev/null || true
      fi
      /usr/bin/sudo -n "$0" _unblock "$token" >/dev/null 2>&1 || true
      clear_state
    }
    trap cleanup_start EXIT
    trap 'exit 130' HUP INT TERM

    /usr/bin/sudo -v
    /usr/bin/nohup /usr/bin/sudo -n "$0" _guard "$token" "$end" "$SITES_FILE" \
      > "$ROOT_LOG" 2>&1 &
    guard_pid=$!

    for _ in {1..40}; do
      if /usr/bin/grep -Fqx "# focus:block:start $token" /etc/hosts; then
        ready=1
        break
      fi
      kill -0 "$guard_pid" 2>/dev/null || break
      /bin/sleep 0.1
    done

    if [ "$ready" -ne 1 ]; then
      wait "$guard_pid" 2>/dev/null || true
      echo "Error: website blocker failed to start" >&2
      [ -s "$ROOT_LOG" ] && /bin/cat "$ROOT_LOG" >&2
      exit 1
    fi

    printf '%s %s\n' "$token" "$end" > "$SESSION_FILE.tmp"
    /bin/mv "$SESSION_FILE.tmp" "$SESSION_FILE"
    /usr/bin/nohup "$0" _finish "$token" "$end" > "$WORKER_LOG" 2>&1 &
    printf '%s\n' "$!" > "$PID_FILE"
    setup_complete=1
    trap - EXIT HUP INT TERM
    play_sound "$START_SOUND"
    echo "Focus started for $minutes minutes"
  }

  stop_session() {
    local token pid
    token=""
    if load_session; then
      token=$SESSION_TOKEN
    else
      token=$(current_hosts_token)
    fi

    if ! valid_token "$token"; then
      clear_state
      echo "Focus is inactive"
      return
    fi

    if [ "$(current_hosts_token)" = "$token" ]; then
      /usr/bin/sudo "$0" _unblock "$token"
    fi

    if [ -r "$PID_FILE" ]; then
      read -r pid < "$PID_FILE"
      [[ "$pid" =~ ^[0-9]+$ ]] && kill "$pid" 2>/dev/null || true
    fi
    clear_state
    play_sound "$END_SOUND"
    echo "Focus stopped"
  }

  show_status() {
    local mode=$1
    local remaining display
    if ! load_session || [ "$SESSION_END" -le "$(now)" ]; then
      [ "$mode" = tmux ] || echo "Focus: inactive"
      return
    fi

    remaining=$((SESSION_END - $(now)))
    display=$(format_remaining "$remaining")
    if [ "$mode" = tmux ]; then
      printf ' 󰔛 %s ' "$display"
    else
      echo "Focus: $display remaining"
    fi
  }

  self_test() {
    [ "$(format_remaining 65)" = "01:05" ]
    [ "$(format_remaining 3600)" = "60:00" ]
    valid_minutes 25
    ! valid_minutes 0
    ! valid_minutes 1441
    echo "focus self-test passed"
  }

  case "''${1:-status}" in
    start)
      [ "$#" -le 2 ] || { usage; exit 1; }
      start_session "''${2:-25}"
      ;;
    stop)
      [ "$#" -eq 1 ] || { usage; exit 1; }
      stop_session
      ;;
    sound)
      [ "$#" -eq 1 ] || { usage; exit 1; }
      sound_on
      ;;
    silent)
      [ "$#" -eq 1 ] || { usage; exit 1; }
      sound_off
      ;;
    status)
      [ "$#" -le 2 ] || { usage; exit 1; }
      case "''${2:-}" in
        "") show_status cli ;;
        --tmux) show_status tmux ;;
        *) usage; exit 1 ;;
      esac
      ;;
    _guard)
      [ "$#" -eq 4 ] || exit 1
      root_guard "$2" "$3" "$4"
      ;;
    _unblock)
      [ "$#" -eq 2 ] || exit 1
      [ "$EUID" -eq 0 ] || { echo "Error: unblock must run as root" >&2; exit 1; }
      hosts_off "$2"
      ;;
    _finish)
      [ "$#" -eq 3 ] || exit 1
      finish_session "$2" "$3"
      ;;
    _tick)
      [ "$#" -eq 3 ] || exit 1
      tick_session "$2" "$3"
      ;;
    _self-test)
      self_test
      ;;
    [0-9]*)
      [ "$#" -eq 1 ] || { usage; exit 1; }
      start_session "$1"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
''
