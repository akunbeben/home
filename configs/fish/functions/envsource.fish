function envsource
    if test (count $argv) -ne 1
        echo "Usage: envsource <file>" >&2
        return 1
    end

    set -f envfile "$argv[1]"
    if not test -f "$envfile"
        echo "Unable to load $envfile"
        return 1
    end

    while read -l line
        if string match -qr '^\s*(#|$)' -- "$line"
            continue
        end

        set -l item (string split -m 1 '=' -- "$line")
        if test (count $item) -ne 2
            echo "Invalid dotenv line in $envfile" >&2
            return 1
        end

        set -l name "$item[1]"
        if not string match -qr '^[A-Za-z_][A-Za-z0-9_]*$' -- "$name"
            echo "Invalid environment variable name in $envfile" >&2
            return 1
        end

        set -gx "$name" "$item[2]"
    end <"$envfile"
end
