{ pkgs, bocRepos }:
let
  repoLines = builtins.concatStringsSep "\n  " (map (r: "\"$HOME/${r}\"") bocRepos);
in
pkgs.writeShellScriptBin "boc" ''
  BOC_REPOS=(
    ${repoLines}
  )

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

  cmd_work() {
    local session="boc"
    local eops_dir="$HOME/Projects/everyday-ops"

    if tmux has-session -t "$session" 2>/dev/null; then
      _tmux_go "$session"
      return
    fi

    local prev_name name

    tmux new-session -d -s "$session" -n "eops" \
      "fish -C 'cd \"$eops_dir\"; claude'"
    prev_name="eops"

    for repo in "''${BOC_REPOS[@]}"; do
      name=$(basename "$repo")
      tmux new-window -a -t "$session:$prev_name" -c "$repo" -n "$name"
      tmux send-keys -t "$session:$name" "nvim ." Enter
      prev_name="$name"
    done

    tmux select-window -t "$session:eops"
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
    gst)  cmd_gst ;;
    work) cmd_work ;;
    *)
      echo "Usage: boc <command>"
      echo ""
      echo "Commands:"
      echo "  gst     Show git status table for all BOC repos"
      echo "  work    Open tmux session with all repos (nvim) + eops (claude)"
      ;;
  esac
''
