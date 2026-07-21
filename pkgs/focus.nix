{ pkgs }:
let
  focusRoot = pkgs.writeShellScriptBin "focus-root" ''
    set -euo pipefail

    now() {
      /bin/date +%s
    }

    valid_token() {
      [[ "$1" =~ ^[0-9]+-[0-9]+-[0-9]+$ ]]
    }

    current_hosts_token() {
      /usr/bin/awk '/^# focus:block:start / { token = $3 } END { print token }' /etc/hosts
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
      local domain count=0 owner size
      local -a domains=()

      valid_token "$token" || { echo "Error: invalid focus token" >&2; return 1; }
      [ -f "$sites" ] || { echo "Error: sites file not found" >&2; return 1; }
      owner=$(/usr/bin/stat -f %u "$sites")
      [ "$owner" = "''${SUDO_UID:-}" ] || { echo "Error: sites file has invalid owner" >&2; return 1; }
      size=$(/usr/bin/stat -f %z "$sites")
      ((size <= 65536)) || { echo "Error: sites file exceeds 64 KiB" >&2; return 1; }

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

    guard() {
      local token=$1
      local end=$2
      local sites=$3
      local current remaining
      valid_token "$token" || { echo "Error: invalid focus token" >&2; exit 1; }
      [[ "$end" =~ ^[0-9]{1,12}$ ]] || { echo "Error: invalid end time" >&2; exit 1; }
      current=$(now)
      remaining=$((end - current))
      ((remaining >= 1 && remaining <= 86400)) || {
        echo "Error: focus deadline must be within 24 hours" >&2
        exit 1
      }

      trap "hosts_off '$token' || true" EXIT
      trap 'exit 0' HUP INT TERM
      hosts_on "$token" "$sites"
      while [ "$(now)" -lt "$end" ]; do
        /bin/sleep 1
      done
    }

    [ "$EUID" -eq 0 ] || { echo "Error: focus-root must run as root" >&2; exit 1; }
    case "''${1:-}" in
      guard)
        [ "$#" -eq 4 ] || exit 1
        guard "$2" "$3" "$4"
        ;;
      unblock)
        [ "$#" -eq 2 ] || exit 1
        hosts_off "$2"
        ;;
      *)
        exit 1
        ;;
    esac
  '';
  tickSound = pkgs.runCommand "focus-tick.wav" {} ''
    ${pkgs.ffmpeg}/bin/ffmpeg -nostdin -loglevel error -i ${../tick.mp3} \
      -af "atrim=start=0.2073:end=8.8322,asetpts=PTS-STARTPTS" \
      -map_metadata -1 -c:a pcm_s16le "$out"
  '';
  tickPlayerSource = pkgs.writeText "focus-tick-player.m" ''
    #import <AVFoundation/AVFoundation.h>

    int main(int argc, const char *argv[]) {
      @autoreleasepool {
        if (argc != 2) return 2;

        NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
        NSError *error = nil;
        AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
        if (player == nil) {
          fprintf(stderr, "focus: %s\n", error.localizedDescription.UTF8String);
          return 1;
        }

        player.numberOfLoops = -1;
        if (![player prepareToPlay] || ![player play]) return 1;
        while (player.isPlaying) {
          [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
        }
      }
      return 0;
    }
  '';
  tickPlayer = pkgs.stdenv.mkDerivation {
    pname = "focus-tick-player";
    version = "1";
    dontUnpack = true;
    buildPhase = ''
      $CC -fobjc-arc -framework Foundation -framework AVFoundation \
        ${tickPlayerSource} -o focus-tick-player
    '';
    installPhase = ''
      mkdir -p "$out/bin"
      cp focus-tick-player "$out/bin/"
    '';
  };
  focus = pkgs.writeShellScriptBin "focus" ''
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
  TICK_SOUND="${tickSound}"
  TICK_PLAYER="${tickPlayer}/bin/focus-tick-player"
  TMUX_BIN="${pkgs.tmux}/bin/tmux"
  ROOT_HELPER="${focusRoot}/bin/focus-root"

  usage() {
    echo "Usage: focus [start [minutes]|stop|status|sound|silent|break [minutes]]" >&2
  }

  now() {
    /bin/date +%s
  }

  now_us() {
    printf '%s\n' "''${EPOCHREALTIME/./}"
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

  refresh_tmux_status() {
    "$TMUX_BIN" refresh-client -S >/dev/null 2>&1 || true
  }

  current_hosts_token() {
    /usr/bin/awk '/^# focus:block:start / { token = $3 } END { print token }' /etc/hosts
  }

  write_sites() {
    /bin/mkdir -p "$STATE_DIR"
    [ -f "$CONFIG_DIR/sites" ] || {
      echo "Error: blocklist not found at $CONFIG_DIR/sites" >&2
      exit 1
    }
    # ponytail: hosts files need explicit domains; use a Network Extension for wildcard blocking.
    /bin/cp "$CONFIG_DIR/sites" "$SITES_FILE"
  }

  finish_session() {
    local token=$1
    local end=$2
    local minutes=$3
    while [ "$(now)" -lt "$end" ]; do
      refresh_tmux_status
      /bin/sleep 1
    done

    load_session || exit 0
    [ "$SESSION_TOKEN" = "$token" ] || exit 0
    clear_state
    refresh_tmux_status
    play_sound "$END_SOUND"
    show_break 5 "$minutes" || true
  }

  tick_session() {
    local token=$1
    local end=$2
    local audio_pid
    load_session || return
    [ "$SESSION_TOKEN" = "$token" ] || return
    [ "$(now)" -lt "$end" ] || return

    "$TICK_PLAYER" "$TICK_SOUND" >/dev/null 2>&1 &
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
    /bin/rm -f "$TICK_FILE"
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

  center_line() {
    local row=$1
    local cols=$2
    local color=$3
    local text=$4
    local col
    col=$(((cols - ''${#text}) / 2 + 1))
    ((col < 1)) && col=1
    printf '\033[%d;%dH\033[38;2;%sm\033[48;2;26;27;38m%s' "$row" "$col" "$color" "$text"
  }

  render_break_timer() {
    local remaining=$1
    local rows=$2
    local cols=$3
    local middle timer
    middle=$((rows / 2))
    ((middle < 4)) && middle=4
    timer=$(format_remaining "$remaining")

    printf '\033[48;2;26;27;38m\033[%d;1H\033[2K' "$middle"
    center_line "$middle" "$cols" "125;207;255" "$timer"
  }

  render_break_action() {
    local rows=$1
    local cols=$2
    local resume_minutes=$3
    local armed=$4
    local text color="86;95;137"

    if ((resume_minutes > 0)); then
      if ((armed)); then
        text="press enter again  ·  focus $resume_minutes minutes"
        color="224;175;104"
      else
        text="enter  continue $resume_minutes min  ·  esc / q  close"
      fi
    else
      text="enter / esc / q"
    fi
    printf '\033[48;2;26;27;38m\033[%d;1H\033[2K' "$((rows - 2))"
    center_line "$((rows - 2))" "$cols" "$color" "$text"
  }

  render_break_screen() {
    local remaining=$1
    local rows=$2
    local cols=$3
    local resume_minutes=$4
    local armed=$5
    local middle
    middle=$((rows / 2))
    ((middle < 4)) && middle=4

    printf '\033[48;2;26;27;38m\033[2J\033[H'
    center_line "$((middle - 3))" "$cols" "86;95;137" "·  BREAK  ·"
    center_line "$((middle + 3))" "$cols" "192;202;245" "breathe  ·  move  ·  look away"
    if ((rows >= 10)); then
      render_break_action "$rows" "$cols" "$resume_minutes" "$armed"
    fi
    render_break_timer "$remaining" "$rows" "$cols"
  }

  activate_terminal() {
    /usr/bin/osascript -e 'tell application "kitty" to activate' >/dev/null 2>&1 \
      || /usr/bin/open -a kitty
  }

  resume_focus() {
    local minutes=$1
    activate_terminal
    printf '\033[0m\033[2J\033[H\033[?25h'
    "$0" start "$minutes"
  }

  break_screen() {
    local minutes=$1
    local resume_minutes=$2
    local end remaining key rows cols last_rows=0 last_cols=0
    local armed=0 confirm_started=0 last_enter=0 current_us since_last
    local terminal_focused=0
    valid_minutes "$minutes" || exit 1
    if [ "$resume_minutes" != 0 ]; then
      valid_minutes "$resume_minutes" || exit 1
    fi
    minutes=$((10#$minutes))
    end=$(($(now) + minutes * 60))

    trap 'printf "\033[0m\033[?25h"' EXIT
    trap 'exit 0' HUP INT TERM
    printf '\033[?25l'
    while true; do
      remaining=$((end - $(now)))
      if ((remaining <= 0)); then
        render_break_timer 0 "$last_rows" "$last_cols"
        if ((resume_minutes > 0)); then
          resume_focus "$resume_minutes"
        else
          /bin/sleep 1
        fi
        return
      fi
      if ((resume_minutes > 0 && remaining <= 5 && terminal_focused == 0)); then
        activate_terminal
        terminal_focused=1
      fi
      read -r rows cols < <(/bin/stty size)
      ((rows > 0)) || rows=24
      ((cols > 0)) || cols=80
      current_us=$(now_us)
      if ((armed && current_us - confirm_started > 5000000)); then
        armed=0
        render_break_action "$rows" "$cols" "$resume_minutes" "$armed"
      fi
      if [ "$rows" -ne "$last_rows" ] || [ "$cols" -ne "$last_cols" ]; then
        render_break_screen "$remaining" "$rows" "$cols" "$resume_minutes" "$armed"
        last_rows=$rows
        last_cols=$cols
      else
        render_break_timer "$remaining" "$rows" "$cols"
      fi
      key=""
      if IFS= read -rsn1 -t 1 key; then
        case "$key" in
          q|Q|$'\e') return ;;
          "")
            if ((resume_minutes == 0)); then
              return
            fi
            current_us=$(now_us)
            if ((armed == 0)); then
              armed=1
              confirm_started=$current_us
              last_enter=$current_us
              render_break_action "$rows" "$cols" "$resume_minutes" "$armed"
            else
              since_last=$((current_us - last_enter))
              last_enter=$current_us
              if ((since_last >= 700000)); then
                resume_focus "$resume_minutes"
                return
              fi
            fi
            ;;
        esac
      fi
    done
  }

  show_break() {
    local minutes=$1
    local resume_minutes=''${2:-0}
    local activity client target_client="" latest_activity=0
    valid_minutes "$minutes" || {
      echo "Error: minutes must be between 1 and 1440" >&2
      return 1
    }
    if [ "$resume_minutes" != 0 ] && ! valid_minutes "$resume_minutes"; then
      echo "Error: resume minutes must be between 1 and 1440" >&2
      return 1
    fi

    while read -r activity client; do
      [[ "$activity" =~ ^[0-9]+$ ]] || continue
      if [ "$activity" -ge "$latest_activity" ]; then
        latest_activity=$activity
        target_client=$client
      fi
    done < <("$TMUX_BIN" list-clients -F '#{client_activity} #{client_name}' 2>/dev/null || true)

    if [ -z "$target_client" ]; then
      echo "Error: no active tmux client" >&2
      return 1
    fi
    activate_terminal
    "$TMUX_BIN" display-popup -B -E -c "$target_client" -w 100% -h 100% \
      -s "bg=#1a1b26" "$0" _break-screen "$minutes" "$resume_minutes"
    echo "Break screen started for $minutes minutes"
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
      /usr/bin/sudo -n "$ROOT_HELPER" unblock "$token" >/dev/null 2>&1 || true
      clear_state
    }
    trap cleanup_start EXIT
    trap 'exit 130' HUP INT TERM

    /usr/bin/nohup /usr/bin/sudo -n "$ROOT_HELPER" guard "$token" "$end" "$SITES_FILE" \
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
    /usr/bin/nohup "$0" _finish "$token" "$end" "$minutes" > "$WORKER_LOG" 2>&1 &
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
      /usr/bin/sudo -n "$ROOT_HELPER" unblock "$token"
    fi

    if [ -r "$PID_FILE" ]; then
      read -r pid < "$PID_FILE"
      [[ "$pid" =~ ^[0-9]+$ ]] && kill "$pid" 2>/dev/null || true
    fi
    clear_state
    refresh_tmux_status
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
    break)
      [ "$#" -le 2 ] || { usage; exit 1; }
      show_break "''${2:-5}"
      ;;
    status)
      [ "$#" -le 2 ] || { usage; exit 1; }
      case "''${2:-}" in
        "") show_status cli ;;
        --tmux) show_status tmux ;;
        *) usage; exit 1 ;;
      esac
      ;;
    _finish)
      [ "$#" -eq 4 ] || exit 1
      finish_session "$2" "$3" "$4"
      ;;
    _tick)
      [ "$#" -eq 3 ] || exit 1
      tick_session "$2" "$3"
      ;;
    _break-screen)
      [ "$#" -eq 3 ] || exit 1
      break_screen "$2" "$3"
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
  '';
in {
  package = focus;
  root = focusRoot;
}
