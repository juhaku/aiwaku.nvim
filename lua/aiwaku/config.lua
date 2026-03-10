local M = {}

---Date format used when displaying session creation times (local timezone).
M.date_format = "%Y-%m-%dT%H:%M:%S%z"

---@type Aiwaku.Config
M.defaults = {
	cmd = {
		{name = "copilot", cmd = "copilot"},
	},
	width = 80,
	position = "right",
	keymaps = {
		[{ "n" }] = {
			["<leader>ai"] = {
				command = function()
					require("aiwaku").toggle()
				end,
				description = "Toggle Aiwaku",
			},
			["<leader>an"] = {
				command = function()
					require("aiwaku").new_session()
				end,
				description = "Aiwaku: new session",
			},
			["<leader>as"] = {
				command = function()
					require("aiwaku").select_session()
				end,
				description = "Aiwaku: select session",
			},
			["<leader>ar"] = {
				command = function()
					require("aiwaku").rename_session()
				end,
				description = "Aiwaku: rename session",
			},
			["<leader>ab"] = {
				command = function()
					require("aiwaku").send_buffer()
				end,
				description = "Aiwaku: send buffer",
			},
		},
		[{ "v" }] = {
			["<leader>ai"] = {
				command = "<Esc><Cmd>lua require('aiwaku').send_selection()<CR>",
				description = "Aiwaku: send selection",
			},
		},
	},
	lsp_code_actions = {
		{ title = "Send to Aiwaku" },
		{ title = "AI: explain this code", prompt = "explain this code:" },
		{ title = "AI: refactor this code", prompt = "refactor this code:" },
		{ title = "AI: send this file", buffer = true },
		{ title = "AI: explain this file", prompt = "explain this file:", buffer = true },
	},
	terminal_keymaps = {
		["<C-w>h"] = { command = "<C-\\><C-n><C-w>h", description = "Focus left" },
		["<C-w>l"] = { command = "<C-\\><C-n><C-w>l", description = "Focus right" },
		["<C-a>r"] = {
			command = "<C-\\><C-n><Cmd>lua require('aiwaku').rename_session()<CR>",
			description = "Aiwaku: rename session",
		},
		["<C-a>s"] = {
			command = "<C-\\><C-n><Cmd>lua require('aiwaku').select_session()<CR>",
			description = "Aiwaku: select session",
		},
		["<C-a>n"] = {
			command = "<C-\\><C-n><Cmd>lua require('aiwaku').new_session()<CR>",
			description = "Aiwaku: new session",
		},
		["<C-a>c"] = {
			command = "<C-\\><C-n><Cmd>lua require('aiwaku').clear_context()<CR>",
			description = "Aiwaku: clear context",
		},
		["<C-o>"] = {
			command = "<C-\\><C-n><Cmd>lua require('aiwaku').open_cword_in_tab()<CR>",
			description = "Aiwaku: open file under cursor in new tab",
		},
	},
}

return M
