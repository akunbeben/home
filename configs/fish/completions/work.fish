function __tmux_work_projects
    set config_dir ~/Projects/dotfiles/tmux-sessions

    if test -d $config_dir
        for file in (ls $config_dir/*.conf 2>/dev/null)
            set name (basename $file .conf)

            if test $name != default
                echo $name
            end
        end
    end
end

complete -c work -f -a "edit (__tmux_work_projects)"
