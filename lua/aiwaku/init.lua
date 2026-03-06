-- Requires: nvim-lua/plenary.nvim
local M = {}

local config = require("aiwaku.config")
local state = require("aiwaku.state")
local session = require("aiwaku.session")
local selection = require("aiwaku.selection")

M.toggle = session.toggle
M.new_session = session.new_session
M.select_session = session.select_session
M.clear_context = session.clear_context
M.rename_session = session.rename_session
M.send_selection = selection.send_selection

---Initialize the aiwaku module.
---Call this once from your Neovim config (e.g. keymap.lua).
---@param opts? Aiwaku.Config Partial config; unset keys fall back to defaults
function M.setup(opts)
	---@type Aiwaku.Config
	state.config = vim.tbl_deep_extend("force", config.defaults, opts or {})

	local km = state.config.keymaps
	local kopts = { noremap = true, silent = true }

	for mode, keymap in pairs(km) do
		for lhs, k in pairs(keymap) do
			vim.keymap.set(mode, lhs, k.command, vim.tbl_extend("force", kopts, { desc = k.description }))
		end
	end

	-- Autocmd: automatically enter terminal mode when focusing a sidebar buffer
	vim.api.nvim_create_autocmd("BufEnter", {
		group = vim.api.nvim_create_augroup("AiwakuFocus", {}),
		callback = function()
			local bufnr = vim.api.nvim_get_current_buf()
			if vim.b[bufnr].aiwaku and vim.bo[bufnr].buftype == "terminal" then
				vim.cmd("startinsert")
			end
		end,
	})
end

return M
