local pwd = debug.getinfo(1).source:match("@?(.*/)")
-- read and load vimrc
-- local vimrc = io.open(pwd.."vimrc", "r")
-- vim.api.nvim_exec(vimrc:read("*all"), false)
-- vimrc:close()

-- Mappings.
-- See `:help vim.diagnostic.*` for documentation on any of the below functions
local opts = { noremap = true, silent = true }
-- vim.keymap.set('n', '<space>e', vim.diagnostic.open_float, opts)
-- vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
-- vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
-- vim.keymap.set('n', '<leader>i', vim.diagnostic.setloclist, opts)

-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
	-- Enable completion triggered by <c-x><c-o>
	vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

	-- Mappings.
	-- See `:help vim.lsp.*` for documentation on any of the below functions
	local bufopts = { noremap = true, silent = true, buffer = bufnr }
	vim.keymap.set("n", "gD", vim.lsp.buf.declaration, bufopts)
	vim.keymap.set("n", "gd", vim.lsp.buf.definition, bufopts)
	vim.keymap.set("n", "<C-space>", vim.lsp.buf.hover, bufopts)
	vim.keymap.set("n", "<leader>i", vim.lsp.buf.hover, bufopts)
	vim.keymap.set("n", "gi", vim.lsp.buf.implementation, bufopts)
	-- vim.keymap.set('n', '<leader>i', vim.lsp.buf.signature_help, bufopts)
	-- vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, bufopts)
	-- vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, bufopts)
	-- vim.keymap.set('n', '<space>wl', function()
	-- print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
	-- end, bufopts)
	-- vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, bufopts)
	-- vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, bufopts)
	-- vim.keymap.set('n', '<space>ca', vim.lsp.buf.code_action, bufopts)
	vim.keymap.set("n", "gr", vim.lsp.buf.references, bufopts)
	-- vim.keymap.set('n', '<space>f', function() vim.lsp.buf.format { async = true } end, bufopts)
end

local lsp_flags = {
	-- This is the default in Nvim 0.7+
	debounce_text_changes = 150,
}
require("lspconfig")["pyright"].setup({
	on_attach = on_attach,
	flags = lsp_flags,
})
require("lspconfig")["tsserver"].setup({
	on_attach = on_attach,
	flags = lsp_flags,
})
require("lspconfig")["lua_ls"].setup({
	settings = {
		Lua = {
			completion = {
				callSnippet = "Replace",
			},
		},
	},
})
-- Configure LSP through rust-tools.nvim plugin.
-- rust-tools will configure and enable certain LSP features for us.
-- See https://github.com/simrat39/rust-tools.nvim#configuration
require("rust-tools").setup({
	tools = { -- rust-tools options
		auto = true,
		inlay_hints = {
			show_parameter_hints = true,
			-- parameter_hints_prefix = "",
			-- other_hints_prefix = "",
		},
	},

	-- all the opts to send to nvim-lspconfig
	-- these override the defaults set by rust-tools.nvim
	-- see https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#rust_analyzer
	server = {
		-- on_attach is a callback called when the language server attachs to the buffer
		on_attach = on_attach,
		flags = lsp_flags,
		settings = {
			-- to enable rust-analyzer settings visit:
			-- https://github.com/rust-analyzer/rust-analyzer/blob/master/docs/user/generated_config.adoc
			["rust-analyzer"] = {
				-- enable clippy on save
				checkOnSave = {
					command = "clippy",
				},
			},
		},
	},
})

local cmp = require("cmp")
cmp.setup({
	window = {
		completion = cmp.config.window.bordered(),
		documentation = cmp.config.window.bordered(),
	},
	snippet = {
		-- this is required even if snippet is not enabled! otherwise rust-tools fail.
		expand = function(args)
			vim.fn["UltiSnips#Anon"](args.body)
		end,
	},
	mapping = cmp.mapping.preset.insert({
		["<C-k>"] = cmp.mapping.select_prev_item(),
		["<C-j>"] = cmp.mapping.select_next_item(),
		["<C-p>"] = cmp.mapping.select_prev_item(),
		["<C-n>"] = cmp.mapping.select_next_item(),
		["<S-Tab>"] = cmp.mapping.select_prev_item(),
		["<Tab>"] = cmp.mapping.select_next_item(),
		["<C-[>"] = cmp.mapping.scroll_docs(-4),
		["<C-]>"] = cmp.mapping.scroll_docs(4),
		["<C-f>"] = cmp.mapping.scroll_docs(-4),
		["<C-d>"] = cmp.mapping.scroll_docs(4),
		["<C-space>"] = cmp.mapping.complete(),
		-- ['<Esc>'] = cmp.mapping.abort(),
		["<C-e>"] = cmp.mapping.abort(),
		["<CR>"] = cmp.mapping.confirm({
			behavior = cmp.ConfirmBehavior.Insert,
			select = true,
		}), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
	}),
	sources = cmp.config.sources({
		{ name = "ultisnips" },
	}, {
		{ name = "nvim_lsp" },
	}, {
		{ name = "buffer" },
	}),
})

-- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
-- cmp.setup.cmdline({ '/', '?' }, {
--     -- mapping = cmp.mapping.preset.cmdline(),
--     mapping = {
--       ['<C-p>'] = cmp.mapping(cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }), { 'i', 'c' }),
--       ['<C-d>'] = cmp.mapping(cmp.mapping.scroll_docs(-4), { 'i', 'c' }),
--       ['<C-f>'] = cmp.mapping(cmp.mapping.scroll_docs(4), { 'i', 'c' }),
--       ['<C-Space>'] = cmp.mapping(cmp.mapping.complete(), { 'i', 'c' }),
--       ['<C-e>'] = cmp.mapping(cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true }), { 'i', 'c' }),
--       ['<CR>'] = cmp.mapping.confirm({
--           behavior = cmp.ConfirmBehavior.Replace,
--           select = false,
--         }),
--       ['<Tab>'] = cmp.mapping(cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }), { 'i', 'c' }),
--       ['<S-Tab>'] = cmp.mapping(cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }), { 'i', 'c' }),
--     },
--     sources = {
--       { name = 'buffer' }
--     }
--   })

-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
-- cmp.setup.cmdline(':', {
--   mapping = cmp.mapping.preset.cmdline(),
--   sources = cmp.config.sources({
--     { name = 'path' }
--   }, {
--     { name = 'cmdline' }
--   })
-- })

local actions = require("telescope.actions")
local action_layout = require("telescope.actions.layout")
require("telescope").setup({
	defaults = {
		mappings = {
			n = {
				["<M-p>"] = action_layout.toggle_preview,
			},
			i = {
				["<M-p>"] = action_layout.toggle_preview,
				["<C-j>"] = actions.move_selection_next,
				["<C-k>"] = actions.move_selection_previous,
			},
		},
		layout_config = {
			horizontal = { height = 0.95, width = 0.95, preview_width = 0.6 },
		},
	},
})
-- To get fzf loaded and working with telescope, you need to call
-- load_extension, somewhere after setup function:
require("telescope").load_extension("fzf")

require("nvim-treesitter.configs").setup({
	ensure_installed = { "c", "lua", "vim", "vimdoc", "query" },
	auto_install = true,
	sync_install = false,
	highlight = {
		enable = true,
		-- Setting this to true will run `:h syntax` and tree-sitter at the same time.
		-- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
		-- Using this option may slow down your editor, and you may see some duplicate highlights.
		-- Instead of true it can also be a list of languages
		additional_vim_regex_highlighting = false,
	},
})

require("mason").setup()
require("chatgpt").setup()
require("lualine").setup({
	options = {
		icons_enabled = true,
		theme = "kanagawa",
		component_separators = { left = "", right = "" },
		section_separators = { left = "", right = "" },
		disabled_filetypes = {
			statusline = {},
			winbar = {},
		},
		ignore_focus = {},
		always_divide_middle = true,
		globalstatus = false,
		refresh = {
			statusline = 1000,
			tabline = 1000,
			winbar = 1000,
		},
	},
	sections = {
		lualine_a = { "mode" },  -- TODO how to show just N/V/NB etc?
		lualine_b = {
			"branch",
			"diff",
		},
		lualine_c = {
			"filename",
			{
				"diagnostics",
				-- Table of diagnostic sources, available sources are:
				--   'nvim_lsp', 'nvim_diagnostic', 'nvim_workspace_diagnostic', 'coc', 'ale', 'vim_lsp'.
				-- or a function that returns a table as such:
				--   { error=error_cnt, warn=warn_cnt, info=info_cnt, hint=hint_cnt }
				sources = { "nvim_diagnostic", "ale" },

				-- Displays diagnostics for the defined severity types
				sections = { "error", "warn", "info", "hint" },

				diagnostics_color = {
					-- Same values as the general color option can be used here.
					error = "DiagnosticError", -- Changes diagnostics' error color.
					warn = "DiagnosticWarn", -- Changes diagnostics' warn color.
					info = "DiagnosticInfo", -- Changes diagnostics' info color.
					hint = "DiagnosticHint", -- Changes diagnostics' hint color.
				},
				symbols = { error = "E", warn = "W", info = "I", hint = "H" },
				colored = true, -- Displays diagnostics status in color if set to true.
				update_in_insert = false, -- Update diagnostics in insert mode.
				always_visible = false, -- Show diagnostics even if there are none.
			},
		},
		lualine_x = { "encoding", "fileformat", "filetype" },
		lualine_y = { "progress" },
		lualine_z = { "location" },
	},
	inactive_sections = {
		lualine_a = {},
		lualine_b = {},
		lualine_c = { "filename" },
		lualine_x = { "location" },
		lualine_y = {},
		lualine_z = {},
	},
	tabline = {},
	winbar = {},
	inactive_winbar = {},
	extensions = {},
})

require("which-key").register({
	n = {
		name = "ChatGPT",
		p = { "<cmd>ChatGPTActAs<CR>", "Act As...", mode = { "n", "v" } },
		n = { "<cmd>ChatGPT<CR>", "ChatGPT" },
		e = { "<cmd>ChatGPTEditWithInstruction<CR>", "Edit with instruction", mode = { "n", "v" } },
		g = { "<cmd>ChatGPTRun grammar_correction<CR>", "Grammar Correction", mode = { "n", "v" } },
		t = { "<cmd>ChatGPTRun translate<CR>", "Translate", mode = { "n", "v" } },
		k = { "<cmd>ChatGPTRun keywords<CR>", "Keywords", mode = { "n", "v" } },
		d = { "<cmd>ChatGPTRun docstring<CR>", "Docstring", mode = { "n", "v" } },
		a = { "<cmd>ChatGPTRun add_tests<CR>", "Add Tests", mode = { "n", "v" } },
		o = { "<cmd>ChatGPTRun optimize_code<CR>", "Optimize Code", mode = { "n", "v" } },
		s = { "<cmd>ChatGPTRun summarize<CR>", "Summarize", mode = { "n", "v" } },
		f = { "<cmd>ChatGPTRun fix_bugs<CR>", "Fix Bugs", mode = { "n", "v" } },
		x = { "<cmd>ChatGPTRun explain_code<CR>", "Explain Code", mode = { "n", "v" } },
		r = { "<cmd>ChatGPTRun roxygen_edit<CR>", "Roxygen Edit", mode = { "n", "v" } },
		l = { "<cmd>ChatGPTRun code_readability_analysis<CR>", "Code Readability Analysis", mode = { "n", "v" } },
	},
}, { prefix = "<leader>" })
require("which-key.plugins.presets").operators["y"] = nil
