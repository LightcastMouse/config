#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./setup.sh [--dry-run] [--force] [--no-backup]

Set up this config repo on a machine:
  - checks for required commands
  - creates ~/.local/bin
  - installs/symlinks the managed config files

Options are passed through to install-symlinks.sh.
EOF
}

DRY_RUN=0
INSTALL_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      INSTALL_ARGS+=("$1")
      ;;
    --force|--no-backup)
      INSTALL_ARGS+=("$1")
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
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

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "missing required command: $command_name" >&2
    return 1
  fi
}

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

require_command git
require_command zsh

if [[ ! -x "$repo_dir/install-symlinks.sh" ]]; then
  echo "missing executable installer: $repo_dir/install-symlinks.sh" >&2
  exit 1
fi

echo "create: $HOME/.local/bin"
run mkdir -p "$HOME/.local/bin"

echo "install: config symlinks"
if (( ${#INSTALL_ARGS[@]} > 0 )); then
  "$repo_dir/install-symlinks.sh" "${INSTALL_ARGS[@]}"
else
  "$repo_dir/install-symlinks.sh"
fi

cat <<'EOF'

Setup complete.

Next steps:
  1. Restart your terminal, or run: source ~/.zshrc
  2. Check Zed with: zed .

If you need machine-specific shell config, put it in ~/.zshrc
EOF
