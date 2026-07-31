{ pkgs, lib, inputs, ... }:
let
  repos = import "${inputs.private}/repos.nix";
  git   = "${pkgs.git}/bin/git";

  cloneIfMissing = dest: r:
    assert lib.match "^[A-Za-z0-9._-]+$" r.name != null;
    let
      repoPath = lib.escapeShellArg "${dest}/${r.name}";
      repoUrl = lib.escapeShellArg r.url;
    in ''
    if [ ! -d ${repoPath}/.git ]; then
      echo "  cloning ${r.name}..."
      if ! ${git} clone ${repoUrl} ${repoPath}; then
        echo "  warning: failed to clone ${r.name}, will retry next activation"
        failed=1
      fi
    fi
  '';
in {
  home.activation.cloneRepos = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export GIT_SSH_COMMAND="/usr/bin/ssh -F $HOME/.ssh/config"
    sentinel="$HOME/.local/share/home-manager/.repos-cloned"
    if [ ! -f "$sentinel" ]; then
      echo "==> Cloning repos (first time setup)..."
      mkdir -p "$HOME/Projects" "$HOME/Work"
      failed=0

      ${lib.concatMapStrings (cloneIfMissing "$HOME/Projects") repos.personal}
      ${lib.concatMapStrings (cloneIfMissing "$HOME/Work")     repos.work}

      if [ "$failed" -eq 0 ]; then
        mkdir -p "$(dirname "$sentinel")"
        touch "$sentinel"
      fi
    fi
  '';
}
