local M = {}

---Date format used when displaying session creation times (local timezone).
M.date_format = "%Y-%m-%dT%H:%M:%S%z"

---@type Aiwaku.Config
M.defaults = {
	cmd = { "copilot" },
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
	},
}

return M
