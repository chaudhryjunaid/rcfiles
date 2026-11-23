set nocompatible

" encoding must be set before scriptencoding.
set encoding=utf-8
scriptencoding utf-8

if has('termguicolors')
  set termguicolors
endif

" ==========================
" Plugins (vim-plug)
" ==========================
" Auto-install vim-plug on first launch, then install plugins.
let s:plug_path = expand('~/.vim/autoload/plug.vim')
if empty(glob(s:plug_path)) && executable('curl')
  silent execute '!curl -fLo ' . shellescape(s:plug_path) . ' --create-dirs '
        \ . 'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

if filereadable(s:plug_path)
  call plug#begin('~/.vim/plugged')
  Plug 'vim-airline/vim-airline'
  Plug 'vim-airline/vim-airline-themes'
  Plug 'tpope/vim-sleuth'                       " auto-detect indentation per file
  Plug 'tpope/vim-surround'                     " edit surrounding quotes/brackets/tags
  Plug 'tpope/vim-repeat'                       " make . repeat plugin maps (e.g. surround)
  Plug 'christoomey/vim-tmux-navigator'         " Ctrl-h/j/k/l across vim splits and tmux panes
  Plug 'junegunn/fzf'                           " fzf vim plugin base (commands/runtimepath)
  Plug 'junegunn/fzf.vim'                       " :Files, :Rg, :Buffers, :Lines, ...
  Plug 'reedes/vim-pencil'                      " prose-aware soft/hard wrap & motions
  Plug 'godlygeek/tabular'                       " align text / :TableFormat (vim-markdown dep)
  Plug 'preservim/vim-markdown'                 " rich Markdown: folding, :Toc, code fences
  Plug 'joshdick/onedark.vim'
  call plug#end()                               " also turns on filetype plugins/indent and syntax
else
  filetype plugin indent on
  syntax enable
endif

" Honor .editorconfig: built into Vim 9.0.1799+ (silent! on older Vims).
silent! packadd! editorconfig

" ==========================
" vim-airline status line
" ==========================
" Theme — swap for any in :AirlineTheme <Tab> (e.g. minimalist, tomorrow, dark)
let g:airline_theme = 'onedark'

" Use powerline/Nerd Font glyphs for separators and symbols
let g:airline_powerline_fonts = 1

" ==========================
" Prose & git commit messages
" ==========================
" vim-pencil: prose-aware motions and soft/hard wrap per file.
let g:pencil#wrapModeDefault = 'soft'
let g:pencil#textwidth = 72

" vim-markdown: show raw markup (no concealing), keep folds available but open.
let g:vim_markdown_conceal = 0
let g:vim_markdown_conceal_code_blocks = 0

augroup filetype_prose
  autocmd!
  " Commit messages: spell on, pencil hard-wraps the body at 72, 50/72 guides.
  " textwidth must be 0 before pencil#init so its hard mode sets 72 (else it
  " reverts to the global textwidth); colorcolumn is set after, as pencil
  " leaves it alone in hard mode.
  autocmd FileType gitcommit setlocal spell textwidth=0
  autocmd FileType gitcommit silent! call pencil#init({'wrap': 'hard', 'textwidth': 72})
  autocmd FileType gitcommit setlocal colorcolumn=51,73
  " Prose: spell on, pencil soft-wraps (no hard breaks, display-line motions).
  autocmd FileType text,markdown setlocal spell
  autocmd FileType text,markdown silent! call pencil#init({'wrap': 'soft'})
  autocmd FileType markdown setlocal foldlevel=99
augroup END

set wildignore+=*/tmp/*,*.so,*.swp,*.zip
" 400ms to finish a mapping (the jk/kj escapes below); 10ms for terminal
" key codes, so Alt/arrow sequences don't split over SSH.
set timeoutlen=400 ttimeoutlen=10

" Set leader key to space
let mapleader = " "
" Comment above and uncomment below if you want leader to be comma
"let mapleader = ","
"nnoremap ,, ,

" map jk and kj to escape
inoremap jk <Esc>
inoremap kj <Esc>

" Security
set modelines=0

" Show line numbers
set number
"set relativenumber

" Show file stats
set ruler

" No beep and no screen flash on errors.
set belloff=all

set cpoptions&vim


" Whitespace
set wrap
set textwidth=79
set formatoptions=crqnj
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
set wildmode=full

" Status bar
set laststatus=2

" Last line
set noshowmode " airline shows the current mode, so hide the default -- INSERT --
set showcmd

set cursorline
nnoremap <silent> <BS> :nohlsearch<CR>

" Searching
"nnoremap / /\v
"vnoremap / /\v
set hlsearch
set incsearch
set ignorecase
set smartcase

" Disable backup and swap files
"set backupdir=~/.vim/backups
"set directory=~/.vim/swaps

if !isdirectory(expand('~/.vim/undo'))
  call mkdir(expand('~/.vim/undo'), 'p')
endif
set undodir=~/.vim/undo

set undofile " Persistent Undo
set nobackup
set noswapfile

set autoread
augroup vimrc_checktime
  autocmd!
  autocmd FocusGained,BufEnter,CursorHold,CursorHoldI * checktime
augroup END

" Use the OS clipboard
if executable('wl-copy') && executable('wl-paste')
  let g:clipboard = {
        \ 'name': 'wl-clipboard',
        \ 'copy': {
        \   '+': 'wl-copy',
        \   '*': 'wl-copy',
        \ },
        \ 'paste': {
        \   '+': 'wl-paste --no-newline',
        \   '*': 'wl-paste --no-newline',
        \ },
        \ 'cache_enabled': 1,
        \ }
  set clipboard=unnamedplus
else
  set clipboard=unnamed
endif

" Show matching brackets/parenthesis
set showmatch

" Don't blink when matching
"set matchtime=0

"" Change cursor shape based on the mode vim is in (steady, not blinking,
"" like the terminals' cursor_blink settings).
" Insert mode - I-beam cursor
let &t_SI = "\e[6 q"
" Replace mode - Underline cursor
let &t_SR = "\e[4 q"
" Normal mode - Block cursor
let &t_EI = "\e[2 q"

" Folding
"set foldmethod=syntax
"set foldnestmax=10
"set nofoldenable
"set foldlevel=1

" Make macros render faster (lazy draw)
set lazyredraw

" autoindent
set autoindent
set signcolumn=yes
set list
set listchars=tab:>-,trail:.,nbsp:+
set colorcolumn=80,120
highlight ColorColumn ctermbg=236 guibg=#1f2430
set completeopt=menuone,noinsert,noselect
set updatetime=300

if executable('rg')
  set grepprg=rg\ --vimgrep\ --smart-case\ --hidden
  set grepformat=%f:%l:%c:%m
endif

"set background=dark
silent! colorscheme onedark  " silent!: don't error out if the scheme is missing

" Set the backspace key to behave more intuitively
set backspace=indent,eol,start
set scrolloff=3
set sidescrolloff=3 " Start scrolling three columns before vertical border of window


set splitbelow " New window goes below
set splitright " New windows goes right

set matchpairs+=<:> " use % to jump between pairs
silent! packadd! matchit " Vim 8+ ships matchit as a package (extends % to if/endif, tags, ...)

" Enable mouse support in all modes
set mouse=a

" Set the command line height to 2 lines for more display space
""set cmdheight=2

" Set the spellcheck language
set spelllang=en_us

set shortmess+=I

"map <leader><space> :let @/=''<cr> " clear search

" Remap help key.
"inoremap <F1> <ESC>:set invfullscreen<CR>a
"nnoremap <F1> :set invfullscreen<CR>
"vnoremap <F1> :set invfullscreen<CR>

" Formatting
"map <leader>q gqip

" Window navigation: Ctrl-h/j/k/l is mapped by vim-tmux-navigator, which also
" crosses into tmux panes.

function! s:OpenFzf() abort
  if exists(':FZF')
    FZF
  else
    echoerr 'FZF command is not available'
  endif
endfunction

nnoremap <silent> <C-p> :<C-u>call <SID>OpenFzf()<CR>
nnoremap <leader>co :copen<CR>
nnoremap <leader>cc :cclose<CR>
nnoremap <leader>cn :cnext<CR>
nnoremap <leader>cp :cprevious<CR>

" :W writes the file via sudo (useful for editing system files). A command,
" not a cnoremap, so typing a capital W elsewhere on the command line is safe.
command! W execute 'silent w !sudo tee % > /dev/null' | edit!

" Quick saving with Ctrl+S
nnoremap <C-s> :w<CR>
inoremap <C-s> <Esc>:w<CR>a
