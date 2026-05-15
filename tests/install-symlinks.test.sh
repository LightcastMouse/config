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

assert_exists() {
  [[ -e "$1" || -L "$1" ]] || fail "expected path to exist: $1"
}

make_repo() {
  local dest="$1"
  mkdir -p "$dest/ghostty" "$dest/zed/snippets" "$dest/warp" "$dest/blueboard" "$dest/github-copilot" "$dest/.jira"
  cp "$repo_root/install-symlinks.sh" "$dest/install-symlinks.sh"
  chmod +x "$dest/install-symlinks.sh"
  printf 'zshrc\n' > "$dest/.zshrc"
  printf 'ghostty\n' > "$dest/ghostty/config.ghostty"
  printf 'zed\n' > "$dest/zed/settings.json"
  printf 'snippets\n' > "$dest/zed/snippets/snippets.json"
  printf 'warp\n' > "$dest/warp/settings.toml"
  printf 'keybindings\n' > "$dest/warp/keybindings.yaml"
  printf 'blueboard\n' > "$dest/blueboard/settings.json"
  printf 'copilot\n' > "$dest/github-copilot/apps.json"
  printf 'jira\n' > "$dest/.jira/.config.yml"
}

test_installs_symlinks() {
  local repo="$tmp_dir/repo-install"
  local home="$tmp_dir/home-install"
  make_repo "$repo"
  mkdir -p "$home"

  HOME="$home" XDG_CONFIG_HOME="$home/.config" "$repo/install-symlinks.sh" >/tmp/install-symlinks.out

  assert_symlink_to "$home/.zshrc" "$repo/.zshrc"
  assert_symlink_to "$home/.config/ghostty" "$repo/ghostty"
  assert_symlink_to "$home/.config/zed" "$repo/zed"
  assert_symlink_to "$home/.warp" "$repo/warp"
  assert_symlink_to "$home/.config/blueboard" "$repo/blueboard"
  assert_symlink_to "$home/.config/github-copilot" "$repo/github-copilot"
  assert_symlink_to "$home/.config/.jira" "$repo/.jira"
}

test_backs_up_existing_destinations() {
  local repo="$tmp_dir/repo-backup"
  local home="$tmp_dir/home-backup"
  make_repo "$repo"
  mkdir -p "$home/.config/ghostty" "$home/.config"
  printf 'old zshrc\n' > "$home/.zshrc"
  printf 'old ghostty\n' > "$home/.config/ghostty/config.ghostty"

  HOME="$home" XDG_CONFIG_HOME="$home/.config" "$repo/install-symlinks.sh" >/tmp/install-symlinks-backup.out

  assert_symlink_to "$home/.zshrc" "$repo/.zshrc"
  assert_symlink_to "$home/.config/ghostty" "$repo/ghostty"
  compgen -G "$home/.zshrc.backup.*" >/dev/null || fail "expected .zshrc backup"
  compgen -G "$home/.config/ghostty.backup.*" >/dev/null || fail "expected ghostty backup"
}

test_dry_run_does_not_change_files() {
  local repo="$tmp_dir/repo-dry-run"
  local home="$tmp_dir/home-dry-run"
  make_repo "$repo"
  mkdir -p "$home/.config"
  printf 'old zshrc\n' > "$home/.zshrc"

  HOME="$home" XDG_CONFIG_HOME="$home/.config" "$repo/install-symlinks.sh" --dry-run >/tmp/install-symlinks-dry-run.out

  [[ ! -L "$home/.zshrc" ]] || fail "dry run should not replace .zshrc"
  [[ "$(cat "$home/.zshrc")" == "old zshrc" ]] || fail "dry run changed .zshrc contents"
  ! compgen -G "$home/.zshrc.backup.*" >/dev/null || fail "dry run created backup"
}

test_no_backup_skips_existing_destinations() {
  local repo="$tmp_dir/repo-no-backup"
  local home="$tmp_dir/home-no-backup"
  make_repo "$repo"
  mkdir -p "$home/.config"
  printf 'old zshrc\n' > "$home/.zshrc"

  HOME="$home" XDG_CONFIG_HOME="$home/.config" "$repo/install-symlinks.sh" --no-backup >/tmp/install-symlinks-no-backup.out

  [[ ! -L "$home/.zshrc" ]] || fail "--no-backup should skip existing .zshrc"
  [[ "$(cat "$home/.zshrc")" == "old zshrc" ]] || fail "--no-backup changed .zshrc contents"
  assert_symlink_to "$home/.config/ghostty" "$repo/ghostty"
}

test_force_replaces_existing_destinations() {
  local repo="$tmp_dir/repo-force"
  local home="$tmp_dir/home-force"
  make_repo "$repo"
  mkdir -p "$home"
  printf 'old zshrc\n' > "$home/.zshrc"

  HOME="$home" XDG_CONFIG_HOME="$home/.config" "$repo/install-symlinks.sh" --force >/tmp/install-symlinks-force.out

  assert_symlink_to "$home/.zshrc" "$repo/.zshrc"
  ! compgen -G "$home/.zshrc.backup.*" >/dev/null || fail "--force should not create backup"
}

for test_name in \
  test_installs_symlinks \
  test_backs_up_existing_destinations \
  test_dry_run_does_not_change_files \
  test_no_backup_skips_existing_destinations \
  test_force_replaces_existing_destinations
 do
  "$test_name"
  echo "ok: $test_name"
done

echo "all tests passed"
