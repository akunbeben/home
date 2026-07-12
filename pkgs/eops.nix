{ pkgs }:
pkgs.writeShellScriptBin "eops" ''
  set -euo pipefail

  eops_help() {
    echo "Usage: eops <command> [date]"
    echo ""
    echo "Commands:"
    echo "  go                       open a shell in repo everyday-ops"
    echo "  start [YYYY-MM-DD]       generate daily log + todo"
    echo "  todo [YYYY-MM-DD]        tampilkan todo harian"
    echo "  daily [YYYY-MM-DD]       tampilkan daily log"
    echo "  task \"<task text>\"        tambah task cepat (tanpa refine)"
    echo "  ai \"<catatan>\"             smart mode (refine via claude -p, lalu append)"
    echo "  ai --raw \"<task text>\"     bypass smart mode, append langsung"
    echo "  refine [YYYY-MM-DD]      refine keseluruhan todo hari itu"
    echo "  ctx                      tampilkan ringkas context inti"
    echo "  tmux                     refresh + tampilkan tmux runtime context"
    echo "  bootstrap                tampilkan bootstrap prompt model baru"
    echo "  status                   ringkas memory + auto activity hari ini"
    echo "  path                     tampilkan root path everyday-ops"
    echo "  help                     tampilkan bantuan"
  }

  root="''${EOPS_ROOT:-$HOME/Projects/everyday-ops}"
  cmd="''${1:-help}"
  date_arg="$(TZ=Asia/Jakarta date +%F)"

  refresh_tmux_context() {
    if [ -x "$root/scripts/refresh-tmux-context.sh" ]; then
      "$root/scripts/refresh-tmux-context.sh" >/dev/null
    fi
  }

  print_tmux_context() {
    if [ -f "$root/memory/tmux-context.md" ]; then
      sed -n '1,240p' "$root/memory/tmux-context.md"
    else
      echo "Tmux context belum ada: $root/memory/tmux-context.md"
    fi
  }

  if [ "$#" -ge 2 ]; then
    date_arg="$2"
  fi

  case "$cmd" in
    go)
      cd "$root"
      exec "''${SHELL:-${pkgs.bash}/bin/bash}"
      ;;
    start)
      cd "$root"
      ./scripts/start-day.sh "$date_arg"
      ./scripts/generate-todo.sh "$date_arg"
      refresh_tmux_context
      ;;
    todo)
      if [ -f "$root/daily/todo-$date_arg.md" ]; then
        sed -n '1,240p' "$root/daily/todo-$date_arg.md"
      else
        echo "Todo belum ada: $root/daily/todo-$date_arg.md"
      fi
      ;;
    daily)
      if [ -f "$root/daily/$date_arg.md" ]; then
        sed -n '1,260p' "$root/daily/$date_arg.md"
      else
        echo "Daily log belum ada: $root/daily/$date_arg.md"
      fi
      ;;
    task)
      if [ "$#" -lt 2 ]; then
        echo 'Usage: eops task "<task text>"'
        exit 1
      fi
      shift
      task_text="$*"
      cd "$root"
      bash ./scripts/add-task.sh "$task_text"
      ;;
    ai)
      if [ "$#" -lt 2 ]; then
        echo 'Usage: eops ai [--raw|--smart] "<catatan>"'
        exit 1
      fi

      shift
      smart_flag=1
      if [ "''${1:-}" = "--raw" ]; then
        smart_flag=0
        shift
      elif [ "''${1:-}" = "--smart" ]; then
        smart_flag=1
        shift
      fi

      if [ "$#" -lt 1 ]; then
        echo 'Usage: eops ai [--raw|--smart] "<catatan>"'
        exit 1
      fi

      task_text="$*"
      cd "$root"

      if [ "$smart_flag" -eq 1 ]; then
        bash ./scripts/add-task.sh --smart "$task_text"
      else
        bash ./scripts/add-task.sh "$task_text"
      fi
      ;;
    refine)
      cd "$root"
      bash ./scripts/refine-todo.sh "$date_arg"
      ;;
    ctx)
      refresh_tmux_context
      echo "--- user ---"
      sed -n '1,120p' "$root/memory/user.md"
      echo ""
      echo "--- okr ---"
      sed -n '1,140p' "$root/memory/okr.md"
      echo ""
      echo "--- handoff ---"
      sed -n '1,180p' "$root/memory/session-handoff.md"
      echo ""
      echo "--- tmux ---"
      print_tmux_context
      ;;
    tmux)
      refresh_tmux_context
      print_tmux_context
      ;;
    bootstrap)
      refresh_tmux_context
      sed -n '1,220p' "$root/prompts/model-bootstrap.md"
      echo ""
      echo "--- tmux runtime context ---"
      print_tmux_context
      ;;
    status)
      refresh_tmux_context
      today="$(TZ=Asia/Jakarta date +%F)"
      echo "EOPS_ROOT: $root"
      echo "Today    : $today"
      echo ""
      echo "Files:"
      for f in "$root"/memory/*; do
        [ -e "$f" ] || continue
        echo "  memory/$(basename "$f")"
      done
      echo ""
      echo "Today Todo:"
      if [ -f "$root/daily/todo-$today.md" ]; then
        sed -n '1,80p' "$root/daily/todo-$today.md"
      else
        echo "  (belum ada)"
      fi
      echo ""
      echo "Auto Activity (today):"
      if [ -f "$root/daily/$today.md" ]; then
        rg -n "Auto Activity|^-[[:space:]][0-9]{2}:[0-9]{2}" "$root/daily/$today.md"
      else
        echo "  (belum ada)"
      fi
      echo ""
      echo "Tmux Runtime Context:"
      if [ -f "$root/memory/tmux-context.md" ]; then
        sed -n '1,80p' "$root/memory/tmux-context.md"
      else
        echo "  (belum ada)"
      fi
      ;;
    path)
      echo "$root"
      ;;
    help|*)
      eops_help
      ;;
  esac
''
