" Don't try to be vi compatible
set nocompatible

" Baseline
set encoding=utf-8
scriptencoding utf-8

set term=xterm-256color

" Helps force plugins to load correctly when it is turned back on below
filetype off

" Turn on syntax highlighting
filetype plugin indent on
syntax on

set t_Co=256   " This is may or may not needed.
set background=dark
set wildignore+=*/tmp/*,*.so,*.swp,*.zip
set timeoutlen=1000 ttimeoutlen=0

" TODO: Pick a leader key
"let mapleader = ","
"nnoremap ,, ,

" map jk and kj to escape
"imap jk <esc>
"imap kj <esc>

" Security
set modelines=0

" Show line numbers
set number

" Show file stats
set ruler

" Blink cursor on error instead of beeping (grr)
"set visualbell

set cpoptions+=$

" Whitespace
set wrap
set textwidth=79
set formatoptions=tcqrn1
set tabstop=2
set shiftwidth=2
set softtabstop=2
set expandtab
set noshiftround

" Move up/down editor lines
"nnoremap j gj
"nnoremap k gk

" Allow hidden buffers
set hidden

set wildmenu
" Rendering
set ttyfast

" Status bar
"set laststatus=2

" Last line
set showmode
set showcmd

set cursorline
nmap <silent> <BS> :nohlsearch<CR>

" Searching
"nnoremap / /\v
"vnoremap / /\v
set hlsearch
set incsearch
set ignorecase
set smartcase

" autosave files when vim loses focus
au FocusLost,WinLeave * :wa
au FocusGained,BufEnter * :silent! !

" Disable backup and swap files
set nobackup
set noswapfile

"set autoread
"au FocusGained,CursorHold,CursorHoldI * checktime

" Use the OS clipboard
"set clipboard=unnamed

" Show matching brackets/parenthesis
set showmatch

" Don't blink when matching
set matchtime=0

" Folding
"set foldmethod=syntax
"set foldnestmax=10
"set nofoldenable
"set foldlevel=1

" Make macros render faster (lazy draw)
set lazyredraw


" autoindent
set autoindent

"set shortmess+=I

"map <leader><space> :let @/=''<cr> " clear search

" Remap help key.
"inoremap <F1> <ESC>:set invfullscreen<CR>a
"nnoremap <F1> :set invfullscreen<CR>
"vnoremap <F1> :set invfullscreen<CR>

" Formatting
"map <leader>q gqip


" Easy window navigation
"map <C-h> <C-w>h
"map <C-j> <C-w>j
"map <C-k> <C-w>k
"map <C-l> <C-w>l

syntax enable

