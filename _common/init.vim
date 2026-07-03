" ============================================================
" Neovim daily terminal driver init.vim
" ============================================================

" ------------------------------------------------------------
" vim-plug bootstrap
" ------------------------------------------------------------
if empty(glob('~/.local/share/nvim/site/autoload/plug.vim'))
  silent !curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs
        \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" ------------------------------------------------------------
" Plugins
" ------------------------------------------------------------
call plug#begin('~/.local/share/nvim/plugged')

" Theme
Plug 'sainnhe/gruvbox-material'
"Plug 'navarasu/onedark.nvim'
Plug 'morhetz/gruvbox'
Plug 'joshdick/onedark.vim'
Plug 'tomasr/molokai'
Plug 'dracula/vim'
Plug 'sainnhe/everforest'

" Statusline
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" Fuzzy finding
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" Git
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'

" Editing improvements
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-surround'
Plug 'jiangmiao/auto-pairs'
Plug 'windwp/nvim-autopairs'

" File navigation
Plug 'preservim/nerdtree'

" Better syntax / structure
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}

" Useful UI helpers
Plug 'Yggdroot/indentLine'
Plug 'machakann/vim-highlightedyank'

" Terminal integration
Plug 'voldikss/vim-floaterm'

call plug#end()

" ------------------------------------------------------------
" Core behavior
" ------------------------------------------------------------
set nocompatible
set cpoptions&vim
filetype plugin indent on
syntax enable

set hidden
set autoread
set confirm
set history=1000
set undofile
set undodir=~/.local/share/nvim/undo
set updatetime=300
set timeoutlen=500
set ttimeoutlen=10

" ------------------------------------------------------------
" UI
" ------------------------------------------------------------
set termguicolors
set background=dark
colorscheme onedark

set number
set relativenumber
set ruler
set laststatus=2
set showcmd
set noshowmode
set cursorline
set signcolumn=yes
set scrolloff=5
set sidescrolloff=8
set colorcolumn=+1
set pumheight=12
set cmdheight=1

" Make colorcolumn subtle
highlight ColorColumn guibg=#222222 ctermbg=236

augroup user_colors
  autocmd!
  autocmd ColorScheme * highlight ColorColumn guibg=#222222 ctermbg=236
augroup END

" ------------------------------------------------------------
" Search
" ------------------------------------------------------------
set ignorecase
set smartcase
set incsearch
set hlsearch

" Clear search highlight with Esc
nnoremap <silent> <Esc> :nohlsearch<CR><Esc>

" ------------------------------------------------------------
" Indentation
" ------------------------------------------------------------
set autoindent
set smartindent
set expandtab
set tabstop=2
set shiftwidth=2
set softtabstop=2
set shiftround

" ------------------------------------------------------------
" Editing
" ------------------------------------------------------------
set backspace=indent,eol,start
set mouse=a
set clipboard=unnamedplus
set splitbelow
set splitright
set virtualedit=block
set formatoptions=crqnj

" ------------------------------------------------------------
" Completion behavior
" ------------------------------------------------------------
set completeopt=menuone,noinsert,noselect

" ------------------------------------------------------------
" Wildmenu / command-line completion
" ------------------------------------------------------------
set wildmenu
set wildmode=longest:full,full
set wildignore+=*.o,*.obj,*.pyc,*.class
set wildignore+=*/node_modules/*,*/.git/*,*/dist/*,*/build/*
set wildignore+=*/target/*,*/.next/*,*/coverage/*

" ------------------------------------------------------------
" Folding
" ------------------------------------------------------------
set foldmethod=indent
set foldlevelstart=99

" ------------------------------------------------------------
" Leader key
" ------------------------------------------------------------
let mapleader=" "
let maplocalleader=" "

" ------------------------------------------------------------
" Basic mappings
" ------------------------------------------------------------

" Save / quit
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>Q :qa<CR>

" Better window navigation
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Resize splits
nnoremap <A-h> :vertical resize -3<CR>
nnoremap <A-l> :vertical resize +3<CR>
nnoremap <A-j> :resize -3<CR>
nnoremap <A-k> :resize +3<CR>

" Buffer navigation
nnoremap <leader>bn :bnext<CR>
nnoremap <leader>bp :bprevious<CR>
nnoremap <leader>bd :bdelete<CR>
nnoremap <leader>bl :buffers<CR>

" Keep visual selection when indenting
vnoremap < <gv
vnoremap > >gv

" Move selected lines up/down
xnoremap J :move '>+1<CR>gv=gv
xnoremap K :move '<-2<CR>gv=gv

" Better paste over selection without overwriting unnamed register
xnoremap <leader>p "_dP

" Yank to system clipboard
nnoremap <leader>y "+y
vnoremap <leader>y "+y
nnoremap <leader>Y "+Y

" Delete without yanking
nnoremap <leader>d "_d
vnoremap <leader>d "_d

" ------------------------------------------------------------
" FZF mappings
" ------------------------------------------------------------
nnoremap <leader>ff :Files<CR>
nnoremap <leader>fg :GFiles<CR>
nnoremap <leader>fb :Buffers<CR>
nnoremap <leader>fr :Rg<CR>
nnoremap <leader>fh :History<CR>
nnoremap <leader>fc :Commands<CR>
nnoremap <leader>fm :Marks<CR>

" FZF layout
let g:fzf_layout = { 'down': '40%' }

" Use ripgrep if available
if executable('rg')
  let $FZF_DEFAULT_COMMAND = 'rg --files --hidden --glob "!.git/*"'
endif

" ------------------------------------------------------------
" NERDTree
" ------------------------------------------------------------
nnoremap <leader>e :NERDTreeToggle<CR>
nnoremap <leader>E :NERDTreeFind<CR>

let NERDTreeShowHidden=1
let NERDTreeMinimalUI=1
let NERDTreeIgnore=[
      \ '\.git$',
      \ 'node_modules$',
      \ 'dist$',
      \ 'build$',
      \ '.next$'
      \ ]

" ------------------------------------------------------------
" Git
" ------------------------------------------------------------
nnoremap <leader>gs :Git<CR>
nnoremap <leader>gd :Gdiffsplit<CR>
nnoremap <leader>gb :Git blame<CR>
nnoremap <leader>gc :Git commit<CR>
nnoremap <leader>gp :Git push<CR>
nnoremap <leader>gl :Git log<CR>

let g:gitgutter_enabled = 1
let g:gitgutter_map_keys = 0

nnoremap ]c :GitGutterNextHunk<CR>
nnoremap [c :GitGutterPrevHunk<CR>
nnoremap <leader>hs :GitGutterStageHunk<CR>
nnoremap <leader>hu :GitGutterUndoHunk<CR>
nnoremap <leader>hp :GitGutterPreviewHunk<CR>

" ------------------------------------------------------------
" Airline: dashboard-style statusline
" ------------------------------------------------------------
set laststatus=2
set showtabline=2
set noshowmode

let g:airline_powerline_fonts = 1
let g:airline_theme = 'onedark'

" Top tab/buffer line
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#formatter = 'unique_tail'
let g:airline#extensions#tabline#show_buffers = 1
let g:airline#extensions#tabline#show_tabs = 1
let g:airline#extensions#tabline#show_tab_type = 1
let g:airline#extensions#tabline#buffer_idx_mode = 1

" Git branch and hunks
let g:airline#extensions#branch#enabled = 1
let g:airline#extensions#hunks#enabled = 1
let g:airline#extensions#fugitiveline#enabled = 1

" File info
let g:airline#extensions#readonly#enabled = 1
let g:airline#extensions#wordcount#enabled = 1

" Cleaner symbols
let g:airline_symbols = {}

let g:airline_left_sep = ''
let g:airline_left_alt_sep = ''
let g:airline_right_sep = ''
let g:airline_right_alt_sep = ''

let g:airline_symbols.branch = ''
let g:airline_symbols.readonly = ''
let g:airline_symbols.linenr = ''
let g:airline_symbols.maxlinenr = ''
let g:airline_symbols.dirty = '●'
let g:airline_symbols.notexists = '∄'
let g:airline_symbols.whitespace = 'Ξ'

" ------------------------------------------------------------
" indentLine
" ------------------------------------------------------------
let g:indentLine_enabled = 1
let g:indentLine_char = '│'
let g:indentLine_fileTypeExclude = ['help', 'nerdtree', 'terminal']

" ------------------------------------------------------------
" Floaterm
" ------------------------------------------------------------
let g:floaterm_width = 0.9
let g:floaterm_height = 0.85
let g:floaterm_position = 'center'
let g:floaterm_keymap_toggle = '<F12>'

nnoremap <leader>tt :FloatermToggle<CR>
tnoremap <Esc> <C-\><C-n>
tnoremap <C-h> <C-\><C-n><C-w>h
tnoremap <C-j> <C-\><C-n><C-w>j
tnoremap <C-k> <C-\><C-n><C-w>k
tnoremap <C-l> <C-\><C-n><C-w>l

" ------------------------------------------------------------
" Filetype-specific settings
" ------------------------------------------------------------
augroup user_filetypes
  autocmd!
  autocmd FileType markdown,text,gitcommit setlocal textwidth=80 colorcolumn=80,100 formatoptions=tcqrn1
  autocmd FileType javascript,typescript,json,html,css,yaml setlocal shiftwidth=2 tabstop=2 softtabstop=2
  autocmd FileType lua setlocal shiftwidth=2 tabstop=2 softtabstop=2
  autocmd FileType python setlocal shiftwidth=4 tabstop=4 softtabstop=4
  autocmd FileType help setlocal number norelativenumber
  autocmd TermOpen * setlocal nonumber norelativenumber signcolumn=no
augroup END
" ------------------------------------------------------------
" Treesitter config
" ------------------------------------------------------------
lua << EOF
local ok, treesitter = pcall(require, "nvim-treesitter.configs")

if ok then
  treesitter.setup {
    ensure_installed = {
      "bash",
      "c",
      "cpp",
      "css",
      "dockerfile",
      "go",
      "html",
      "javascript",
      "json",
      "lua",
      "markdown",
      "markdown_inline",
      "python",
      "regex",
      "tsx",
      "typescript",
      "vim",
      "vimdoc",
      "yaml"
    },

    highlight = {
      enable = true,
      additional_vim_regex_highlighting = false,
    },

    indent = {
      enable = true,
    },
  }
end
EOF

" ------------------------------------------------------------
" nvim-autopairs config
" ------------------------------------------------------------
lua << EOF
pcall(function()
  require("nvim-autopairs").setup {}
end)
EOF

" ------------------------------------------------------------
" Quality-of-life commands
" ------------------------------------------------------------

" Reload config
nnoremap <leader>sv :source $MYVIMRC<CR>

" Edit config
nnoremap <leader>ev :edit $MYVIMRC<CR>

" Toggle relative number
nnoremap <leader>rn :set relativenumber!<CR>

" Toggle paste mode, useful for terminal paste issues
nnoremap <leader>pp :set paste!<CR>

" Toggle spellcheck
nnoremap <leader>sp :setlocal spell! spelllang=en_us<CR>

" Strip trailing whitespace
nnoremap <leader>tw :%s/\s\+$//e<CR>

" ------------------------------------------------------------
" Startup
" ------------------------------------------------------------
set shortmess+=c


" ----------------------------
" Wrapping / text files
" ----------------------------

set linebreak
set breakindent
set showbreak=↪\ 
set wrap

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

" ------------------------------------------------------------
" Files, backup, swap
" ------------------------------------------------------------
"set nobackup
"set nowritebackup
set noswapfile
set backupdir='~/.local/share/nvim/backup'
set undodir='~/.local/share/nvim/undo'

