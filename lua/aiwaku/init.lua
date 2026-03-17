-- Requires: nvim-lua/plenary.nvim
local M = {}

local config = require("aiwaku.config")
local state = require("aiwaku.state")
local session = require("aiwaku.session")
local sender = require("aiwaku.send")

M.toggle = session.toggle
M.new_session = session.new_session
M.select_session = session.select_session
M.select_tool = session.select_tool
M.clear_context = session.clear_context
M.rename_session = session.rename_session
M.quit_all = session.quit_all
M.send_selection = sender.send_selection
M.send_buffer = sender.send_buffer
M.send_diagnostic = sender.send_diagnostic
M.send_file_diagnostics = sender.send_file_diagnostics

---Return the display name of the current active AI session, suitable for use
---in a statusline or winbar. Returns nil when no session is active or before
---setup() has been called.
---@return string|nil
function M.session_name()
	if not state.current_session then
		return nil
	end
	return state.current_session:gsub("^ai%-", "")
end

---Open the file path under the cursor in a new tab.
---Strips optional :line or :line:col suffix from the word (AI tools often
---output paths in the form src/file.lua:42 or src/file.lua:42:5).
---Falls back to a cwd-relative lookup when the path is not absolute.
function M.open_cword_in_tab()
	local word = vim.fn.expand("<cWORD>")
	if word == "" then
		return
	end

	local path = word
	local line = nil
	local p, l = word:match("^(.-):(%d+):%d+$")
	if p then
		path, line = p, tonumber(l)
	else
		p, l = word:match("^(.-):(%d+)$")
		if p then
			path, line = p, tonumber(l)
		end
	end

	if vim.fn.filereadable(path) == 0 then
		local rel = vim.fn.getcwd() .. "/" .. path
		if vim.fn.filereadable(rel) == 1 then
			path = rel
		else
			vim.notify("[aiwaku] File not found: " .. path, vim.log.levels.WARN)
			return
		end
	end

	vim.cmd("tabedit " .. vim.fn.fnameescape(path))
	if line then
		vim.api.nvim_win_set_cursor(0, { line, 0 })
	end
end

---Initialize the aiwaku module.
---Call this once from your Neovim config (e.g. keymap.lua).
---@param opts? Aiwaku.Config Partial config; unset keys fall back to defaults
function M.setup(opts)
	---@type Aiwaku.Config
	state.config = vim.tbl_deep_extend("force", config.defaults, opts or {})
	state.config.cmd = config.normalize_cmd(state.config.cmd)
	-- lsp_code_actions is a list; tbl_deep_extend merges by integer index rather
	-- than replacing the whole array. When the user supplies it, use it as-is.
	if opts and opts.lsp_code_actions then
		state.config.lsp_code_actions = opts.lsp_code_actions
	end

	local km = state.config.keymaps
	local kopts = { noremap = true, silent = true }

	for mode, keymap in pairs(km) do
		for lhs, k in pairs(keymap) do
			vim.keymap.set(mode, lhs, k.command, vim.tbl_extend("force", kopts, { desc = k.description }))
		end
	end

	local subcmds = { "toggle", "new", "select", "rename", "clear", "tool", "quit" }
	vim.api.nvim_create_user_command("Aiwaku", function(args)
		local sub = args.fargs[1]
		if sub == "toggle" then
			M.toggle()
		elseif sub == "new" then
			M.new_session(args.fargs[2])
		elseif sub == "select" then
			M.select_session()
		elseif sub == "rename" then
			M.rename_session()
		elseif sub == "clear" then
			M.clear_context()
		elseif sub == "tool" then
			M.select_tool()
		elseif sub == "quit" then
			M.quit_all()
		else
			vim.notify("[aiwaku] Unknown subcommand: " .. tostring(sub), vim.log.levels.WARN)
		end
	end, {
		nargs = "+",
		complete = function(arglead, cmdline, _)
			-- Only complete the first (subcommand) argument
			if cmdline:match("^%s*Aiwaku%s+%S+%s") then
				return {}
			end
			local matches = {}
			for _, s in ipairs(subcmds) do
				if vim.startswith(s, arglead) then
					table.insert(matches, s)
				end
			end
			return matches
		end,
	})

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

	-- Autocmd: restore the last-used AI session when a Neovim session is loaded
	vim.api.nvim_create_autocmd("SessionLoadPost", {
		group = vim.api.nvim_create_augroup("AiwakuSessionRestore", {}),
		callback = function()
			session.restore_session()
		end,
	})
end

return M
