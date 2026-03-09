local null_ls_ok, null_ls = pcall(require, "null-ls")
local state = require("aiwaku.state")

if not null_ls_ok then
	vim.notify("[aiwaku] null_ls not loaded, cannot create LSP code actions", vim.log.levels.WARN)
	return {}
end

---Build a single null-ls code action entry from an action definition.
---@param action_def Aiwaku.LspCodeAction
---@return table null_ls code action
local function make_code_action(action_def)
	return {
		title = action_def.title,
		action = function()
			if action_def.buffer then
				require("aiwaku").send_buffer(action_def.prompt)
			else
				require("aiwaku").send_selection(action_def.prompt)
			end
		end,
	}
end

---null-ls source that exposes configured LSP code actions for all filetypes.
local M = {
	name = "aiwaku",
	method = null_ls.methods.CODE_ACTION,
	filetypes = {},
	generator = {
		fn = function(_params)
			if not state.config then
				vim.notify("[aiwaku] Call setup() before using LSP code actions", vim.log.levels.ERROR)
				return {}
			end
			local actions = {}
			for _, action_def in ipairs(state.config.lsp_code_actions) do
				if type(action_def.title) ~= "string" or action_def.title == "" then
					vim.notify("[aiwaku] Skipping LSP code action with missing or empty title", vim.log.levels.WARN)
				else
					table.insert(actions, make_code_action(action_def))
				end
			end
			return actions
		end,
	},
}

return M
