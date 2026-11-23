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

autocmd("TextYankPost", {
  group = augroup("user_yank"),
  callback = function() vim.hl.on_yank({ timeout = 300 }) end,
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
ft_local({ "markdown", "text", "gitcommit" },
  { textwidth = 80, colorcolumn = "80,100", formatoptions = "tcqrn1" })
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
map("n", "<leader>w", ":w<CR>")
map("n", "<leader>q", ":q<CR>")
map("n", "<leader>Q", ":qa<CR>")

-- Window navigation: Ctrl-h/j/k/l is mapped by vim-tmux-navigator, which also
-- crosses into tmux panes.

-- Resize splits
map("n", "<A-h>", ":vertical resize -3<CR>")
map("n", "<A-l>", ":vertical resize +3<CR>")
map("n", "<A-j>", ":resize -3<CR>")
map("n", "<A-k>", ":resize +3<CR>")

-- Buffer navigation
map("n", "<leader>bn", ":bnext<CR>")
map("n", "<leader>bp", ":bprevious<CR>")
map("n", "<leader>bd", ":bdelete<CR>")
map("n", "<leader>bl", ":buffers<CR>")

-- Keep visual selection when indenting
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Move selected lines up/down
map("x", "J", ":move '>+1<CR>gv=gv")
map("x", "K", ":move '<-2<CR>gv=gv")

-- Better paste over selection without overwriting unnamed register
map("x", "<leader>p", [["_dP]])

-- Yank to system clipboard
map({ "n", "v" }, "<leader>y", [["+y]])
map("n", "<leader>Y", [["+Y]])

-- Delete without yanking
map({ "n", "v" }, "<leader>d", [["_d]])

-- FZF ($FZF_DEFAULT_COMMAND comes from ~/.shellrc.sh)
map("n", "<leader>ff", ":Files<CR>")
map("n", "<leader>fg", ":GFiles<CR>")
map("n", "<leader>fb", ":Buffers<CR>")
map("n", "<leader>fr", ":Rg<CR>")
map("n", "<leader>fh", ":History<CR>")
map("n", "<leader>fc", ":Commands<CR>")
map("n", "<leader>fm", ":Marks<CR>")
vim.g.fzf_layout = { down = "40%" }

-- Git (fugitive; gitsigns' hunk maps are in its spec)
map("n", "<leader>gs", ":Git<CR>")
map("n", "<leader>gd", ":Gdiffsplit<CR>")
map("n", "<leader>gb", ":Git blame<CR>")
map("n", "<leader>gc", ":Git commit<CR>")
map("n", "<leader>gp", ":Git push<CR>")
map("n", "<leader>gl", ":Git log<CR>")

-- Claude Code: send current buffer / visual selection
map("n", "<leader>ab", ":ClaudeCodeAdd %<CR>")
map("x", "<leader>as", ":ClaudeCodeSend<CR>")

-- Terminal: double Esc leaves terminal mode; a single Esc still reaches TUIs
-- running in the terminal (Claude Code, fzf, htop, nested vim).
map("t", "<Esc><Esc>", [[<C-\><C-n>]])
map("t", "<C-h>", [[<C-\><C-n><C-w>h]])
map("t", "<C-j>", [[<C-\><C-n><C-w>j]])
map("t", "<C-k>", [[<C-\><C-n><C-w>k]])
map("t", "<C-l>", [[<C-\><C-n><C-w>l]])

-- Quality of life
map("n", "<leader>sv", ":source $MYVIMRC<CR>") -- options/maps only; plugins: :Lazy
map("n", "<leader>ev", ":edit $MYVIMRC<CR>")
map("n", "<leader>tn", ":set relativenumber!<CR>") -- (<leader>rn is LSP rename)
map("n", "<leader>sp", ":setlocal spell! spelllang=en_us<CR>")
map("n", "<leader>tw", [[:%s/\s\+$//e<CR>]])

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
      extensions = { "fugitive", "fzf", "lazy", "mason", "nerdtree", "quickfix" },
    },
  },

  -- Fuzzy finding: just the vim glue (fzf#run); the fzf binary comes from mise.
  "junegunn/fzf",
  "junegunn/fzf.vim",

  -- Git
  "tpope/vim-fugitive",
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

  -- Editing improvements (commenting, gc/gcc, is built in since Neovim 0.10)
  "tpope/vim-surround",
  { "windwp/nvim-autopairs", event = "InsertEnter", opts = {} },

  -- File tree
  {
    "preservim/nerdtree",
    cmd = { "NERDTreeToggle", "NERDTreeFind" },
    keys = {
      { "<leader>e", ":NERDTreeToggle<CR>" },
      { "<leader>E", ":NERDTreeFind<CR>" },
    },
    init = function()
      vim.g.NERDTreeShowHidden = 1
      vim.g.NERDTreeMinimalUI = 1
      vim.g.NERDTreeIgnore = { [[\.git$]], "node_modules$", "dist$", "build$", ".next$" }
    end,
  },

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
          "bash", "c", "cpp", "css", "dockerfile", "go", "html", "javascript",
          "json", "lua", "markdown", "markdown_inline", "python", "regex", "tsx",
          "typescript", "vim", "vimdoc", "yaml",
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

  -- Indent guides (virtual text: unlike indentLine, doesn't touch
  -- conceallevel, which hid quotes in JSON and Markdown). help, terminal and
  -- other special buffers are excluded by default.
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    opts = {
      indent = { char = "│" },
      exclude = { filetypes = { "nerdtree" } },
    },
  },

  -- Terminal integration
  {
    "voldikss/vim-floaterm",
    cmd = { "FloatermToggle", "FloatermNew" },
    keys = {
      { "<F12>", ":FloatermToggle<CR>", silent = true },
      { "<F12>", [[<C-\><C-n>:FloatermToggle<CR>]], mode = "t", silent = true },
      { "<leader>tt", ":FloatermToggle<CR>" },
    },
    init = function()
      vim.g.floaterm_width = 0.9
      vim.g.floaterm_height = 0.85
      vim.g.floaterm_position = "center"
    end,
  },
  {
    "coder/claudecode.nvim",
    opts = {
      auto_start = true,
      terminal = { provider = "none" },
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
