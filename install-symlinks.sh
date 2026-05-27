#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./install-symlinks.sh [--dry-run] [--force] [--no-backup]

Install this config repo into the locations used by each app.
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

ensure_zshrc_sources_repo() {
  local dest="$HOME/.zshrc"
  local repo_zshrc="$repo_dir/.zshrc"
  local source_line="source \"$repo_zshrc\""
  local loader
  loader="$(cat <<EOF
# Local shell entrypoint. Shared config lives in the config repo.
$source_line
EOF
)"

  if [[ ! -e "$repo_zshrc" ]]; then
    echo "skip: source missing: $repo_zshrc"
    return
  fi

  if [[ -f "$dest" && ! -L "$dest" ]] && grep -F "$source_line" "$dest" >/dev/null 2>&1; then
    echo "ok: zshrc already sources repo config: $dest"
    return
  fi

  if [[ -L "$dest" && "$(readlink "$dest")" == "$repo_zshrc" ]]; then
    echo "replace: old zsh symlink with local zshrc file: $dest"
    run rm "$dest"
  elif [[ -e "$dest" || -L "$dest" ]]; then
    if [[ "$FORCE" == 1 ]]; then
      echo "remove: $dest"
      run rm -rf "$dest"
    elif [[ "$NO_BACKUP" == 1 ]]; then
      echo "skip: destination exists: $dest"
      return
    else
      local backup="${dest}.backup.${timestamp}"
      echo "backup: $dest -> $backup"
      run cp -p "$dest" "$backup"
      echo "append: repo config source to $dest"
      if [[ "$DRY_RUN" == 0 ]]; then
        printf '\n# Shared config from config repo.\n%s\n' "$source_line" >> "$dest"
      else
        echo "dry-run: append $source_line to $dest"
      fi
      return
    fi
  fi

  echo "write: $dest"
  run mkdir -p "$(dirname "$dest")"
  if [[ "$DRY_RUN" == 0 ]]; then
    printf '%s\n' "$loader" > "$dest"
  else
    echo "dry-run: write zsh loader to $dest"
  fi
}

ensure_zed_cli() {
  if command -v zed >/dev/null 2>&1; then
    echo "ok: zed CLI found: $(command -v zed)"
    return
  fi

  local zed_cli="/Applications/Zed.app/Contents/MacOS/cli"
  local dest="$HOME/.local/bin/zed"

  if [[ ! -x "$zed_cli" ]]; then
    echo "skip: Zed CLI source missing: $zed_cli"
    echo "      Install Zed, then run 'zed: install cli' from Zed or rerun this script."
    return
  fi

  link_item "$zed_cli" "$dest"
}

# Files/directories tracked by this repo and where the apps expect them.
ensure_zshrc_sources_repo
link_item "$repo_dir/aerospace.toml" "$HOME/.aerospace.toml"
link_item "$repo_dir/ghostty" "$config_home/ghostty"
link_item "$repo_dir/zed" "$config_home/zed"
link_item "$repo_dir/warp" "$HOME/.warp"
link_item "$repo_dir/lazygit/config.yml" "$HOME/Library/Application Support/lazygit/config.yml"
ensure_zed_cli

# Optional local config directories, if present in this checkout.
link_item "$repo_dir/blueboard" "$config_home/blueboard"
link_item "$repo_dir/github-copilot" "$config_home/github-copilot"
link_item "$repo_dir/.jira" "$config_home/.jira"

echo "done"
