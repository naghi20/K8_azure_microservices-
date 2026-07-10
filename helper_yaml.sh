#!/usr/bin/env bash
# setup-vim.sh -- bootstrap vim environment on a fresh system
# Supports: Debian/Ubuntu and RHEL 9 based (RHEL, Rocky, Alma, CentOS Stream 9)
# Installs: vim, git, ripgrep, fzf (git install), fzf.vim plugin, ~/.vimrc
set -euo pipefail

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

# ---------------------------------------------------------------- detect OS
if [ -f /etc/os-release ]; then
  . /etc/os-release
else
  echo "ERROR: cannot detect OS (/etc/os-release missing)" >&2
  exit 1
fi

install_pkgs() {
  case "$ID" in
    debian|ubuntu)
      sudo apt-get update -y
      sudo apt-get install -y vim git curl ripgrep
      ;;
    rhel|rocky|almalinux|centos|ol)
      # EPEL needed for ripgrep on RHEL 9 based systems
      if ! rpm -q epel-release &>/dev/null; then
        if [ "$ID" = "rhel" ]; then
          sudo dnf install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm" || true
        else
          sudo dnf install -y epel-release || true
        fi
      fi
      sudo dnf install -y vim-enhanced git curl
      if ! sudo dnf install -y ripgrep; then
        echo "WARN: ripgrep not available via dnf, installing static binary from GitHub"
        RG_VER="14.1.1"
        curl -fsSL -o /tmp/rg.tar.gz \
          "https://github.com/BurntSushi/ripgrep/releases/download/${RG_VER}/ripgrep-${RG_VER}-x86_64-unknown-linux-musl.tar.gz"
        tar -xzf /tmp/rg.tar.gz -C /tmp
        sudo install -m 0755 /tmp/ripgrep-${RG_VER}-x86_64-unknown-linux-musl/rg /usr/local/bin/rg
        rm -rf /tmp/rg.tar.gz /tmp/ripgrep-${RG_VER}-x86_64-unknown-linux-musl
      fi
      ;;
    *)
      echo "ERROR: unsupported distro: $ID" >&2
      exit 1
      ;;
  esac
}

install_fzf() {
  if [ ! -d "$TARGET_HOME/.fzf" ]; then
    git clone --depth 1 https://github.com/junegunn/fzf.git "$TARGET_HOME/.fzf"
    "$TARGET_HOME/.fzf/install" --key-bindings --completion --no-update-rc
  else
    echo "fzf already present at $TARGET_HOME/.fzf, skipping"
  fi
}

install_fzf_vim() {
  mkdir -p "$TARGET_HOME/.vim/bundle"
  if [ ! -d "$TARGET_HOME/.vim/bundle/fzf.vim" ]; then
    git clone --depth 1 https://github.com/junegunn/fzf.vim.git "$TARGET_HOME/.vim/bundle/fzf.vim"
  else
    echo "fzf.vim already present, skipping"
  fi
}

write_vimrc() {
  if [ -f "$TARGET_HOME/.vimrc" ]; then
    cp "$TARGET_HOME/.vimrc" "$TARGET_HOME/.vimrc.bak.$(date +%Y%m%d%H%M%S)"
    echo "existing .vimrc backed up"
  fi
  cat > "$TARGET_HOME/.vimrc" << 'VIMRC'
syntax on
colorscheme slate
hi SpellBad term=reverse ctermbg=red
set number relativenumber
set cursorline
set showcmd   "shows current command in the statusline
set exrc      "read <cwd>/.vimrc
set ttyfast   "more characters will be sent to the screen for redrawing
set wildmenu  "a better menu in command mode
set wildmode=longest:full,full
set colorcolumn=81
highlight ColorColumn ctermbg=235 guibg=#2c2d27
set hlsearch  "highlights search results
set ignorecase smartcase
set shortmess-=S
hi Search ctermbg=DarkGray
hi Search ctermfg=Red
hi QuickFixLine term=reverse ctermbg=52  "change QuickFix selected line color
set laststatus=2
set statusline=%f\:%l\:%c\ \[%L\]
set tabstop=2
set shiftwidth=2
set softtabstop=2
set expandtab
filetype plugin indent on
set runtimepath^=~/.fzf
set runtimepath^=~/.vim/bundle/fzf.vim
set grepprg=rg\ --vimgrep\ --smart-case\ --follow
nnoremap <silent> <C-f> :Files<CR>
nnoremap <silent> <Leader>f :Rg<CR>
map <C-n> :cnext<CR>
map <C-m> :cprevious<CR>
cnoremap <C-a> <Home>
cnoremap <C-e> <End>
cnoremap <C-p> <Up>
cnoremap <C-n> <Down>
cnoremap <C-b> <Left>
cnoremap <C-f> <Right>
VIMRC
}

fix_ownership() {
  if [ "$TARGET_USER" != "root" ]; then
    sudo chown -R "$TARGET_USER":"$TARGET_USER" \
      "$TARGET_HOME/.vimrc" "$TARGET_HOME/.fzf" "$TARGET_HOME/.vim" 2>/dev/null || true
  fi
}

echo "== Installing packages ($ID) =="
install_pkgs
echo "== Installing fzf =="
install_fzf
echo "== Installing fzf.vim =="
install_fzf_vim
echo "== Writing ~/.vimrc =="
write_vimrc
fix_ownership
echo "== Done. Open vim and test :Files (Ctrl-f) and :Rg (\\f) =="
