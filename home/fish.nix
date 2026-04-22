{ ... }: {
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
      ai       = "gemini";
      gg       = "goto-ssh";
      dot      = "nvim ~/Projects/home";
      start    = "sudo systemctl start";
      stop     = "sudo systemctl stop";
      restart  = "sudo systemctl restart";
      mysqldump = "/usr/bin/mariadb-dump";
      php      = "valet php";
      composer = "valet composer";
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
      lint       = "./vendor/bin/pint";

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
      gpersonal = ''git config user.email "akunbeben@gmail.com"'';
      gwork     = ''git config user.email "benny.rahmat@thrive.co.id"'';

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

      set --export BUN_INSTALL "$HOME/.bun"
      fish_add_path $BUN_INSTALL/bin

      set -gx PNPM_HOME $HOME/Library/pnpm
      fish_add_path $PNPM_HOME

      set fish_greeting
      set -gx EDITOR nvim

      envsource "$HOME/.env"

      fnm env --use-on-cd --shell fish | source

      if test -f "$HOME/.cargo/env.fish"
          source "$HOME/.cargo/env.fish"
      end
    '';

    functions = {
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
    "fish/functions/artisan.fish".source = ../configs/fish/functions/artisan.fish;
    "fish/functions/eops.fish".source    = ../configs/fish/functions/eops.fish;
    "fish/completions/artisan.fish".source = ../configs/fish/completions/artisan.fish;
    "fish/completions/eops.fish".source    = ../configs/fish/completions/eops.fish;
    "fish/completions/work.fish".source    = ../configs/fish/completions/work.fish;
    "fish/completions/ssht.fish".source    = ../configs/fish/completions/ssht.fish;
  };
}
