#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_symlink_to() {
  local link="$1"
  local target="$2"
  [[ -L "$link" ]] || fail "expected symlink: $link"
  [[ "$(readlink "$link")" == "$target" ]] || fail "expected $link -> $target, got $(readlink "$link")"
}

assert_zshrc_sources_repo() {
  local zshrc="$1"
  local repo="$2"
  [[ -f "$zshrc" ]] || fail "expected zshrc file: $zshrc"
  [[ ! -L "$zshrc" ]] || fail "expected zshrc to be a file, not symlink: $zshrc"
  grep -F "source \"$repo/.zshrc\"" "$zshrc" >/dev/null || fail "expected zshrc to source repo .zshrc"
}

make_repo() {
  local dest="$1"
  mkdir -p "$dest/ghostty" "$dest/zed/snippets" "$dest/warp"
  cp "$repo_root/setup.sh" "$dest/setup.sh"
  cp "$repo_root/install-symlinks.sh" "$dest/install-symlinks.sh"
  chmod +x "$dest/setup.sh" "$dest/install-symlinks.sh"
  printf 'zshrc\n' > "$dest/.zshrc"
  printf 'ghostty\n' > "$dest/ghostty/config.ghostty"
  printf 'zed\n' > "$dest/zed/settings.json"
  printf 'snippets\n' > "$dest/zed/snippets/snippets.json"
  printf 'warp\n' > "$dest/warp/settings.toml"
  printf 'keybindings\n' > "$dest/warp/keybindings.yaml"
}

test_setup_creates_local_bin_and_installs_symlinks() {
  local repo="$tmp_dir/repo-setup"
  local home="$tmp_dir/home-setup"
  make_repo "$repo"
  mkdir -p "$home"

  HOME="$home" XDG_CONFIG_HOME="$home/.config" "$repo/setup.sh" >/tmp/setup.out

  [[ -d "$home/.local/bin" ]] || fail "expected ~/.local/bin to be created"
  assert_zshrc_sources_repo "$home/.zshrc" "$repo"
  assert_symlink_to "$home/.config/ghostty" "$repo/ghostty"
  assert_symlink_to "$home/.config/zed" "$repo/zed"
  assert_symlink_to "$home/.warp" "$repo/warp"
}

test_setup_dry_run_does_not_change_files() {
  local repo="$tmp_dir/repo-setup-dry-run"
  local home="$tmp_dir/home-setup-dry-run"
  make_repo "$repo"
  mkdir -p "$home"

  HOME="$home" XDG_CONFIG_HOME="$home/.config" "$repo/setup.sh" --dry-run >/tmp/setup-dry-run.out

  [[ ! -e "$home/.local" ]] || fail "dry run should not create ~/.local"
  [[ ! -e "$home/.zshrc" ]] || fail "dry run should not create ~/.zshrc"
  [[ ! -e "$home/.config" ]] || fail "dry run should not create ~/.config"
  [[ ! -e "$home/.warp" ]] || fail "dry run should not create ~/.warp"
}

test_setup_passes_no_backup_to_installer() {
  local repo="$tmp_dir/repo-setup-no-backup"
  local home="$tmp_dir/home-setup-no-backup"
  make_repo "$repo"
  mkdir -p "$home"
  printf 'old zshrc\n' > "$home/.zshrc"

  HOME="$home" XDG_CONFIG_HOME="$home/.config" "$repo/setup.sh" --no-backup >/tmp/setup-no-backup.out

  [[ ! -L "$home/.zshrc" ]] || fail "--no-backup should not replace existing ~/.zshrc"
  [[ "$(cat "$home/.zshrc")" == "old zshrc" ]] || fail "--no-backup changed ~/.zshrc"
  assert_symlink_to "$home/.config/ghostty" "$repo/ghostty"
}

for test_name in \
  test_setup_creates_local_bin_and_installs_symlinks \
  test_setup_dry_run_does_not_change_files \
  test_setup_passes_no_backup_to_installer
 do
  "$test_name"
  echo "ok: $test_name"
done

echo "all tests passed"
