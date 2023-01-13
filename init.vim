set nocompatible " disable compatibility to old-time vi
set showmatch " show matching 
set ignorecase " case insensitive 
set hlsearch " highlight search 
set incsearch " incremental search
set smartcase
set autoindent " indent a new line the same amount as the line just typed
set relativenumber " add line numbers
set hidden
set wildmode=longest,list " get bash-like tab completions
set mouse=a " enable mouse click
set clipboard=unnamedplus " using system clipboard
set cursorline " highlight current cursorline
set ttyfast " Speed up scrolling in Vim

" Baseline
set encoding=utf-8
scriptencoding utf-8

"set term=xterm-256color

" Helps force plugins to load correctly when it is turned back on below
filetype off

" Turn on syntax highlighting
filetype plugin indent on
syntax on

" color schemes
if (has("termguicolors"))
  set termguicolors
endif

colorscheme slate

syntax enable

" open new split panes to right and below
set splitright
set splitbelow

set wildignore+=*/tmp/*,*.so,*.swp,*.zip
set timeoutlen=1000 ttimeoutlen=0

" Show file stats
set ruler

" Blink cursor on error instead of beeping (grr)
set visualbell

set cpoptions+=$

"Whitespace
set wrap
set textwidth=79
set formatoptions=tcqrn1
"set tabstop=2
"set shiftwidth=2
"set softtabstop=2
"set expandtab
set noshiftround

" Status bar
set laststatus=2

" Last line
set showmode
set showcmd

" autosave files when vim loses focus
au FocusLost,WinLeave * :wa
au FocusGained,BufEnter * :silent! !

" Disable backup and swap files
set nobackup
set noswapfile
set nowritebackup

" Having longer updatetime (default is 4000 ms = 4 s) leads to noticeable
" delays and poor user experience.
set updatetime=300

" Don't pass messages to |ins-completion-menu|.
set shortmess+=c

" Always show the signcolumn, otherwise it would shift the text each time
" diagnostics appear/become resolved.
if has("nvim-0.5.0") || has("patch-8.1.1564")
  " Recently vim can merge signcolumn and number column into one
  set signcolumn=number
else
  set signcolumn=yes
endif

"set autoread
au FocusGained,CursorHold,CursorHoldI * checktime

" Don't blink when matching
set matchtime=0

" Folding
"set foldmethod=syntax
"set foldnestmax=10
"set nofoldenable
"set foldlevel=1

" Make macros render faster (lazy draw)
set lazyredraw

syntax enable

