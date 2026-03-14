local M = {}

---Date format used when displaying session creation times (local timezone).
M.date_format = "%Y-%m-%dT%H:%M:%S%z"

---Resolve the display name for a CLI tool from its cmd value.
---Used during normalization to derive tool names when not explicitly provided.
---@param cmd string|string[] CLI command value
---@return string name
local function name_from_cmd(cmd)
	local raw
	if type(cmd) == "table" then
		raw = tostring(cmd[1])
	else
		raw = cmd:match("^%S+") or cmd
	end
	return vim.fn.fnamemodify(raw, ":t")
end

---Normalize the user-supplied cmd config value to a list of Aiwaku.CliTool.
---Accepts the old string and string[] formats alongside the new CliTool[] format.
---@param cmd string|string[]|Aiwaku.CliTool[] Raw cmd value from config
---@return Aiwaku.CliTool[]
function M.normalize_cmd(cmd)
	if type(cmd) == "string" then
		return { { name = name_from_cmd(cmd), cmd = cmd } }
	end
	if type(cmd) == "table" and vim.islist(cmd) then
		if type(cmd[1]) == "string" then
			-- Old string[] format: { "claude", "--arg" }
			return { { name = name_from_cmd(cmd), cmd = cmd } }
		end
		-- CliTool[] format — ensure every entry has a name
		local out = {}
		for _, tool in ipairs(cmd) do
			table.insert(out, {
				name = tool.name or name_from_cmd(tool.cmd),
				cmd = tool.cmd,
			})
		end
		return out
	end
	return { { name = "terminal", cmd = tostring(cmd) } }
end

---@type Aiwaku.Config
M.defaults = {
	cmd = { "copilot" },
	width = 80,
	position = "right",
	auto_submit = false,
	restore_on_session_load = true,
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
			["<leader>ad"] = {
				command = function()
					require("aiwaku").send_diagnostic()
				end,
				description = "Aiwaku: send diagnostic",
			},
			["<leader>at"] = {
				command = function()
					require("aiwaku").select_tool()
				end,
				description = "Aiwaku: select CLI tool",
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
		{ title = "AI: send selection" },
		{ title = "AI: explain this code", prompt = "explain this code:" },
		{ title = "AI: refactor this code", prompt = "refactor this code:" },
		{ title = "AI: send this file", buffer = true },
		{ title = "AI: explain this file", prompt = "explain this file:", buffer = true },
		{ title = "AI: send diagnostics", diagnostic = true },
		{ title = "AI: fix diagnostics", prompt = "Fix the following diagnostics:", diagnostic = true },
		{ title = "AI: send file diagnostics", file_diagnostic = true },
	},
	terminal_keymaps = {
		["<C-w>h"] = { command = "<C-\\><C-n><C-w>h", description = "Focus left" },
		["<C-w>l"] = { command = "<C-\\><C-n><C-w>l", description = "Focus right" },
		["<C-a>i"] = {
			command = "<C-\\><C-n><Cmd>lua require('aiwaku').toggle()<CR>",
			description = "Toggle Aiwaku",
		},
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
		["<C-a>t"] = {
			command = "<C-\\><C-n><Cmd>lua require('aiwaku').select_tool()<CR>",
			description = "Aiwaku: select CLI tool",
		},
		["<C-o>"] = {
			command = "<C-\\><C-n><Cmd>lua require('aiwaku').open_cword_in_tab()<CR>",
			description = "Aiwaku: open file under cursor in new tab",
		},
	},
}

return M
