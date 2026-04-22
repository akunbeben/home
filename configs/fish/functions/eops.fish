function __eops_help
    echo "Usage: eops <command> [date]"
    echo ""
    echo "Commands:"
    echo "  go                       cd ke repo everyday-ops"
    echo "  start [YYYY-MM-DD]       generate daily log + todo"
    echo "  todo [YYYY-MM-DD]        tampilkan todo harian"
    echo "  daily [YYYY-MM-DD]       tampilkan daily log"
    echo "  task \"<task text>\"        tambah task cepat (tanpa refine)"
    echo "  ai \"<catatan>\"             smart mode (refine via claude -p, lalu append)"
    echo "  ai --raw \"<task text>\"     bypass smart mode, append langsung"
    echo "  refine [YYYY-MM-DD]      refine keseluruhan todo hari itu"
    echo "  ctx                      tampilkan ringkas context inti"
    echo "  bootstrap                tampilkan bootstrap prompt model baru"
    echo "  status                   ringkas memory + auto activity hari ini"
    echo "  path                     tampilkan root path everyday-ops"
    echo "  help                     tampilkan bantuan"
end

function eops --description "everyday-ops global helper"
    set -l root "/Users/benny/Projects/everyday-ops"
    if set -q EOPS_ROOT
        set root "$EOPS_ROOT"
    end

    set -l cmd "help"
    if test (count $argv) -ge 1
        set cmd "$argv[1]"
    end

    set -l date_arg (TZ=Asia/Jakarta date +%F)
    if test (count $argv) -ge 2
        set date_arg "$argv[2]"
    end

    switch "$cmd"
        case go
            cd "$root"
        case start
            cd "$root"; and ./scripts/start-day.sh "$date_arg"; and ./scripts/generate-todo.sh "$date_arg"
        case todo
            if test -f "$root/daily/todo-$date_arg.md"
                sed -n '1,240p' "$root/daily/todo-$date_arg.md"
            else
                echo "Todo belum ada: $root/daily/todo-$date_arg.md"
            end
        case daily
            if test -f "$root/daily/$date_arg.md"
                sed -n '1,260p' "$root/daily/$date_arg.md"
            else
                echo "Daily log belum ada: $root/daily/$date_arg.md"
            end
        case task
            if test (count $argv) -lt 2
                echo 'Usage: eops task "<task text>"'
                return 1
            end
            set -e argv[1]
            set -l task_text (string join " " $argv)
            cd "$root"; or return 1
            bash ./scripts/add-task.sh "$task_text"
        case ai
            if test (count $argv) -lt 2
                echo 'Usage: eops ai [--raw|--smart] "<catatan>"'
                return 1
            end

            set -e argv[1]
            set -l smart_flag 1
            if test (count $argv) -ge 1; and test "$argv[1]" = "--raw"
                set smart_flag 0
                set -e argv[1]
            else if test (count $argv) -ge 1; and test "$argv[1]" = "--smart"
                set smart_flag 1
                set -e argv[1]
            end

            if test (count $argv) -lt 1
                echo 'Usage: eops ai [--raw|--smart] "<catatan>"'
                return 1
            end

            set -l task_text (string join " " $argv)
            cd "$root"; or return 1

            if test $smart_flag -eq 1
                bash ./scripts/add-task.sh --smart "$task_text"
            else
                bash ./scripts/add-task.sh "$task_text"
            end
        case refine
            cd "$root"; or return 1
            bash ./scripts/refine-todo.sh "$date_arg"
        case ctx
            echo "--- user ---"
            sed -n '1,120p' "$root/memory/user.md"
            echo ""
            echo "--- okr ---"
            sed -n '1,140p' "$root/memory/okr.md"
            echo ""
            echo "--- handoff ---"
            sed -n '1,180p' "$root/memory/session-handoff.md"
        case bootstrap
            sed -n '1,220p' "$root/prompts/model-bootstrap.md"
        case status
            set -l today (TZ=Asia/Jakarta date +%F)
            echo "EOPS_ROOT: $root"
            echo "Today    : $today"
            echo ""
            echo "Files:"
            for f in (ls -1 "$root/memory")
                echo "  memory/$f"
            end
            echo ""
            echo "Today Todo:"
            if test -f "$root/daily/todo-$today.md"
                sed -n '1,80p' "$root/daily/todo-$today.md"
            else
                echo "  (belum ada)"
            end
            echo ""
            echo "Auto Activity (today):"
            if test -f "$root/daily/$today.md"
                rg -n "Auto Activity|^-[[:space:]][0-9]{2}:[0-9]{2}" "$root/daily/$today.md"
            else
                echo "  (belum ada)"
            end
        case path
            echo "$root"
        case help '*'
            __eops_help
    end
end
