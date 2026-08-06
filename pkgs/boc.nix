{ pkgs, bocRepos }:
let
  repoLines = builtins.concatStringsSep "\n  " (map (r: "\"$HOME/${r}\"") bocRepos);
in
pkgs.writeShellScriptBin "boc" ''
  BOC_REPOS=(
    ${repoLines}
  )
  BOC_EOPS_DIR="$HOME/Projects/everyday-ops"
  BOC_WORK_REPOS=("''${BOC_REPOS[@]}" "$HOME/Work/better-boc-provision" "$HOME/Work/nodegraf" "$HOME/Work/keloola-ai")

  TL='┌' TR='┐' BL='└' BR='┘'
  H='─' V='│'
  TM='┬' BM='┴' LM='├' RM='┤' CR='┼'

  _hline() { printf '%0.s'"$H" $(seq 1 "$1"); }
  _pad_right() { printf "%-''${1}s" "$2"; }
  _pad_center() {
    local width=$1 text=$2
    local len=''${#text}
    local total=$((width - len))
    local left=$((total / 2))
    local right=$((total - left))
    printf '%*s%s%*s' "$left" ''' "$text" "$right" '''
  }

  _top()    { printf '%s%s%s%s%s%s%s\n' "$TL" "$(_hline "$1")" "$TM" "$(_hline "$2")" "$TM" "$(_hline "$3")" "$TR"; }
  _mid()    { printf '%s%s%s%s%s%s%s\n' "$LM" "$(_hline "$1")" "$CR" "$(_hline "$2")" "$CR" "$(_hline "$3")" "$RM"; }
  _bot()    { printf '%s%s%s%s%s%s%s\n' "$BL" "$(_hline "$1")" "$BM" "$(_hline "$2")" "$BM" "$(_hline "$3")" "$BR"; }
  _row()    { printf '%s %s %s %s %s %s %s\n' "$V" "$(_pad_right "$(($1 - 2))" "$4")" "$V" "$(_pad_right "$(($2 - 2))" "$5")" "$V" "$(_pad_right "$(($3 - 2))" "$6")" "$V"; }
  _header() { printf '%s %s %s %s %s %s %s\n' "$V" "$(_pad_center "$(($1 - 2))" "Repo")" "$V" "$(_pad_center "$(($2 - 2))" "Branch")" "$V" "$(_pad_center "$(($3 - 2))" "Last Commit")" "$V"; }

  _tmux_go() {
    if [ -n "$TMUX" ]; then
      tmux switch-client -t "$1"
    else
      tmux attach -t "$1"
    fi
  }

  _current_size() {
    local rows cols

    if [ -n "$TMUX" ]; then
      cols=$(tmux display-message -p '#{client_width}' 2>/dev/null)
      rows=$(tmux display-message -p '#{client_height}' 2>/dev/null)
    elif read -r rows cols < <(stty size 2>/dev/null); then
      :
    else
      rows="''${LINES:-}"
      cols="''${COLUMNS:-}"
    fi

    [ -n "$cols" ] && [ -n "$rows" ] && printf '%s %s\n' "$cols" "$rows"
  }

  _window_dir() {
    local target="$1"
    local name repo

    name=$(tmux display-message -p -t "$target" '#{window_name}' 2>/dev/null)
    if [ "$name" = "workspace" ]; then
      printf '%s\n' "$BOC_EOPS_DIR"
      return
    fi

    for repo in "''${BOC_WORK_REPOS[@]}"; do
      if [ "$(basename "$repo")" = "$name" ]; then
        printf '%s\n' "$repo"
        return
      fi
    done
  }

  _is_shell() {
    case "$1" in
      sh|bash|zsh|fish) return 0 ;;
      *) return 1 ;;
    esac
  }

  _shell_quote() {
    local shell="$1"
    local value="$2"

    if [ "$shell" = fish ]; then
      fish -c 'string escape -- "$argv[1]"' -- "$value"
      return
    fi

    value=''${value//\'/\'\\\'\'}
    printf "'%s'" "$value"
  }

  _sync_bottom_pane_cwd() {
    local target="$1"
    local target_dir="$2"
    local pane cmd path

    [ -n "$target_dir" ] || return

    pane=$(tmux list-panes -t "$target" -f '#{==:#{pane_index},1}' -F '#{pane_id}' 2>/dev/null)
    [ -n "$pane" ] || return

    cmd=$(tmux display-message -p -t "$pane" '#{pane_current_command}' 2>/dev/null)
    path=$(tmux display-message -p -t "$pane" '#{pane_current_path}' 2>/dev/null)

    _is_shell "$cmd" || return
    [ "$path" = "$target_dir" ] && return

    local quoted_dir
    quoted_dir=$(_shell_quote "$cmd" "$target_dir")
    tmux send-keys -t "$pane" C-c "cd -- $quoted_dir" Enter
  }

  _ensure_window_layout() {
    local target="$1"
    local active_pane target_dir window_name
    local -a panes

    window_name=$(tmux display-message -p -t "$target" '#{window_name}' 2>/dev/null)
    [ "$window_name" = "workspace" ] && return

    mapfile -t panes < <(tmux list-panes -t "$target" -F '#{pane_id}' 2>/dev/null)
    [ "''${#panes[@]}" -eq 0 ] && return

    active_pane=$(tmux list-panes -t "$target" -f '#{pane_active}' -F '#{pane_id}' 2>/dev/null)
    target_dir=$(_window_dir "$target")

    if [ -z "$target_dir" ]; then
      target_dir=$(tmux list-panes -t "$target" -f '#{pane_active}' -F '#{pane_current_path}' 2>/dev/null)
    fi

    if [ "''${#panes[@]}" -eq 1 ]; then
      tmux split-window -d -v -t "$active_pane" -c "$target_dir"
      mapfile -t panes < <(tmux list-panes -t "$target" -F '#{pane_id}' 2>/dev/null)
    fi

    # ponytail: don't collapse existing >2-pane windows because that would kill running work.
    if [ "''${#panes[@]}" -eq 2 ]; then
      tmux set-window-option -t "$target" main-pane-height 80%
      tmux select-layout -t "$active_pane" main-horizontal >/dev/null
      _sync_bottom_pane_cwd "$target" "$target_dir"
    fi
  }

  _ensure_session_layout() {
    local session="$1"
    local window

    while IFS= read -r window; do
      _ensure_window_layout "$window"
    done < <(tmux list-windows -t "$session" -F '#{window_id}')
  }

  _refresh_tmux_context() {
    if [ -x "$BOC_EOPS_DIR/scripts/refresh-tmux-context.sh" ]; then
      "$BOC_EOPS_DIR/scripts/refresh-tmux-context.sh" >/dev/null 2>&1 || true
    fi
  }

  _ensure_repo_windows() {
    local session="$1"
    local repo name

    for repo in "''${BOC_WORK_REPOS[@]}"; do
      name=$(basename "$repo")
      if tmux list-windows -t "$session" -F '#{window_name}' 2>/dev/null | grep -Fxq "$name"; then
        continue
      fi

      tmux new-window -d -t "$session:" -c "$repo" -n "$name"
    done
  }

  _set_layout_hooks() {
    local session="$1"
    local hook='run-shell "boc __layout-window #{window_id}"'

    tmux set-hook -t "$session" client-attached "$hook"
    tmux set-hook -t "$session" client-session-changed "$hook"
    tmux set-hook -t "$session" client-resized "$hook"
    tmux set-hook -t "$session" after-select-window "$hook"
  }

  cmd_layout_window() {
    [ -n "''${1:-}" ] || return
    _ensure_window_layout "$1"
  }

  cmd_work() {
    local session="boc"
    local size cols rows

    if tmux has-session -t "$session" 2>/dev/null; then
      size=$(_current_size)
      if [ -n "$size" ]; then
        read -r cols rows <<<"$size"
        tmux set-option -t "$session" default-size "$cols''${rows:+x$rows}" >/dev/null
      fi

      _set_layout_hooks "$session"
      _ensure_repo_windows "$session"
      _ensure_session_layout "$session"
      _refresh_tmux_context
      _tmux_go "$session"
      return
    fi

    local prev_name name

    size=$(_current_size)
    if [ -n "$size" ]; then
      read -r cols rows <<<"$size"
      tmux new-session -d -s "$session" -x "$cols" -y "$rows" -n "workspace" \
        "fish -C 'cd \"$BOC_EOPS_DIR\"; opencode'"
      tmux set-option -t "$session" default-size "$cols''${rows:+x$rows}" >/dev/null
    else
      tmux new-session -d -s "$session" -n "workspace" \
        "fish -C 'cd \"$BOC_EOPS_DIR\"; opencode'"
    fi

    _set_layout_hooks "$session"
    prev_name="workspace"

    for repo in "''${BOC_WORK_REPOS[@]}"; do
      name=$(basename "$repo")
      tmux new-window -a -t "$session:$prev_name" -c "$repo" -n "$name"
      prev_name="$name"
    done

    _ensure_session_layout "$session"
    tmux select-window -t "$session:workspace"
    _refresh_tmux_context
    _tmux_go "$session"
  }

  cmd_gst() {
    local -a names branches commits

    for repo in "''${BOC_REPOS[@]}"; do
      names+=("$(basename "$repo")")
      branches+=("$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')")
      commits+=("$(git -C "$repo" log --oneline -1 2>/dev/null || echo '?')")
    done

    local w1=6 w2=8 w3=13
    for i in "''${!names[@]}"; do
      ((''${#names[$i]} + 2 > w1)) && w1=$((''${#names[$i]} + 2))
      ((''${#branches[$i]} + 2 > w2)) && w2=$((''${#branches[$i]} + 2))
      ((''${#commits[$i]} + 2 > w3)) && w3=$((''${#commits[$i]} + 2))
    done

    _top "$w1" "$w2" "$w3"
    _header "$w1" "$w2" "$w3"
    _mid "$w1" "$w2" "$w3"
    for i in "''${!names[@]}"; do
      _row "$w1" "$w2" "$w3" "''${names[$i]}" "''${branches[$i]}" "''${commits[$i]}"
      ((i < ''${#names[@]} - 1)) && _mid "$w1" "$w2" "$w3"
    done
    _bot "$w1" "$w2" "$w3"
  }

  case "''${1:-}" in
    __layout-window) cmd_layout_window "''${2:-}" ;;
    gst)  cmd_gst ;;
    work) cmd_work ;;
    *)
      echo "Usage: boc <command>"
      echo ""
      echo "Commands:"
      echo "  gst     Show git status table for all BOC repos"
      echo "  work    Open tmux session with all repos + eops (opencode)"
      ;;
  esac
''
