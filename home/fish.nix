{ config, ... }: {
  programs.fish = {
    enable = true;

    shellAliases = {
      q        = "exit";
      c        = "clear";
      l        = "eza --long --icons --group-directories-first";
      v        = "nvim .";
      t        = "tmux a";
      f        = "yazi";
      o        = "open";
      vim      = "nvim";
      vimconf  = "nvim ~/.config/nvim";
      install  = "brew install";
      i        = "brew install";
      uninstall = "brew uninstall";
      ls       = "eza --long --icons --group-directories-first";
      ll       = "eza --long --icons --group-directories-first --all";
      ai       = "codex";
      gg       = "goto-ssh";
      dot      = "nvim ~/Projects/home";
      nx       = "sudo SSH_AUTH_SOCK=\"$SSH_AUTH_SOCK\" GIT_SSH_COMMAND=\"ssh -F $HOME/.ssh/config\" darwin-rebuild switch --flake ~/Projects/home#Macbook";
      start    = "sudo systemctl start";
      stop     = "sudo systemctl stop";
      restart  = "sudo systemctl restart";
      mysqldump = "/usr/bin/mariadb-dump";
      php      = "valet php";
      composer = "valet composer";
      claudex  = "CLAUDE_CODE_SUBAGENT_MODEL=gpt-5.6-sol CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=1 CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY=3 ENABLE_TOOL_SEARCH=false claude --model gpt-5.6-sol";
    };

    shellAbbrs = {
      # Laravel / PHP
      a          = "php artisan";
      va         = "valet php artisan";
      migrate    = "php artisan migrate";
      rollback   = "php artisan migrate:rollback";
      model      = "php artisan make:model";
      controller = "php artisan make:controller";
      request    = "php artisan make:request";
      event      = "php artisan make:event";
      listener   = "php artisan make:listener";
      job        = "php artisan make:job";
      seeder     = "php artisan make:seeder";
      tinker     = "php artisan tinker";
      rl         = "php artisan route:list";
      lint       = "composer lint";

      # Misc
      delete = "rm -rfv";
      r      = "exec fish";
      n      = "n8n-node";
      shadcn = "bunx --bun shadcn@latest add";

      # Git
      lg  = "lazygit";
      ld  = "lazydocker";
      lq  = "lazysql";
      g   = "git";
      ga  = "git add";
      gaa = "git add .";
      gb  = "git branch";
      gc  = "git commit -m";
      gco = "git checkout";
      gcb = "git checkout -b";
      gd  = "git diff";
      gl  = "git pull";
      glog = "git log --oneline --graph --decorate";
      gp  = "git push";
      gpo = "git push origin";
      gpf = "git push --force";
      gst = "git status";
      gr  = "git remote -v";
      grm = "git rm";
      gcl = "git clone";
      gpl = "git pull origin";
      gps = "git push origin";
      gsw = "git switch";
      gss = "git stash save";
      gsp = "git stash pop";
      gsta = "git stash";
      gstl = "git stash list";
      gsts = "git stash show -p";

      # Navigation
      cdd  = "cd -";
      home = "cd ~/Projects/home";
      root = "cd /";
      docs = "cd ~/Documents";
      dl   = "cd ~/Downloads";
      desk = "cd ~/Desktop";
      proj = "cd ~/Projects";
      src  = "cd ~/src";
      "..1" = "cd ..";
      "..2" = "cd ../..";
      "..3" = "cd ../../..";
      "..4" = "cd ../../../..";
      "..5" = "cd ../../../../..";
    };

    interactiveShellInit = ''
      fish_add_path /opt/homebrew/bin
      fish_add_path $HOME/.config/composer/vendor/bin
      fish_add_path $HOME/Projects/scripting
      fish_add_path $HOME/.opencode/bin
      fish_add_path $HOME/Projects/home/bin
      fish_add_path $HOME/.local/bin
      fish_add_path $HOME/.lmstudio/bin
      fish_add_path $HOME/.antigravity/antigravity/bin
      fish_add_path $HOME/Library/Android/sdk/platform-tools
      fish_add_path $HOME/Library/Android/sdk/commandline-tools/bin
      fish_add_path $HOME/Android-Development/flutter/bin
      fish_add_path /opt/homebrew/opt/openjdk@21/bin
      fish_add_path $HOME/.cargo/bin

      set --export BUN_INSTALL "$HOME/.bun"
      fish_add_path $BUN_INSTALL/bin

      set -gx PNPM_HOME $HOME/Library/pnpm
      fish_add_path $PNPM_HOME

      set -gx JAVA_HOME /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home

      set fish_greeting
      set -gx EDITOR nvim

      test -f "$HOME/.env"; and envsource "$HOME/.env"

      fnm env --use-on-cd --shell fish | source

      terminal-theme-sync 2>/dev/null
    '';

    functions = {
      tk = {
        body = ''
          if test (count $argv) -gt 1
              echo "Usage: tk [session]" >&2
              return 1
          end

          set -l target "$argv[1]"
          if test -z "$target"
              if not set -q TMUX
                  echo "Usage: tk [session]" >&2
                  return 1
              end

              set target (tmux display-message -p '#{session_name}')
          end

          if not tmux has-session -t "$target" 2>/dev/null
              echo "No such tmux session: $target" >&2
              return 1
          end

          set -l session (tmux display-message -p -t "$target" '#{session_name}')
          set -l socket_path (tmux display-message -p -t "$target" '#{socket_path}')
          tmux run-shell -b "bash $HOME/Projects/home/scripts/tmux-kill-session.sh $session $socket_path"
        '';
      };
      terminal-theme-sync = {
        body = ''
          set -l mode (defaults read -g AppleInterfaceStyle 2>/dev/null)
          if test "$mode" = Dark
              set theme ~/.config/kitty/themes/opencode-dark.conf
              set bg '#0a0a0a'
              set fg '#eeeeee'
              set muted '#808080'
              set green '#7fd88f'
              set blue '#fab283'
              set cyan '#56b6c2'
              set magenta '#9d7cd8'
              set yellow '#f5a742'
              set command '#fab283'
              set keyword '#9d7cd8'
              set info '#56b6c2'
              set error '#e06c75'
              set selection '#1d1d25'
          else
              set theme ~/.config/kitty/themes/opencode-light.conf
              set bg '#ffffff'
              set fg '#1a1a1a'
              set muted '#8a8a8a'
              set green '#3d9a57'
              set blue '#3b7dd8'
              set cyan '#318795'
              set magenta '#d68c27'
              set yellow '#b0851f'
              set command '#3b7dd8'
              set keyword '#d68c27'
              set info '#318795'
              set error '#d1383d'
              set selection '#dfeaf7'
          end

          cp $theme ~/.config/kitty/current-theme.conf

          for sock in /tmp/kitty-*
              test -S $sock; and /Applications/kitty.app/Contents/MacOS/kitty @ --to unix:$sock \
                  set-colors --all $theme 2>/dev/null
          end

          set -g fish_color_normal $fg
          set -g fish_color_command $command
          set -g fish_color_keyword $keyword
          set -g fish_color_quote $green
          set -g fish_color_redirection $info
          set -g fish_color_end $info
          set -g fish_color_error $error
          set -g fish_color_param $fg
          set -g fish_color_comment $muted
          set -g fish_color_operator $info
          set -g fish_color_escape $yellow
          set -g fish_color_autosuggestion $muted
          set -g fish_color_cwd $green
          set -g fish_color_cwd_root $error
          set -g fish_color_selection --background=$selection
          set -g fish_color_search_match --background=$selection
          set -g fish_pager_color_prefix $keyword
          set -g fish_pager_color_completion $fg
          set -g fish_pager_color_description $muted
          set -g fish_pager_color_progress $muted

          if set -q TMUX
               tmux set -g status-style "fg=$fg,bg=$bg"
               tmux set -g status-left "#[fg=$bg,bg=$magenta,bold]    #S #[fg=$magenta,bg=$bg,nobold] "
               tmux set -g status-right "#[fg=$cyan,bg=$bg]  #[fg=$fg]#(tmux-system-status cpu)  #[fg=$green]  #[fg=$fg]#(tmux-system-status memory) #[fg=$yellow,bold]#(focus status --tmux)"
               tmux set -g window-status-current-format "#[fg=$blue,bg=$bg]#[fg=$bg,bg=$blue,bold] #I #W #[fg=$blue,bg=$bg,nobold] "
               tmux set -g window-status-format "#[fg=$muted,bg=$bg] #I #[fg=$fg]#W "
               tmux set -g message-style "fg=$bg,bg=$cyan,bold"
               tmux set -g mode-style "fg=$bg,bg=$yellow"
               tmux set -g clock-mode-colour "$blue"
               tmux set -g pane-border-style "fg=$muted"
               tmux set -g pane-active-border-style "fg=$blue"
               tmux set -g popup-border-style "fg=$blue"
               tmux set -g popup-style "fg=$fg,bg=$bg"
          end
        '';
      };
      envsource = {
        body = ''
          set -f envfile "$argv"
          if not test -f "$envfile"
              echo "Unable to load $envfile"
              return 1
          end
          while read line
              if not string match -qr '^#|^$' "$line"
                  if string match -qr '=' "$line"
                      set item (string split -m 1 '=' $line)
                      set item[2] (eval echo $item[2])
                      set -gx $item[1] $item[2]
                  else
                      eval $line
                  end
              end
          end <"$envfile"
        '';
      };
    };
  };

  # Custom functions and completions kept as files
  xdg.configFile = {
    "fish/functions/artisan.fish".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Projects/home/configs/fish/functions/artisan.fish";
    "fish/completions/artisan.fish".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Projects/home/configs/fish/completions/artisan.fish";
    "fish/completions/eops.fish".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Projects/home/configs/fish/completions/eops.fish";
    "fish/completions/work.fish".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Projects/home/configs/fish/completions/work.fish";
    "fish/completions/ssht.fish".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Projects/home/configs/fish/completions/ssht.fish";
  };
}
