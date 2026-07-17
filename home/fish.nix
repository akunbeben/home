{ config, ... }: {
  programs.fish = {
    enable = true;

    shellAliases = {
      q        = "exit";
      c        = "clear";
      l        = "eza --long --icons --group-directories-first";
      v        = "nvim .";
      t        = "tmux a";
      tk       = "tmux kill-session";
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
      home = "cd ~";
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
      terminal-theme-sync = {
        body = ''
          set -l mode (defaults read -g AppleInterfaceStyle 2>/dev/null)
          if test "$mode" = Dark
              set theme ~/.config/kitty/kitty-themes/themes/TokyoNightStorm.conf
              set bg '#24283b'
              set fg '#c0caf5'
              set muted '#414868'
              set green '#9ece6a'
              set blue '#7aa2f7'
              set cyan '#7dcfff'
              set magenta '#bb9af7'
              set yellow '#e0af68'
          else
              set theme ~/.config/kitty/kitty-themes/themes/TokyoNightDay.conf
              set bg '#e1e2e7'
              set fg '#3760bf'
              set muted '#99a7df'
              set green '#587539'
              set blue '#2e7de9'
              set cyan '#007197'
              set magenta '#9854f1'
              set yellow '#8c6c3e'
          end

          cp $theme ~/.config/kitty/current-theme.conf

          for sock in /tmp/kitty-*
              test -S $sock; and /Applications/kitty.app/Contents/MacOS/kitty @ --to unix:$sock \
                  set-colors --all $theme 2>/dev/null
          end

          if set -q TMUX
              tmux set -g status-style "fg=$fg,bg=$bg"
              tmux set -g status-left "#[fg=$bg,bg=$magenta,bold]  #S "
              tmux set -g status-right "#[fg=$bg,bg=$cyan,bold]  #{cpu} #[fg=$bg,bg=$green]  #{mem} #[fg=$bg,bg=$yellow,bold]#(focus status --tmux)"
              tmux set -g window-status-current-format "#[fg=$bg,bg=$blue,bold] #I:#W "
              tmux set -g window-status-format "#[fg=$fg,bg=$muted] #I:#W "
              tmux set -g message-style "fg=$cyan,bg=default"
              tmux set -g mode-style "fg=$bg,bg=$yellow"
              tmux set -g pane-border-style "fg=$bg"
              tmux set -g pane-active-border-style "fg=$blue"
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
