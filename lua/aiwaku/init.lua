local M = {}

local config = require("aiwaku.config")
local state = require("aiwaku.state")
local session = require("aiwaku.session")
local sender = require("aiwaku.send")

---Toggle the AI sidebar.
---@param opts? Aiwaku.ToggleOpts
---@return nil
function M.toggle(opts)
	session.toggle(opts)
end
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

-- Merge user keymaps into the defaults by matching mode groups by value.
-- tbl_deep_extend uses table references as keys so two distinct { "n" } tables
-- never merge; this function compares mode lists by their sorted contents instead.
---@param defaults {[Aiwaku.Keymap.Mode[]]: {[string]: Aiwaku.Keymap}}
---@param user_km {[Aiwaku.Keymap.Mode[]]: {[string]: Aiwaku.Keymap}}|nil
---@return {[Aiwaku.Keymap.Mode[]]: {[string]: Aiwaku.Keymap}}
local function merge_keymaps(defaults, user_km)
	if not user_km then
		return defaults
	end
	local function mode_sig(modes)
		local m = vim.list_extend({}, modes)
		table.sort(m)
		return table.concat(m, ",")
	end
	-- Build a signature→key lookup from the defaults
	local sig_to_key = {}
	local result = vim.deepcopy(defaults)
	for modes in pairs(result) do
		sig_to_key[mode_sig(modes)] = modes
	end
	for user_modes, user_bindings in pairs(user_km) do
		local key = sig_to_key[mode_sig(user_modes)]
		if key then
			-- Merge individual lhs entries into the existing mode group
			for lhs, binding in pairs(user_bindings) do
				result[key][lhs] = binding
			end
		else
			result[user_modes] = vim.deepcopy(user_bindings)
		end
	end
	return result
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
	-- keymaps uses array tables as keys; tbl_deep_extend cannot merge them by
	-- value. Re-merge user keymaps so individual lhs overrides work correctly.
	if opts and opts.keymaps then
		state.config.keymaps = merge_keymaps(config.defaults.keymaps, opts.keymaps)
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
			local toggle_opt = args.fargs[2]
			if toggle_opt ~= nil and toggle_opt ~= "jump" then
				vim.notify("[aiwaku] Unknown toggle option: " .. tostring(toggle_opt), vim.log.levels.WARN)
				return
			end
			M.toggle({
				jump = toggle_opt == "jump",
			})
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
			if cmdline:match("^%s*Aiwaku%s+%S+%s") then
				if cmdline:match("^%s*Aiwaku%s+toggle%s+") then
					local matches = {}
					for _, s in ipairs({ "jump" }) do
						if vim.startswith(s, arglead) then
							table.insert(matches, s)
						end
					end
					return matches
				end
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
