{ pkgs }:
pkgs.writeShellScriptBin "work" ''
  WORKSPACES_DIR="$HOME/.config/workspaces"

  if [ "$1" = "edit" ]; then
    if [ "$2" = "." ]; then
      PROJECT_DIR=$(pwd)
      PROJECT_NAME=$(basename "$PROJECT_DIR")
    else
      PROJECT_NAME="$2"
    fi

    if [ -z "$PROJECT_NAME" ]; then
      echo "Usage: work edit <project-name> or work edit ."
      exit 1
    fi

    CONF_FILE="$WORKSPACES_DIR/${PROJECT_NAME}.conf"
    if [ ! -f "$CONF_FILE" ]; then
      mkdir -p "$WORKSPACES_DIR"
      cat >"$CONF_FILE" <<EOF
  WINDOW_4_NAME="monitor"
  WINDOW_4_PANES=()
  EOF
    fi
    ''${EDITOR:-nvim} "$CONF_FILE"
    exit 0
  fi

  if [ "$1" = "." ]; then
    PROJECT_DIR=$(pwd)
    PROJECT_NAME=$(basename "$PROJECT_DIR")
  else
    PROJECT_NAME="$1"
    PROJECT_DIR="$HOME/Projects/$PROJECT_NAME"
  fi

  if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: work <project-name> or work ."
    exit 1
  fi

  if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: Directory not found at $PROJECT_DIR"
    exit 1
  fi

  SESSION="$PROJECT_NAME"

  DEFAULT_CONF="$WORKSPACES_DIR/default.conf"
  PROJECT_CONF="$WORKSPACES_DIR/${PROJECT_NAME}.conf"

  source "$DEFAULT_CONF"

  if [ ! -f "$PROJECT_CONF" ]; then
    if [ -d "$PROJECT_DIR" ]; then
      mkdir -p "$WORKSPACES_DIR"
      cat >"$PROJECT_CONF" <<EOF
  WINDOW_4_NAME="monitor"
  WINDOW_4_PANES=()
  EOF
    fi
  fi

  source "$PROJECT_CONF"

  tmux has-session -t "$SESSION" 2>/dev/null
  if [ $? != 0 ]; then
    tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR"
    tmux send-keys -t "$SESSION:0" "$WINDOW_1_COMMAND" C-m

    tmux new-window -t "$SESSION" -c "$PROJECT_DIR"
    [ ! -z "$WINDOW_2_COMMAND" ] && tmux send-keys -t "$SESSION:1" "$WINDOW_2_COMMAND" C-m

    tmux new-window -t "$SESSION" -c "$PROJECT_DIR"
    [ ! -z "$WINDOW_3_COMMAND" ] && tmux send-keys -t "$SESSION:2" "$WINDOW_3_COMMAND" C-m

    tmux new-window -t "$SESSION" -c "$PROJECT_DIR"

    i=0
    for cmd in "''${WINDOW_4_PANES[@]}"; do
      if [ "$i" -eq 0 ]; then
        tmux select-pane -t "$SESSION:3.0"
        tmux send-keys "$cmd" C-m
      else
        tmux split-window -v -t "$SESSION:3" -c "$PROJECT_DIR"
        tmux select-pane -t "$SESSION:3.$i"
        tmux send-keys "$cmd" C-m
      fi
      i=$((i + 1))
    done

    tmux select-layout -t "$SESSION:3" tiled
    tmux select-window -t "$SESSION:0"
  fi

  tmux attach -t "$SESSION"
''
