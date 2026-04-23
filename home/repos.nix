{ pkgs, lib, inputs, ... }:
let
  repos = import "${inputs.private}/repos.nix";
  git   = "${pkgs.git}/bin/git";

  cloneIfMissing = dest: r: ''
    if [ ! -d "${dest}/${r.name}/.git" ]; then
      echo "  cloning ${r.name}..."
      ${git} clone "${r.url}" "${dest}/${r.name}" || echo "  warning: failed to clone ${r.name}, skipping"
    fi
  '';
in {
  home.activation.cloneRepos = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export GIT_SSH_COMMAND="/usr/bin/ssh -F $HOME/.ssh/config"
    sentinel="$HOME/.local/share/home-manager/.repos-cloned"
    if [ ! -f "$sentinel" ]; then
      echo "==> Cloning repos (first time setup)..."
      mkdir -p "$HOME/Projects" "$HOME/Work"

      ${lib.concatMapStrings (cloneIfMissing "$HOME/Projects") repos.personal}
      ${lib.concatMapStrings (cloneIfMissing "$HOME/Work")     repos.work}

      mkdir -p "$(dirname "$sentinel")"
      touch "$sentinel"
    fi
  '';
}
