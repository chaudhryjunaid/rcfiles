" Don't try to be vi compatible
set nocompatible

" Baseline
scriptencoding utf-8
set encoding=utf-8
set fileencodings=utf-8
set termencoding=utf-8

set term=xterm-256color
"set t_Co=256   " This is may or may not needed.

" Helps force plugins to load correctly when it is turned back on below
filetype off

set wildignore+=*/tmp/*,*.so,*.swp,*.zip
set timeoutlen=1000 ttimeoutlen=0

" Set leader key to space
let mapleader = " "
" Comment above and uncomment below if you want leader to be comma
"let mapleader = ","
"nnoremap ,, ,

" map jk and kj to escape
imap jk <esc>
imap kj <esc>

" Security
set modelines=0

" Show line numbers
set number
set relativenumber

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

" Enable command completion
set wildmenu
set  wildmode=full

" Rendering
set ttyfast

" Status bar
set laststatus=2

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
"set backupdir=~/.vim/backups
"set directory=~/.vim/swaps

silent !mkdir -p ~/.vim/undo
set undodir=~/.vim/undo

set undofile " Persistent Undo


"set autoread
au FocusGained,CursorHold,CursorHoldI * checktime

" Use the OS clipboard
"set clipboard=unnamedplus

" Show matching brackets/parenthesis
set showmatch

" Don't blink when matching
"set matchtime=0

"" Change cursor shape based on the mode vim is in!
" Insert mode - I-beam cursor
let &t_SI = "\e[5 q"
" Replace mode - Underline cursor
let &t_SR = "\e[3 q"
" Normal mode - Block cursor
let &t_EI = "\e[1 q"

" Folding
"set foldmethod=syntax
"set foldnestmax=10
"set nofoldenable
"set foldlevel=1

" Make macros render faster (lazy draw)
set lazyredraw

" autoindent
set autoindent

"set background=dark
colorscheme sorbet

" Set the backspace key to behave more intuitively
set backspace=indent,eol,start
set scrolloff=3
set sidescrolloff=3 " Start scrolling three columns before vertical border of window


set splitbelow " New window goes below
set splitright " New windows goes right

set matchpairs+=<:> " use % to jump between pairs
runtime! macros/matchit.vim

" Enable mouse support in all modes
set mouse=v

" Set the command line height to 2 lines for more display space
""set cmdheight=2

" Set the spellcheck language
set  spelllang=en_us

set shortmess+=I

"map <leader><space> :let @/=''<cr> " clear search

" Remap help key.
"inoremap <F1> <ESC>:set invfullscreen<CR>a
"nnoremap <F1> :set invfullscreen<CR>
"vnoremap <F1> :set invfullscreen<CR>

" Formatting
"map <leader>q gqip

" Easy window navigation
map <C-h> <C-w>h
map <C-j> <C-w>j
map <C-k> <C-w>k
map <C-l> <C-w>l

map <C-p> :FZF<CR>

" Map ':W' as a sudo write command (useful for editing system files)
cnoremap W w !sudo tee % > /dev/null

" Quick saving with Ctrl+S
nnoremap <C-s> :w<CR>
inoremap <C-s> <Esc>:w<CR>a

set rtp+=/opt/homebrew/opt/fzf

" Turn on syntax highlighting
filetype plugin indent on
syntax on

syntax enable

