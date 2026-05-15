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

For machine-specific shell setup, put it in `~/.zshrc.local`. The repo-managed `.zshrc` sources that file if it exists.

## Test

```bash
./tests/install-symlinks.test.sh
./tests/setup.test.sh
```

## Managed configs

- `~/.zshrc` → `.zshrc`
- `~/.config/ghostty` → `ghostty/`
- `~/.config/zed` → `zed/`
- `~/.local/bin/zed` → `/Applications/Zed.app/Contents/MacOS/cli` when needed
- `~/.warp` → `warp/`
- `~/.config/blueboard` → `blueboard/` if present
- `~/.config/github-copilot` → `github-copilot/` if present
- `~/.config/.jira` → `.jira/` if present
