# Config

Personal config files managed from this repo.

## Install

Clone this repo to `~/.config`, then run the full setup:

```bash
./setup.sh
```

To preview changes first:

```bash
./setup.sh --dry-run
```

The setup script creates `~/.local/bin`, checks required commands, and runs `install-symlinks.sh`.
Existing files/directories are backed up before being replaced with symlinks.

The setup script makes sure your local `~/.zshrc` sources the repo-managed `~/.config/.zshrc`. Existing local `~/.zshrc` contents are preserved by default.

## Test

```bash
./tests/install-symlinks.test.sh
./tests/setup.test.sh
./tests/zshrc.test.sh
```

## Managed configs

- `~/.zshrc` local file sources repo `.zshrc`
- `~/.aerospace.toml` → `aerospace.toml`
- `~/.config/ghostty` → `ghostty/`
- `~/.config/zed` → `zed/`
- `~/.local/bin/zed` → `/Applications/Zed.app/Contents/MacOS/cli` when needed
- `~/.warp` → `warp/`
- `~/Library/Application Support/lazygit/config.yml` → `lazygit/config.yml`
- `~/.config/blueboard` → `blueboard/` if present
- `~/.config/github-copilot` → `github-copilot/` if present
- `~/.config/.jira` → `.jira/` if present
