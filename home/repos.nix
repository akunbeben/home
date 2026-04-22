{ pkgs, lib, ... }:
let
  repos = import ../data/repos.nix;
  git   = "${pkgs.git}/bin/git";

  cloneIfMissing = dest: r: ''
    if [ ! -d "${dest}/${r.name}/.git" ]; then
      echo "  cloning ${r.name}..."
      ${git} clone "${r.url}" "${dest}/${r.name}"
    fi
  '';
in {
  home.activation.cloneRepos = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
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
