#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./install-symlinks.sh [--dry-run] [--force] [--no-backup]

Symlink this config repo into the locations used by each app.
Existing files/directories are backed up by default before being replaced.

Options:
  --dry-run    Print what would happen without changing anything
  --force      Remove existing destinations instead of backing them up
  --no-backup  Skip existing destinations instead of backing them up
  -h, --help   Show this help
EOF
}

DRY_RUN=0
FORCE=0
NO_BACKUP=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --force) FORCE=1 ;;
    --no-backup) NO_BACKUP=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

run() {
  if [[ "$DRY_RUN" == 1 ]]; then
    printf 'dry-run: '
    printf '%q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
timestamp="$(date +%Y%m%d%H%M%S)"

link_item() {
  local src="$1"
  local dest="$2"

  if [[ ! -e "$src" && ! -L "$src" ]]; then
    echo "skip: source missing: $src"
    return
  fi

  if [[ "$src" == "$dest" ]]; then
    echo "ok: already in place: $dest"
    return
  fi

  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    echo "ok: already linked: $dest -> $src"
    return
  fi

  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ "$FORCE" == 1 ]]; then
      echo "remove: $dest"
      run rm -rf "$dest"
    elif [[ "$NO_BACKUP" == 1 ]]; then
      echo "skip: destination exists: $dest"
      return
    else
      local backup="${dest}.backup.${timestamp}"
      echo "backup: $dest -> $backup"
      run mv "$dest" "$backup"
    fi
  fi

  echo "link: $dest -> $src"
  run mkdir -p "$(dirname "$dest")"
  run ln -s "$src" "$dest"
}

# Files/directories tracked by this repo and where the apps expect them.
link_item "$repo_dir/.zshrc" "$HOME/.zshrc"
link_item "$repo_dir/ghostty" "$config_home/ghostty"
link_item "$repo_dir/zed" "$config_home/zed"
link_item "$repo_dir/warp" "$HOME/.warp"

# Optional local config directories, if present in this checkout.
link_item "$repo_dir/blueboard" "$config_home/blueboard"
link_item "$repo_dir/github-copilot" "$config_home/github-copilot"
link_item "$repo_dir/.jira" "$config_home/.jira"

echo "done"
