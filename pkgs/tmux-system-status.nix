{ pkgs }:
pkgs.writeShellScriptBin "tmux-system-status" ''
  set -euo pipefail
  export LC_ALL=C

  case "''${1:-}" in
    cpu)
      /usr/bin/top -l 1 -n 0 | /usr/bin/awk '
        /^CPU usage:/ {
          gsub(/%/, "", $7)
          printf "%.0f%%\n", 100 - $7
          exit
        }
      '
      ;;
    memory)
      /usr/bin/memory_pressure -Q | /usr/bin/awk '
        /free percentage:/ {
          gsub(/%/, "", $5)
          printf "%d%%\n", 100 - $5
          exit
        }
      '
      ;;
    *)
      echo "Usage: tmux-system-status <cpu|memory>" >&2
      exit 2
      ;;
  esac
''
