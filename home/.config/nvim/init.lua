-- ============================================================
-- Neovim daily terminal driver init.lua
-- ============================================================

-- Byte-compile and cache Lua modules: faster startup.
vim.loader.enable()

local map = vim.keymap.set

-- ------------------------------------------------------------
-- Leader key: set before any <leader> mapping (and before lazy.nvim, whose
-- `keys` specs read it when defined).
-- ------------------------------------------------------------
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- ------------------------------------------------------------
-- Core behavior (hidden, autoread, history=10000, laststatus=2, filetype
-- plugin indent on, syntax on, ... are already Neovim defaults)
-- ------------------------------------------------------------
vim.cmd("set cpoptions&vim")

vim.o.confirm = true
-- Undo files go to the default ~/.local/state/nvim/undo/.
vim.o.undofile = true
vim.o.updatetime = 300
vim.o.timeoutlen = 500
vim.o.ttimeoutlen = 10
vim.o.swapfile = false

-- ------------------------------------------------------------
-- UI
-- ------------------------------------------------------------
vim.o.termguicolors = true
vim.o.background = "dark"

vim.o.number = true
vim.o.relativenumber = true
vim.o.showcmd = true
vim.o.showmode = false -- lualine shows the mode
vim.o.cursorline = true
vim.o.signcolumn = "yes"
vim.o.scrolloff = 5
vim.o.sidescrolloff = 8
vim.o.colorcolumn = "+1"
vim.o.pumheight = 12
vim.o.showtabline = 2 -- lualine's buffer line
vim.opt.shortmess:append("c")

-- Wrapping / text files
vim.o.linebreak = true
vim.o.breakindent = true
vim.o.showbreak = "↪ "
vim.o.wrap = true

-- ------------------------------------------------------------
-- Search
-- ------------------------------------------------------------
vim.o.ignorecase = true
vim.o.smartcase = true
-- Preview :s results live, with off-screen matches in a split.
vim.o.inccommand = "split"

-- ------------------------------------------------------------
-- Indentation
-- ------------------------------------------------------------
vim.o.expandtab = true
vim.o.tabstop = 2
vim.o.shiftwidth = 2
vim.o.softtabstop = 2
vim.o.shiftround = true
vim.o.spelllang = "en_us"

-- ------------------------------------------------------------
-- Editing
-- ------------------------------------------------------------
vim.o.mouse = "a"
-- Set after startup: finding the clipboard tool would otherwise slow it.
vim.schedule(function() vim.o.clipboard = "unnamedplus" end)
vim.o.splitbelow = true
vim.o.splitright = true
vim.o.virtualedit = "block"
vim.o.formatoptions = "crqnj"
vim.o.completeopt = "menuone,noinsert,noselect"

-- Wildmenu / command-line completion
vim.o.wildmode = "longest:full,full"
vim.opt.wildignore:append({
  "*.o", "*.obj", "*.pyc", "*.class",
  "*/node_modules/*", "*/.git/*", "*/dist/*", "*/build/*",
  "*/target/*", "*/.next/*", "*/coverage/*",
})

-- Treesitter folds (no folds in buffers without a parser); all open at start.
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.o.foldlevelstart = 99

-- ------------------------------------------------------------
-- Highlights and autocmds (defined before the colorscheme loads, so its
-- ColorScheme event applies them)
-- ------------------------------------------------------------
local augroup = function(name) return vim.api.nvim_create_augroup(name, { clear = true }) end
local autocmd = vim.api.nvim_create_autocmd

-- Subtle colorcolumn; red trailing whitespace.
local function user_highlights()
  vim.api.nvim_set_hl(0, "ColorColumn", { bg = "#222222", ctermbg = 236 })
  vim.api.nvim_set_hl(0, "ExtraWhitespace", { bg = "red", ctermbg = "red" })
end
autocmd("ColorScheme", { group = augroup("user_colors"), callback = user_highlights })

-- :match is per window, so set it in every window showing a normal file
-- (not terminals or plugin panes).
autocmd({ "BufWinEnter", "WinEnter", "TermOpen" }, {
  group = augroup("user_extra_whitespace"),
  callback = function()
    if vim.bo.buftype == "" then
      vim.cmd([[match ExtraWhitespace /\s\+$/]])
    else
      vim.cmd("match none")
    end
  end,
})

-- Indent guides, built in: 'list' draws a │ at every indent level of the
-- leading spaces (and tabs), sized to the buffer's shiftwidth. Only in
-- normal file buffers; terminals, help and plugin panes stay clean. Blank
-- lines get no guide (unlike indent-blankline).
local function update_indent_guides()
  -- netrw sets its buftype only after BufWinEnter, so check it by filetype.
  if vim.bo.buftype ~= "" or vim.bo.filetype == "netrw" then
    vim.opt_local.list = false
    return
  end
  local sw = vim.fn.shiftwidth()
  vim.opt_local.list = true
  vim.opt_local.listchars = {
    tab = "│ ",
    nbsp = "␣",
    leadmultispace = "│" .. (" "):rep(math.max(sw - 1, 0)),
  }
end
autocmd({ "BufWinEnter", "FileType" }, { group = augroup("user_indent_guides"), callback = update_indent_guides })
autocmd("OptionSet", {
  group = augroup("user_indent_guides_opt"),
  pattern = { "shiftwidth", "tabstop" },
  callback = update_indent_guides,
})

autocmd("TextYankPost", {
  group = augroup("user_yank"),
  callback = function() vim.hl.on_yank({ timeout = 300 }) end,
})

-- Pick up edits made outside nvim (Claude Code, git): 'autoread' reloads
-- unmodified buffers, but Neovim only checks on focus; also check on
-- entering a buffer and when the cursor rests, and say when it happened.
autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
  group = augroup("user_checktime"),
  callback = function()
    if vim.fn.mode() ~= "c" and vim.fn.getcmdwintype() == "" then vim.cmd("checktime") end
  end,
})
autocmd("FileChangedShellPost", {
  group = augroup("user_reloaded"),
  callback = function(args)
    vim.notify(vim.fn.fnamemodify(args.file, ":~:.") .. " changed on disk; reloaded", vim.log.levels.INFO)
  end,
})

-- Reopen a file at the last cursor position (not for commit messages and
-- rebase lists, which are new each time).
autocmd("BufReadPost", {
  group = augroup("user_last_position"),
  callback = function(args)
    if vim.tbl_contains({ "gitcommit", "gitrebase" }, vim.bo[args.buf].filetype) then return end
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(args.buf) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

local ft = augroup("user_filetypes")
local function ft_local(pattern, opts)
  autocmd("FileType", {
    group = ft,
    pattern = pattern,
    callback = function()
      for k, v in pairs(opts) do vim.opt_local[k] = v end
    end,
  })
end
ft_local({ "markdown", "text" },
  { textwidth = 80, colorcolumn = "80,100", formatoptions = "tcqrn1", spell = true })
-- Commit messages: body wrapped at 72, guides at 50 (subject) and 72.
ft_local("gitcommit",
  { textwidth = 72, colorcolumn = "51,73", formatoptions = "tcqrn1", spell = true })
-- Prose: j/k move by screen line through long wrapped lines (5j still
-- counts real lines).
autocmd("FileType", {
  group = ft,
  pattern = { "markdown", "text" },
  callback = function(args)
    for _, key in ipairs({ "j", "k" }) do
      map({ "n", "x" }, key, function() return vim.v.count == 0 and "g" .. key or key end,
        { buffer = args.buf, expr = true, desc = "Move by screen line" })
    end
  end,
})
ft_local({ "javascript", "typescript", "json", "html", "css", "yaml" },
  { shiftwidth = 2, tabstop = 2, softtabstop = 2 })
ft_local("lua", { shiftwidth = 2, tabstop = 2, softtabstop = 2 })
ft_local("python", { shiftwidth = 4, tabstop = 4, softtabstop = 4 })
ft_local("help", { number = true, relativenumber = false })
autocmd("TermOpen", {
  group = ft,
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
    vim.opt_local.list = false
  end,
})

-- ------------------------------------------------------------
-- LSP (servers come from mason; see the plugin specs below)
-- ------------------------------------------------------------
-- Neovim 0.11 default maps: grn rename, gra code action, grr references,
-- gri implementation, gO symbols, K hover, [d/]d diagnostics, <C-s> signature.

-- Know about the `vim` global when editing Neovim config.
vim.lsp.config("lua_ls", {
  settings = { Lua = { diagnostics = { globals = { "vim" } } } },
})

vim.diagnostic.config({
  virtual_text = true,
  severity_sort = true,
  float = { border = "rounded", source = true },
})

autocmd("LspAttach", {
  group = augroup("user_lsp"),
  callback = function(args)
    local bmap = function(lhs, rhs, desc)
      map("n", lhs, rhs, { buffer = args.buf, desc = desc })
    end
    bmap("gd", vim.lsp.buf.definition, "Go to definition")
    bmap("gD", vim.lsp.buf.declaration, "Go to declaration")
    bmap("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
    bmap("<leader>ca", vim.lsp.buf.code_action, "Code action")
    bmap("<leader>lf", function() vim.lsp.buf.format({ async = true }) end, "Format buffer")
    bmap("<leader>ld", vim.diagnostic.open_float, "Line diagnostics")
  end,
})

-- ------------------------------------------------------------
-- Mappings
-- ------------------------------------------------------------
-- Clear search highlight with Esc
map("n", "<Esc>", ":nohlsearch<CR><Esc>", { silent = true })

-- Save / quit
map("n", "<leader>w", ":w<CR>", { desc = "Save" })
map("n", "<leader>q", ":q<CR>", { desc = "Quit window" })
map("n", "<leader>Q", ":qa<CR>", { desc = "Quit all" })

-- Window navigation: Ctrl-h/j/k/l is mapped by vim-tmux-navigator, which also
-- crosses into tmux panes.

-- Resize splits
map("n", "<A-h>", ":vertical resize -3<CR>")
map("n", "<A-l>", ":vertical resize +3<CR>")
map("n", "<A-j>", ":resize -3<CR>")
map("n", "<A-k>", ":resize +3<CR>")

-- Buffer navigation
map("n", "<leader>bn", ":bnext<CR>", { desc = "Next buffer" })
map("n", "<leader>bp", ":bprevious<CR>", { desc = "Previous buffer" })
map("n", "<leader>bd", ":bdelete<CR>", { desc = "Delete buffer" })
map("n", "<leader>bl", ":buffers<CR>", { desc = "List buffers" })

-- Keep visual selection when indenting
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Move selected lines up/down
map("x", "J", ":move '>+1<CR>gv=gv")
map("x", "K", ":move '<-2<CR>gv=gv")

-- Better paste over selection without overwriting unnamed register
map("x", "<leader>p", [["_dP]], { desc = "Paste, keep register" })

-- Yank to system clipboard
map({ "n", "v" }, "<leader>y", [["+y]], { desc = "Yank to clipboard" })
map("n", "<leader>Y", [["+Y]], { desc = "Yank line to clipboard" })

-- Delete without yanking
map({ "n", "v" }, "<leader>d", [["_d]], { desc = "Delete, no yank" })

-- FZF ($FZF_DEFAULT_COMMAND comes from ~/.shellrc.sh)
map("n", "<leader>ff", ":Files<CR>", { desc = "Files" })
map("n", "<leader>fg", ":GFiles<CR>", { desc = "Git files" })
map("n", "<leader>fb", ":Buffers<CR>", { desc = "Buffers" })
map("n", "<leader>fr", ":Rg<CR>", { desc = "Ripgrep text" })
map("n", "<leader>fh", ":History<CR>", { desc = "Recent files" })
map("n", "<leader>fc", ":Commands<CR>", { desc = "Commands" })
map("n", "<leader>fm", ":Marks<CR>", { desc = "Marks" })
vim.g.fzf_layout = { down = "40%" }

-- File tree: netrw (built in) in a left split. <leader>e toggles it at the
-- working directory, <leader>E opens it at the current file's directory.
vim.g.netrw_banner = 0
vim.g.netrw_liststyle = 3 -- tree view
vim.g.netrw_winsize = 25 -- percent of the width
vim.g.netrw_list_hide = [[^\.git/$,^node_modules/$,^dist/$,^build/$,^\.next/$]]
map("n", "<leader>e", ":Lexplore<CR>", { silent = true, desc = "Toggle file tree" })
map("n", "<leader>E", ":Lexplore %:p:h<CR>", { silent = true, desc = "File tree at this file" })

-- Git (fugitive; gitsigns' hunk maps are in its spec)
map("n", "<leader>gs", ":Git<CR>", { desc = "Git status (fugitive)" })
map("n", "<leader>gd", ":Gdiffsplit<CR>", { desc = "Diff this file" })
map("n", "<leader>gb", ":Git blame<CR>", { desc = "Blame" })
map("n", "<leader>gc", ":Git commit<CR>", { desc = "Commit" })
map("n", "<leader>gp", ":Git push<CR>", { desc = "Push" })
map("n", "<leader>gl", ":Git log<CR>", { desc = "Log" })

-- Terminal: double Esc leaves terminal mode; a single Esc still reaches TUIs
-- running in the terminal (fzf, htop, nested vim, other TUIs).
map("t", "<Esc><Esc>", [[<C-\><C-n>]])
map("t", "<C-h>", [[<C-\><C-n><C-w>h]])
map("t", "<C-j>", [[<C-\><C-n><C-w>j]])
map("t", "<C-k>", [[<C-\><C-n><C-w>k]])
map("t", "<C-l>", [[<C-\><C-n><C-w>l]])

-- Floating terminal on F12 / <leader>tt (from normal or terminal mode). One
-- shell, hidden and shown again by each toggle; when it exits, the next
-- toggle starts a new one.
local float_term = { buf = -1, win = -1 }
local function toggle_float_term()
  if vim.api.nvim_win_is_valid(float_term.win) then
    vim.api.nvim_win_hide(float_term.win)
    return
  end
  local new = not vim.api.nvim_buf_is_valid(float_term.buf)
  if new then float_term.buf = vim.api.nvim_create_buf(false, true) end
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.85)
  float_term.win = vim.api.nvim_open_win(float_term.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
  })
  if new then
    local buf = float_term.buf
    vim.fn.jobstart(vim.o.shell, {
      term = true,
      on_exit = function()
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
        end)
      end,
    })
  end
  vim.cmd.startinsert()
end
map({ "n", "t" }, "<F12>", toggle_float_term, { desc = "Toggle floating terminal" })
map("n", "<leader>tt", toggle_float_term, { desc = "Toggle floating terminal" })

-- Quality of life
map("n", "<leader>sv", ":source $MYVIMRC<CR>", { desc = "Reload config" }) -- options/maps only; plugins: :Lazy
map("n", "<leader>ev", ":edit $MYVIMRC<CR>", { desc = "Edit config" })
map("n", "<leader>tn", ":set relativenumber!<CR>", { desc = "Toggle relative numbers" }) -- (<leader>rn is LSP rename)
map("n", "<leader>sp", ":setlocal spell!<CR>", { desc = "Toggle spell check" })
map("n", "<leader>tw", [[:%s/\s\+$//e<CR>]], { desc = "Trim trailing whitespace" })

-- ------------------------------------------------------------
-- lazy.nvim bootstrap
-- ------------------------------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({ { "Failed to clone lazy.nvim:\n" .. out, "ErrorMsg" } }, true, {})
  end
end
vim.opt.rtp:prepend(lazypath)

-- ------------------------------------------------------------
-- Plugins
-- ------------------------------------------------------------
local servers = { "ts_ls", "pyright", "lua_ls", "bashls", "jsonls", "yamlls" }
if vim.fn.executable("go") == 1 then
  table.insert(servers, "gopls")
end

-- airline-style buffer names: just the file name, or a shortened path when
-- another listed buffer has the same name.
local function unique_tail(name, ctx)
  local path = vim.api.nvim_buf_get_name(ctx.bufnr)
  if path == "" or vim.bo[ctx.bufnr].buftype ~= "" then return name end
  local tail = vim.fn.fnamemodify(path, ":t")
  for _, b in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if b.bufnr ~= ctx.bufnr and vim.fn.fnamemodify(b.name, ":t") == tail then
      return (name:gsub(vim.pesc(tail), vim.fn.pathshorten(vim.fn.fnamemodify(path, ":~:.")), 1))
    end
  end
  return name
end

-- airline's trailing-whitespace warning: first offending line, cached per
-- buffer and refreshed when the text settles.
autocmd({ "BufWinEnter", "BufWritePost", "InsertLeave" }, {
  group = augroup("user_whitespace_check"),
  callback = function(args)
    if vim.bo[args.buf].buftype ~= "" then return end
    vim.b[args.buf].trailing_ws = vim.api.nvim_buf_call(args.buf, function()
      return vim.fn.search([[\s\+$]], "nw")
    end)
  end,
})

local prose = { markdown = true, text = true, gitcommit = true, help = true, mail = true, rst = true, tex = true }

local plugins = {
  -- Theme (the only one used)
  {
    "joshdick/onedark.vim",
    lazy = false,
    priority = 1000,
    config = function() pcall(vim.cmd.colorscheme, "onedark") end,
  },

  -- Statusline and buffer line
  {
    "nvim-lualine/lualine.nvim",
    opts = {
      options = {
        theme = "onedark",
        icons_enabled = false, -- no nvim-web-devicons
        section_separators = { left = "\u{e0b0}", right = "\u{e0b2}" },
        component_separators = { left = "\u{e0b1}", right = "\u{e0b3}" },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = {
          { "branch", icons_enabled = true, icon = "\u{e0a0}" },
          {
            "diff",
            source = function()
              local g = vim.b.gitsigns_status_dict
              if g then return { added = g.added, modified = g.changed, removed = g.removed } end
            end,
          },
        },
        lualine_c = {
          {
            "filename",
            symbols = { modified = "[+]", readonly = "\u{f023}", newfile = "∄" },
          },
        },
        lualine_x = {
          {
            function() return vim.fn.wordcount().words .. " words" end,
            cond = function() return prose[vim.bo.filetype] ~= nil end,
          },
          "filetype",
          "encoding",
          "fileformat",
        },
        lualine_y = { "progress" },
        lualine_z = {
          { "location", fmt = function(s) return "\u{e0a1} " .. vim.trim(s) end },
          "diagnostics",
          {
            function() return "Ξ trailing[" .. vim.b.trailing_ws .. "]" end,
            cond = function() return (vim.b.trailing_ws or 0) > 0 end,
          },
        },
      },
      tabline = {
        lualine_a = {
          {
            "buffers",
            mode = 2, -- name + index, like airline's buffer_idx_mode
            fmt = unique_tail,
            max_length = function() return vim.o.columns end,
          },
        },
        lualine_z = {
          { "tabs", cond = function() return vim.fn.tabpagenr("$") > 1 end },
        },
      },
      extensions = { "fugitive", "fzf", "lazy", "mason", "quickfix" },
    },
  },

  -- Fuzzy finding: just the vim glue (fzf#run); the fzf binary comes from mise.
  "junegunn/fzf",
  "junegunn/fzf.vim",

  -- Git
  "tpope/vim-fugitive",
  {
    -- Review every changed file (e.g. after Claude Code edits) before
    -- committing: <leader>gv all changes, <leader>gh this file's history;
    -- q closes either view.
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory", "DiffviewToggleFiles" },
    keys = {
      { "<leader>gv", "<cmd>DiffviewOpen<CR>", desc = "Review changes (diffview)" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<CR>", desc = "File history (diffview)" },
    },
    opts = {
      use_icons = false, -- no nvim-web-devicons
      keymaps = {
        view = { { "n", "q", "<cmd>DiffviewClose<CR>", { desc = "Close diffview" } } },
        file_panel = { { "n", "q", "<cmd>DiffviewClose<CR>", { desc = "Close diffview" } } },
        file_history_panel = { { "n", "q", "<cmd>DiffviewClose<CR>", { desc = "Close diffview" } } },
      },
    },
  },
  {
    -- ]c/[c next/previous hunk (plain ]c/[c in diff mode),
    -- <leader>hs stage, <leader>hu reset, <leader>hp preview.
    "lewis6991/gitsigns.nvim",
    opts = {
      on_attach = function(buf)
        local gs = require("gitsigns")
        local bmap = function(lhs, rhs, desc)
          map("n", lhs, rhs, { buffer = buf, desc = desc })
        end
        bmap("]c", function()
          if vim.wo.diff then vim.cmd.normal({ "]c", bang = true }) else gs.nav_hunk("next") end
        end, "Next hunk")
        bmap("[c", function()
          if vim.wo.diff then vim.cmd.normal({ "[c", bang = true }) else gs.nav_hunk("prev") end
        end, "Previous hunk")
        bmap("<leader>hs", gs.stage_hunk, "Stage hunk")
        bmap("<leader>hu", gs.reset_hunk, "Reset hunk")
        bmap("<leader>hp", gs.preview_hunk, "Preview hunk")
      end,
    },
  },

  -- Editing improvements (commenting, gc/gcc, is built in since Neovim 0.10;
  -- blink.cmp adds brackets when accepting a function completion)
  "tpope/vim-surround",

  -- Better syntax / structure
  -- main branch: needs Neovim 0.12+ (installed via mise), tree-sitter-cli and
  -- a C compiler to build parsers. It doesn't support lazy loading.
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      -- Installs missing parsers in the background; a no-op once installed.
      if vim.fn.executable("tree-sitter") == 1 then
        require("nvim-treesitter").install({
          "bash", "c", "cpp", "css", "diff", "dockerfile", "git_rebase",
          "gitcommit", "go", "html", "java", "javascript", "json", "lua",
          "markdown", "markdown_inline", "python", "regex", "rust", "sql",
          "toml", "tsx", "typescript", "vim", "vimdoc", "xml", "yaml",
        })
      end

      -- Highlighting and indentation are opt-in per buffer on the main branch.
      autocmd("FileType", {
        group = augroup("user_treesitter"),
        callback = function(args)
          if pcall(vim.treesitter.start, args.buf) then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },

  -- LSP: server installer, server configs, completion. mason-lspconfig
  -- installs `servers` and enables the installed ones; it loads (with mason,
  -- the configs and blink, whose capabilities the servers need up front) when
  -- the first file is opened.
  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUninstall", "MasonUninstallAll", "MasonUpdate", "MasonLog" },
    opts = {},
  },
  {
    "mason-org/mason-lspconfig.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig", "saghen/blink.cmp" },
    opts = { ensure_installed = servers },
  },
  {
    "saghen/blink.cmp",
    version = "1.*",
    event = { "InsertEnter", "CmdlineEnter" },
    opts = {
      keymap = { preset = "default" }, -- <C-y> accept, <C-n>/<C-p> select, <C-space> open
      completion = { documentation = { auto_show = true } },
      signature = { enabled = true },
      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
    config = function(_, opts)
      local blink = require("blink.cmp")
      blink.setup(opts)
      vim.lsp.config("*", { capabilities = blink.get_lsp_capabilities() })
    end,
  },

  -- Ctrl-h/j/k/l across nvim splits and tmux panes (see ~/.tmux.conf)
  "christoomey/vim-tmux-navigator",

  -- Press <leader> (or g, ], z, ...) and wait: a popup lists the next keys.
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      icons = { mappings = false }, -- no icon plugin
      spec = {
        { "<leader>b", group = "buffer" },
        { "<leader>c", group = "code" },
        { "<leader>f", group = "find" },
        { "<leader>g", group = "git" },
        { "<leader>h", group = "hunk" },
        { "<leader>l", group = "lsp" },
        { "<leader>r", group = "rename" },
        { "<leader>s", group = "source/spell" },
        { "<leader>t", group = "terminal/toggle" },
      },
    },
  },
}

-- :source $MYVIMRC re-applies the options and mappings above; lazy.nvim
-- refuses a second setup.
if not vim.g.lazy_did_setup then
  require("lazy").setup(plugins, {
    -- Pinned versions, committed next to this file (resolved through
    -- link.sh's symlink, so updates land in the repo).
    lockfile = vim.fs.dirname(vim.fn.resolve(debug.getinfo(1, "S").source:sub(2))) .. "/lazy-lock.json",
    install = { colorscheme = { "onedark" } },
    change_detection = { notify = false },
  })
end

-- The colorscheme may be missing (or fail) on first launch.
user_highlights()
