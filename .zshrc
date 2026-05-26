
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
alias bd='bun dev'
alias bb='bun build'
alias bl='bun lint'
alias bc='bun check'

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

# Alias to always use color with common flags
alias ls='ls -G'
alias ll='ls -alG'
