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

The setup script writes a small `~/.zshrc` loader file. That loader sources the repo-managed `~/.config/.zshrc` first, then `~/.zshrc.local` if it exists.

For machine-specific shell setup, put it in `~/.zshrc.local`.

## Test

```bash
./tests/install-symlinks.test.sh
./tests/setup.test.sh
./tests/zshrc.test.sh
```

## Managed configs

- `~/.zshrc` loader file sources `.zshrc` and `~/.zshrc.local`
- `~/.config/ghostty` → `ghostty/`
- `~/.config/zed` → `zed/`
- `~/.local/bin/zed` → `/Applications/Zed.app/Contents/MacOS/cli` when needed
- `~/.warp` → `warp/`
- `~/.config/blueboard` → `blueboard/` if present
- `~/.config/github-copilot` → `github-copilot/` if present
- `~/.config/.jira` → `.jira/` if present
