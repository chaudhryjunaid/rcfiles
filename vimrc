" ---- General ----
set nocompatible              " Use Vim defaults, not vi
set encoding=utf-8
set hidden                    " Allow switching buffers without saving
set history=1000
set undofile                  " Persistent undo across sessions
set undodir=~/.vim/undo//
set backupdir=~/.vim/backup//
set directory=~/.vim/swap//
set autoread                  " Reload files changed outside vim
set mouse=a                   " Enable mouse in all modes

" ---- UI ----
set number                    " Line numbers
set relativenumber            " Relative line numbers (great for motions)
set ruler                     " Show cursor position
set showcmd                   " Show partial commands
set showmatch                 " Highlight matching brackets
set laststatus=2              " Always show status line
set wildmenu                  " Better command-line completion
set wildmode=longest:full,full
set scrolloff=8               " Keep 8 lines of context above/below cursor
set sidescrolloff=8
set signcolumn=yes            " Always show sign column (no jitter)
set cursorline                " Highlight current line
set termguicolors             " True color support
set background=dark
syntax on
filetype plugin indent on
colorscheme catppuccin

" ---- Search ----
set ignorecase                " Case-insensitive search...
set smartcase                 " ...unless you type a capital letter
set incsearch                 " Show matches as you type
set hlsearch                  " Highlight all matches

" ---- Indentation ----
set expandtab                 " Spaces, not tabs
set tabstop=4
set shiftwidth=4
set softtabstop=4
set autoindent
set smartindent

" ---- Splits ----
set splitright                " Vertical splits open to the right
set splitbelow                " Horizontal splits open below

" ---- Performance / behavior ----
set updatetime=300
set timeoutlen=500
set ttimeoutlen=10            " Faster escape from insert mode
set lazyredraw                " Don't redraw during macros
set backspace=indent,eol,start

" ---- Disable focus event garbage in some terminals ----
let &t_fe = ""
let &t_fd = ""

" ---- Keymaps ----
let mapleader = " "

" Clear search highlight
nnoremap <silent> <leader>h :nohlsearch<CR>

" Quick save / quit
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>

" Move between splits with Ctrl-h/j/k/l
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Keep selection after indenting in visual mode
vnoremap < <gv
vnoremap > >gv

" Center cursor when jumping
nnoremap n nzz
nnoremap N Nzz
nnoremap <C-d> <C-d>zz
nnoremap <C-u> <C-u>zz

" ---- Filetype tweaks ----
augroup filetype_settings
  autocmd!
  autocmd FileType yaml,json,html,css,javascript,typescript setlocal ts=2 sw=2 sts=2
  autocmd FileType make setlocal noexpandtab
  autocmd BufWritePre * :%s/\s\+$//e   " Strip trailing whitespace on save
augroup END

