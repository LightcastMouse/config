#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

tmp_home="$(mktemp -d)"
trap 'rm -rf "$tmp_home"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

HOME="$tmp_home" zsh -fc "source '$repo_root/.zshrc'" || fail "repo .zshrc should source successfully"

# The repo .zshrc should not source machine-local config directly. The generated
# ~/.zshrc loader is responsible for sourcing both repo config and ~/.zshrc.local.
printf 'return 42\n' > "$tmp_home/.zshrc.local"
HOME="$tmp_home" zsh -fc "source '$repo_root/.zshrc'" || fail "repo .zshrc should not depend on ~/.zshrc.local"

echo "all tests passed"
