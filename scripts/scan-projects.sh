#!/usr/bin/env bash
# Scan ~/Projects recursively for git repos and categorize by remote origin.
# Outputs a visual table + nix-formatted clone list.
#
# Usage: bash scripts/scan-projects.sh

set -euo pipefail

SCAN_DIR="${1:-$HOME/Projects}"

declare -a personal_repos=()
declare -a work_repos=()
declare -a dummy_repos=()

while IFS= read -r git_dir; do
  repo_dir="${git_dir%/.git}"
  origin=$(git -C "$repo_dir" remote get-url origin 2>/dev/null || echo "")

  if [[ "$origin" == *"github.com-personal"* ]]; then
    personal_repos+=("$repo_dir|$origin")
  elif [[ "$origin" == *"github.com-work"* ]]; then
    work_repos+=("$repo_dir|$origin")
  else
    dummy_repos+=("$repo_dir|$origin")
  fi
done < <(find "$SCAN_DIR" -name ".git" -type d | sort)

# --- Table helpers ---
TL='┌' TR='┐' BL='└' BR='┘'
H='─' V='│' TM='┬' BM='┴' LM='├' RM='┤' CR='┼'

_hline() { printf '%0.s'"$H" $(seq 1 "$1"); }
_pad()   { printf "%-${1}s" "$2"; }
_top()   { printf '%s%s%s%s%s\n' "$TL" "$(_hline "$1")" "$TM" "$(_hline "$2")" "$TR"; }
_mid()   { printf '%s%s%s%s%s\n' "$LM" "$(_hline "$1")" "$CR" "$(_hline "$2")" "$RM"; }
_bot()   { printf '%s%s%s%s%s\n' "$BL" "$(_hline "$1")" "$BM" "$(_hline "$2")" "$BR"; }
_row()   { printf '%s %s %s %s %s\n' "$V" "$(_pad "$(($1-2))" "$3")" "$V" "$(_pad "$(($2-2))" "$4")" "$V"; }

_print_table() {
  local label="$1"; shift
  local -a rows=("$@")

  if [[ ${#rows[@]} -eq 0 ]]; then
    return
  fi

  local w1=8 w2=10
  for entry in "${rows[@]}"; do
    path="${entry%%|*}"
    url="${entry##*|}"
    name=$(basename "$path")
    (( ${#name} + 2 > w1 )) && w1=$(( ${#name} + 2 ))
    (( ${#url}  + 2 > w2 )) && w2=$(( ${#url}  + 2 ))
  done

  echo ""
  echo "[$label]"
  _top "$w1" "$w2"
  _row "$w1" "$w2" "Name" "Remote Origin"
  _mid "$w1" "$w2"
  local i=0
  for entry in "${rows[@]}"; do
    path="${entry%%|*}"
    url="${entry##*|}"
    _row "$w1" "$w2" "$(basename "$path")" "$url"
    (( i < ${#rows[@]} - 1 )) && _mid "$w1" "$w2"
    (( i++ )) || true
  done
  _bot "$w1" "$w2"
}

# --- Print tables ---
_print_table "PERSONAL" "${personal_repos[@]+"${personal_repos[@]}"}"
_print_table "WORK"     "${work_repos[@]+"${work_repos[@]}"}"
_print_table "DUMMY"    "${dummy_repos[@]+"${dummy_repos[@]}"}"

# --- Print nix clone list ---
echo ""
echo "# ============================================================"
echo "# Paste into data/repos.nix (review before saving)"
echo "# Rename duplicate 'name' values before using."
echo "# ============================================================"
echo "{"
echo "  personal = ["

for entry in "${personal_repos[@]+"${personal_repos[@]}"}"; do
  path="${entry%%|*}"
  url="${entry##*|}"
  name=$(basename "$path")
  echo "    { name = \"$name\"; url = \"$url\"; }"
done

echo "  ];"
echo ""
echo "  work = ["

for entry in "${work_repos[@]+"${work_repos[@]}"}"; do
  path="${entry%%|*}"
  url="${entry##*|}"
  name=$(basename "$path")
  echo "    { name = \"$name\"; url = \"$url\"; }"
done

echo "  ];"
echo "}"
