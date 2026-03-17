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
			if action_def.diagnostic then
				require("aiwaku").send_diagnostic(action_def.prompt)
			elseif action_def.file_diagnostic then
				require("aiwaku").send_file_diagnostics(action_def.prompt)
			elseif action_def.buffer then
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
		fn = function(params)
			if not state.config then
				vim.notify("[aiwaku] Call setup() before using LSP code actions", vim.log.levels.ERROR)
				return {}
			end
			local lsp_range = params.lsp_params and params.lsp_params.range
			local has_selection = lsp_range ~= nil
				and (lsp_range["start"].line ~= lsp_range["end"].line
					or lsp_range["start"].character ~= lsp_range["end"].character)
			local cursor_lnum = params.row - 1
			local cursor_diags = vim.diagnostic.get(params.bufnr, { lnum = cursor_lnum })
			local buffer_diags = vim.diagnostic.get(params.bufnr)
			local actions = {}
			for _, action_def in ipairs(state.config.lsp_code_actions) do
				if type(action_def.title) ~= "string" or action_def.title == "" then
					vim.notify("[aiwaku] Skipping LSP code action with missing or empty title", vim.log.levels.WARN)
				elseif action_def.diagnostic and #cursor_diags == 0 then
					-- skip: no diagnostic on cursor line
				elseif action_def.file_diagnostic and #buffer_diags == 0 then
					-- skip: no diagnostics in buffer
				elseif not action_def.buffer and not action_def.diagnostic and not action_def.file_diagnostic and not has_selection then
					-- skip: selection-based action but no visual selection active
				else
					table.insert(actions, make_code_action(action_def))
				end
			end
			return actions
		end,
	},
}

return M
