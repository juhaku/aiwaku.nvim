local null_ls = require("null-ls")

local function make_code_action(title, prompt)
	return {
		title = title,
		action = function()
			local ok, aiwaku = pcall(require, "aiwaku")
			if ok then
				aiwaku.send_selection(prompt)
			else
				vim.notify("[aiwaku] Module not loaded", vim.log.levels.WARN)
			end
		end,
	}
end

local M = {
	name = "aiwaku",
	method = null_ls.methods.CODE_ACTION,
	filetypes = {}, -- available for all filetypes
	generator = {
		fn = function(_params)
			return {
				make_code_action("Send to Aiwaku", nil),
				make_code_action("AI: explain this code", "explain this code:"),
				make_code_action("AI: refactor this code", "refactor this code:"),
			}
		end,
	},
}

return M
