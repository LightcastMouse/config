# Config

Personal config files managed from this repo.

## Install

Clone this repo to `~/.config`, then run:

```bash
./install-symlinks.sh
```

To preview changes first:

```bash
./install-symlinks.sh --dry-run
```

The script backs up existing files/directories before replacing them with symlinks.

## Test

```bash
./tests/install-symlinks.test.sh
```

## Managed configs

- `~/.zshrc` → `.zshrc`
- `~/.config/ghostty` → `ghostty/`
- `~/.config/zed` → `zed/`
- `~/.warp` → `warp/`
- `~/.config/blueboard` → `blueboard/` if present
- `~/.config/github-copilot` → `github-copilot/` if present
- `~/.config/.jira` → `.jira/` if present
