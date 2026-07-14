
autoload -Uz colors && colors

default_dir_color=150
above_repo_dir_color=255
clean_repo_dir_color=220
staged_repo_dir_color=108
unstaged_repo_dir_color=203

function _prompt_escape_path {
  print -r -- "${1//\%/%%}"
}

function _git_dir_prompt_color {
  command git rev-parse --is-inside-work-tree &>/dev/null || {
    print -r -- $default_dir_color
    return
  }

  local git_status
  git_status="$(command git status --porcelain=v1 --untracked-files=normal 2>/dev/null)"

  if [[ -z "$git_status" ]]; then
    print -r -- $clean_repo_dir_color
  elif print -r -- "$git_status" | command grep -qE '^.[^ ]'; then
    print -r -- $unstaged_repo_dir_color
  elif print -r -- "$git_status" | command grep -qE '^[^ ]'; then
    print -r -- $staged_repo_dir_color
  else
    print -r -- $clean_repo_dir_color
  fi
}

function _git_dir_prompt {
  command git rev-parse --is-inside-work-tree &>/dev/null || {
    print -r -- "%F{$default_dir_color}%~%f"
    return
  }

  local repo_root repo_parent repo_name repo_path prefix dir_color
  repo_root="$(command git rev-parse --show-toplevel 2>/dev/null)" || {
    print -r -- "%F{$default_dir_color}%~%f"
    return
  }

  repo_parent="${repo_root:h}"
  repo_name="${repo_root:t}"
  repo_path="$repo_name${PWD#$repo_root}"
  dir_color="$(_git_dir_prompt_color)"

  if [[ "$repo_parent" == "$HOME" ]]; then
    prefix="~/"
  elif [[ "$repo_parent" == "$HOME"/* ]]; then
    prefix="~/${repo_parent#$HOME/}/"
  elif [[ "$repo_parent" == / ]]; then
    prefix="/"
  else
    prefix="$repo_parent/"
  fi

  print -r -- "%F{$above_repo_dir_color}$(_prompt_escape_path "$prefix")%f%F{$dir_color}$(_prompt_escape_path "$repo_path")%f"
}

function _set_prompt {
  local last_status=$?
  local dir_prompt="$(_git_dir_prompt)"
  local arrow_color

  if (( last_status == 0 )); then
    arrow_color=108
  else
    arrow_color=203
  fi

  PS1="%f ${dir_prompt} %F{$arrow_color}❯%f "
  return $last_status
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _set_prompt

# source .zshrc
function s {
  if [[ $1 = "z" ]]; then
    source ~/.zshrc &&
      echo "sourced ~/.zshrc"
  elif [[ $1 = "s" ]]; then
    source setup.sh &&
      echo "sourced setup.sh"
  fi
}

# common commands
alias co='zed .'

# npm
alias ni='npm install'
alias nrd='npm run dev'
alias nra='npm run app'
alias nrb='npm run build'
alias nrl='npm run lint'
# bun
alias bi='bun install'
alias brb='bun run build'
alias brl='bun run lint'
alias brc='bun run check'
alias brt='bun run test'
alias brd='bun run dev'
alias brdb='bun run db'

alias ttdev='bun "$HOME/.config/tt/dev.ts"'

# git
alias kk='git checkout'
alias gs='git status'
alias gp='git pull'
alias gpu='git push'
alias gcm='git commit -am'
alias gb='git branch'
alias gbd='git branch -D'

# lazygit
alias lgit='lazygit'

# TT Postgres
alias cleanuppg="~/d/tt/lab/db/setup-local-postgres.sh --cleanup"
alias resetpg="~/d/tt/lab/db/setup-local-postgres.sh --reset"

# ssh keys
alias add-gitlab-ssh-key='ssh-add --apple-use-keychain ~/.ssh/id_ed25519-m4-macbook-pro-08-2025-gitlab >/dev/null 2>&1'
alias add-github-ssh-key='ssh-add --apple-use-keychain ~/.ssh/id_ed25519-m4-macbook-pro-08-2025-github >/dev/null 2>&1'
alias add-universal-ssh-key='ssh-add --apple-use-keychain ~/.ssh/id_ed25519_ssh_key >/dev/null 2>&1'

function add-ssh-keys() {
  add-gitlab-ssh-key
  add-github-ssh-key
  add-universal-ssh-key
}

if command -v ssh-add >/dev/null 2>&1; then
  add-ssh-keys
fi

# paths
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
export PATH="$PATH:$HOME/Library/Python/3.9/bin"
export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"

# nvm
export NVM_DIR="$HOME/.nvm"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  source "$NVM_DIR/nvm.sh"
fi
if [[ -s "$NVM_DIR/bash_completion" ]]; then
  source "$NVM_DIR/bash_completion"
fi

# Puppeteer / Chromium
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
if command -v chromium >/dev/null 2>&1; then
  export PUPPETEER_EXECUTABLE_PATH="$(command -v chromium)"
fi

# bun completions
if [[ -s "$HOME/.bun/_bun" ]]; then
  source "$HOME/.bun/_bun"
fi

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# deno
export DENO_INSTALL="$HOME/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# PostgreSQL, if installed through Homebrew.
if command -v brew >/dev/null 2>&1 && brew --prefix postgresql@17 >/dev/null 2>&1; then
  export PATH="$(brew --prefix postgresql@17)/bin:$PATH"
fi

export EDITOR="zed --wait"
export VISUAL="zed --wait"

# Enable colors for ls
export CLICOLOR=1

# Define colors for different types (directories, links, executables, etc.)
export LSCOLORS="Gxfxcxdxbxegedabagacad"

export WARP_DB="$HOME/Library/Group Containers/2BBY89MBSN.dev.warp/Library/Application Support/dev.warp.Warp-Stable/warp.sqlite"

function warp_prune_interactive {
  : "${WARP_DB:?set WARP_DB first}"
  command -v fzf >/dev/null || { echo 'missing: fzf' >&2; return 1; }

  local src_file sel_file
  src_file="$(mktemp)" || return 1
  sel_file="$(mktemp)" || { rm -f "$src_file"; return 1; }

  python3 - "$WARP_DB" > "$src_file" <<'PY'
import re, sqlite3, sys

conn = sqlite3.connect(sys.argv[1])
cur = conn.cursor()
queries = [
    ("commands", "id", "coalesce(start_ts, '')", "command"),
    ("ai_queries", "id", "coalesce(start_ts, '')", "input"),
    ("agent_conversations", "id", "coalesce(last_modified_at, '')", "conversation_data"),
]

def squish(text):
    return re.sub(r"\s+", " ", text or "").strip()

for table, id_col, ts_expr, text_col in queries:
    sql = f"select {id_col}, {ts_expr}, {text_col} from {table} order by {id_col} desc"
    for row_id, ts, text in cur.execute(sql):
        full = squish(text)
        preview = full[:140] + ("..." if len(full) > 140 else "")
        print(f"{table}\t{row_id}\t{ts[:19]}\t{preview}")
PY

  fzf --multi --layout=reverse --delimiter=$'\t' --with-nth=1,3,4 \
    --bind 'space:toggle,ctrl-a:select-all' \
    --preview 'printf "%s\n" {4}' \
    --preview-window='wrap' \
    < "$src_file" > "$sel_file" || {
      rm -f "$src_file" "$sel_file"
      return 1
    }

  python3 - "$WARP_DB" "$sel_file" "${HISTFILE:-$HOME/.zsh_history}" <<'PY'
import shutil, sqlite3, sys

DB = sys.argv[1]
SEL = sys.argv[2]
HISTFILE = sys.argv[3]

with open(SEL) as f:
    rows = [line.rstrip("\n").split("\t", 3) for line in f if line.strip()]

if not rows:
    raise SystemExit(0)

backup = DB + ".bak"
shutil.copy2(DB, backup)
print(f"db backup: {backup}")

by_table = {}
for table, row_id, *_ in rows:
    by_table.setdefault(table, []).append(int(row_id))

conn = sqlite3.connect(DB)
cur = conn.cursor()

selected_commands = set()
command_ids = by_table.get("commands", [])
if command_ids:
    placeholders = ",".join("?" for _ in command_ids)
    for (command,) in cur.execute(f'SELECT command FROM "commands" WHERE id IN ({placeholders})', command_ids):
        selected_commands.add(command)

for table, ids in by_table.items():
    placeholders = ",".join("?" for _ in ids)
    cur.execute(f'DELETE FROM "{table}" WHERE id IN ({placeholders})', ids)
    print(f'{table}: deleted {cur.rowcount} rows')

conn.commit()
cur.execute("PRAGMA wal_checkpoint(TRUNCATE);")
cur.execute("VACUUM;")
conn.close()

if selected_commands:
    hist_backup = HISTFILE + ".bak"
    shutil.copy2(HISTFILE, hist_backup)
    print(f"zsh history backup: {hist_backup}")

    removed = 0
    kept = []
    with open(HISTFILE, "r", encoding="utf-8", errors="surrogateescape") as f:
        for line in f:
            payload = line.split(";", 1)[1] if ";" in line else line
            payload = payload.rstrip("\n")
            if payload in selected_commands:
                removed += 1
                continue
            kept.append(line)

    with open(HISTFILE, "w", encoding="utf-8", errors="surrogateescape") as f:
        f.writelines(kept)

    print(f'zsh_history: deleted {removed} rows')
PY

  rm -f "$src_file" "$sel_file"
}
