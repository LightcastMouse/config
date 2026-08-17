
autoload -Uz colors && colors

default_dir_color=150
above_repo_dir_color=255
clean_repo_dir_color=220
staged_repo_dir_color=108
unstaged_repo_dir_color=203

## prompt
# escape path for PS1 (ahelp-blacklist-me)
function _prompt_escape_path {
  print -r -- "${1//\%/%%}"
}

# git dir prompt color (ahelp-blacklist-me)
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

# git dir prompt segment (ahelp-blacklist-me)
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

# set PS1 (ahelp-blacklist-me)
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

## shell
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

# list all aliases/funcs, ordered by last used
# tag a preceding comment with (ahelp-blacklist-me) to hide that entry
function ahelp() {
  local cfg="$HOME/.config/.zshrc"
  local db="${WARP_DB:-$HOME/Library/Group Containers/2BBY89MBSN.dev.warp/Library/Application Support/dev.warp.Warp-Stable/warp.sqlite}"

  sqlite3 -separator $'\t' "$db" "
    SELECT strftime('%s', start_ts), command
    FROM commands
    WHERE command IS NOT NULL AND command != ''
  " 2>/dev/null | awk -F'\t' -v cfg="$cfg" '
    FNR==NR {
      ts = $1
      cmd = $2
      sub(/^[\r\n\t \x01-\x1f]+/, "", cmd)
      split(cmd, parts, /[ \t]+/)
      name = parts[1]
      if (name != "" && (ts+0) > (last[name]+0)) last[name] = ts
      next
    }
    {
      if ($0 ~ /^## /) { next }
      if ($0 ~ /^# /)  { c = $0; sub(/^# */, "", c); next }
      if ($0 ~ /^alias [a-zA-Z0-9_-]+=/) {
        name = $0; sub(/^alias /, "", name); sub(/=.*/, "", name)
        emit(name); next
      }
      if ($0 ~ /^function [a-zA-Z0-9_-]+/) {
        name = $0; sub(/^function /, "", name); sub(/[ (].*/, "", name)
        emit(name); next
      }
      if ($0 ~ /^[a-zA-Z_][a-zA-Z0-9_-]*\(\)/) {
        name = $0; sub(/\(\).*/, "", name)
        emit(name); next
      }
    }
    function emit(name) {
      if (c ~ /\(ahelp-blacklist-me\)/) { c = ""; return }
      t = last[name] + 0
      nrows++; rowt[nrows] = t; rowname[nrows] = name; rowc[nrows] = c
      c = ""
    }
    END {
      for (i = 1; i <= nrows; i++) {
        print rowt[i] "\t" rowname[i] "\t" rowc[i]
      }
    }
  ' - "$cfg" | sort -t $'\t' -k1,1nr | while IFS=$'\t' read -r ts name cmt; do
    if [[ "$ts" == "0" ]]; then
      d="never"
    else
      d="$(date -r "$ts" +%Y-%m-%d)"
    fi
    printf "%-22s %-30s %s\n" "$name" "$cmt" "$d"
  done
}

## editor
# open cwd in Zed
alias co='zed .'

## network
# find PID on port
function findPortPID() {
  lsof -nP -iTCP:"$1" -sTCP:LISTEN
}

# kill a PID
function killPID() {
  kill "$1"
}

# kill process on port
function freePort() {
  if [[ $# -ne 1 || ! "$1" =~ '^[0-9]+$' || "$1" -lt 1 || "$1" -gt 65535 ]]; then
    echo 'usage: freePort <port>' >&2
    return 2
  fi

  local pids
  pids=(${(@f)$(lsof -tiTCP:"$1" -sTCP:LISTEN)})

  if (( ${#pids[@]} == 0 )); then
    echo "No process listening on port $1"
    return 1
  fi

  kill "${pids[@]}"
}

## warp
export WARP_DB="$HOME/Library/Group Containers/2BBY89MBSN.dev.warp/Library/Application Support/dev.warp.Warp-Stable/warp.sqlite"

# open 3 Warp tabs
function warp-tabs() {
  if [[ $# -ne 1 || ! "$1" =~ '^[[:alnum:]_-]+$' ]]; then
    echo 'usage: warp-tabs <ticket>' >&2
    return 2
  fi

  osascript <<'APPLESCRIPT'
tell application "Warp" to activate
tell application "System Events"
  repeat 3 times
    keystroke "t" using {command down}
    delay 1
  end repeat
end tell
APPLESCRIPT

  python3 - "$WARP_DB" "$1" <<'PY'
import sqlite3
import sys
import time

titles = [f"[{sys.argv[2]}] {name}" for name in ("dev", "pi", "lgit")]
for _ in range(10):
    try:
        with sqlite3.connect(sys.argv[1], timeout=1) as db:
            tab_ids = [row[0] for row in db.execute(
                "SELECT id FROM tabs ORDER BY id DESC LIMIT 3"
            )]
            if len(tab_ids) != 3:
                raise RuntimeError("could not find three new Warp tabs")
            db.executemany(
                "UPDATE tabs SET custom_title = ? WHERE id = ?",
                zip(titles, tab_ids),
            )
        break
    except sqlite3.OperationalError:
        time.sleep(0.2)
else:
    raise SystemExit("could not update Warp tab titles")
PY
}
# open 3 Warp tabs
alias wt='warp-tabs'

# prune Warp history
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
    --header='ctrl-a/alt-a: select all · space: toggle' \
    --bind 'space:toggle,ctrl-a:select-all,alt-a:select-all' \
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

## npm
# npm install
alias ni='npm install'
# npm run dev
alias nrd='npm run dev'
# npm run app
alias nra='npm run app'
# npm run build
alias nrb='npm run build'
# npm run lint
alias nrl='npm run lint'

## bun
# bun install
alias bi='bun install'
# bun run build
alias brb='bun run build'
# bun run lint
alias brl='bun run lint'
# bun run check
alias brc='bun run check'
# bun run test
alias brt='bun run test'
# bun run dev
alias brd='bun run dev'
# bun run db
alias brdb='bun run db'

## tt
# run TT dev script
alias ttdev='bun "$HOME/.config/tt/dev.ts"'
# run TT tests
alias tttest="DEV_DATA_PATH=.test DB_CONNECTION_STRING= DB_PROXY_CONNECTION_STRING= bun db && DEV_DATA_PATH=.test DB_CONNECTION_STRING= DB_PROXY_CONNECTION_STRING= bun test"
# cd to tt repo
alias tt='cd ~/d/tt/'
# cd to tt-trees
alias ttt='cd ~/d/tt-trees'
# cleanup local pg
alias cpg="~/d/tt/lab/db/setup-local-postgres.sh --cleanup"
# reset local pg
alias rpg="~/d/tt/lab/db/setup-local-postgres.sh --reset"

## git
# # git checkout
# alias kk='git checkout'
# # git status
# alias gs='git status'
# # git pull
# alias gp='git pull'
# # git push
# alias gpu='git push'
# # git commit -am
# alias gcm='git commit -am'
# # git branch
# alias gb='git branch'
# # delete git branch
# alias gbd='git branch -D'
# lazygit
alias lgit='lazygit'

## ssh
# add gitlab ssh key
alias add-gitlab-ssh-key='ssh-add --apple-use-keychain ~/.ssh/id_ed25519-m4-macbook-pro-08-2025-gitlab >/dev/null 2>&1'
# add github ssh key
alias add-github-ssh-key='ssh-add --apple-use-keychain ~/.ssh/id_ed25519-m4-macbook-pro-08-2025-github >/dev/null 2>&1'
# add universal ssh key
alias add-universal-ssh-key='ssh-add --apple-use-keychain ~/.ssh/id_ed25519_ssh_key >/dev/null 2>&1'
# add all ssh keys
function add-ssh-keys() {
  add-gitlab-ssh-key
  add-github-ssh-key
  add-universal-ssh-key
}

if command -v ssh-add >/dev/null 2>&1; then
  add-ssh-keys
fi

## pi
# keep pi awake
# alias cafpi='caffeinate -s -i -u pi'

# # run pi with skills
# pi() {
#   # Package-manager commands must receive untouched arguments.
#   case "${1-}" in
#     update|install|remove|uninstall|list|config)
#       command pi "$@"
#       return
#       ;;
#   esac

#   local global="$HOME/.agents/skills"
#   local repo_root
#   local args=(--no-skills)

#   repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"

#   for skill in tt-glab tt-jira-fst tt-kysely tt-remove-feature-flag; do
#     [[ -d "$global/$skill" ]] && args+=(--skill "$global/$skill")
#   done

#   if [[ -n "$repo_root" ]]; then
#     [[ -d "$repo_root/.pi/skills" ]] && args+=(--skill "$repo_root/.pi/skills")
#     [[ -d "$repo_root/.agents/skills" ]] && args+=(--skill "$repo_root/.agents/skills")
#   fi

#   # Load other global skills after the selected overrides.
#   args+=(--skill "$global")

#   command pi "${args[@]}" "$@"
# }

## claude
# keep claude awake
alias cc="caffeinate -s -i -u claude"
# run claude
alias c='claude'
# claude with chrome
alias ch='claude --chrome'
# claude remote control
alias cr='claude remote-control'
# cdash: dashboard of all active Claude sessions/background jobs/subagents
# under the current directory (reads ~/.claude/sessions + ~/.claude/jobs).
# Run in a second Warp pane/tab alongside your normal `c`/`claude` sessions.
# claude fleet dashboard
alias cdash='bash ~/.claude/scripts/fleet-dashboard.sh "$PWD" watch'

## nav
# cd to ~/d
alias d='cd ~/d'

## paths
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
