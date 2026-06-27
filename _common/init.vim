" ============================================================
" Basic Neovim daily-driver config
" File: ~/.config/nvim/init.vim
" ============================================================

" ----------------------------
" General behavior
" ----------------------------

set nocompatible
set encoding=utf-8
set fileencoding=utf-8

set number
set relativenumber
set cursorline
set ruler
set showcmd
set showmode

set mouse=a
set clipboard=unnamedplus

set hidden
set confirm
set autoread
set updatetime=300
set timeoutlen=400

set splitbelow
set splitright

set scrolloff=5
set sidescrolloff=8

set signcolumn=yes

" ----------------------------
" Search
" ----------------------------

set ignorecase
set smartcase
set incsearch
set hlsearch

nnoremap <Esc><Esc> :nohlsearch<CR>

" ----------------------------
" Indentation
" ----------------------------

set autoindent
set smartindent
set expandtab
set tabstop=4
set shiftwidth=4
set softtabstop=4

" ----------------------------
" Wrapping / text files
" ----------------------------

set linebreak
set breakindent
set showbreak=↪\ 
set wrap

" ----------------------------
" Backups / undo / swap
" ----------------------------

set undofile
set undodir=~/.local/share/nvim/undo

set backup
set backupdir=~/.local/share/nvim/backup//

set directory=~/.local/share/nvim/swap//

" ----------------------------
" Completion
" ----------------------------

set wildmenu
set wildmode=longest:full,full
set completeopt=menuone,noinsert,noselect

" ----------------------------
" Visual appearance
" ----------------------------

syntax enable
filetype plugin indent on

set termguicolors
set background=dark

" Use built-in colorscheme.
" Other good built-ins: slate, desert, industry, habamax
colorscheme habamax

" ----------------------------
" Status line
" ----------------------------

set laststatus=2

set statusline=
set statusline+=%f
set statusline+=\ %m
set statusline+=%r
set statusline+=%h
set statusline+=%w
set statusline+=%=
set statusline+=%y
set statusline+=\ [%{&fileencoding}]
set statusline+=\ [%{&fileformat}]
set statusline+=\ %l:%c
set statusline+=\ %p%%

" ----------------------------
" Key mappings
" ----------------------------

let mapleader=" "

" Save / quit
nnoremap <leader>w :write<CR>
nnoremap <leader>q :quit<CR>
nnoremap <leader>x :xit<CR>

" Easier window movement
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Resize windows
nnoremap <A-h> :vertical resize -2<CR>
nnoremap <A-l> :vertical resize +2<CR>
nnoremap <A-j> :resize -2<CR>
nnoremap <A-k> :resize +2<CR>

" Buffers
nnoremap <leader>bn :bnext<CR>
nnoremap <leader>bp :bprevious<CR>
nnoremap <leader>bd :bdelete<CR>
nnoremap <leader>bl :buffers<CR>:buffer<Space>

" Better indenting in visual mode
vnoremap < <gv
vnoremap > >gv

" Move selected lines up/down
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv

" Keep cursor centered when jumping/searching
nnoremap n nzzzv
nnoremap N Nzzzv
nnoremap <C-d> <C-d>zz
nnoremap <C-u> <C-u>zz

" Paste without overwriting unnamed register
xnoremap <leader>p "_dP

" Yank to system clipboard
nnoremap <leader>y "+y
vnoremap <leader>y "+y
nnoremap <leader>Y "+Y

" Delete without yanking
nnoremap <leader>d "_d
vnoremap <leader>d "_d

" ----------------------------
" Terminal mode
" ----------------------------

tnoremap <Esc> <C-\><C-n>

" ----------------------------
" File-type specific settings
" ----------------------------

augroup filetype_settings
  autocmd!
  
  " Markdown / text writing
  autocmd FileType markdown,text,gitcommit setlocal spell spelllang=en_us
  autocmd FileType markdown,text,gitcommit setlocal wrap linebreak
  autocmd FileType markdown,text,gitcommit setlocal textwidth=80
  autocmd FileType markdown,text,gitcommit setlocal colorcolumn=80

  " Git commit messages
  autocmd FileType gitcommit setlocal spell textwidth=72 colorcolumn=72

  " YAML
  autocmd FileType yaml,yml setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab

  " JSON
  autocmd FileType json setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab

  " JavaScript / TypeScript
  autocmd FileType javascript,typescript,typescriptreact,javascriptreact setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab

  " HTML / CSS
  autocmd FileType html,css,scss setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab

  " Shell scripts
  autocmd FileType sh,bash,zsh setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab
augroup END

" ----------------------------
" Trailing whitespace
" ----------------------------

highlight ExtraWhitespace ctermbg=red guibg=red
match ExtraWhitespace /\s\+$/

nnoremap <leader>tw :%s/\s\+$//e<CR>

" ----------------------------
" Directories
" ----------------------------

if !isdirectory(expand('~/.local/share/nvim/undo'))
  call mkdir(expand('~/.local/share/nvim/undo'), 'p')
endif

if !isdirectory(expand('~/.local/share/nvim/backup'))
  call mkdir(expand('~/.local/share/nvim/backup'), 'p')
endif

if !isdirectory(expand('~/.local/share/nvim/swap'))
  call mkdir(expand('~/.local/share/nvim/swap'), 'p')
endif


