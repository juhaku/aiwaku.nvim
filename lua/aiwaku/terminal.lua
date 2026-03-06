local M = {}

local state = require("aiwaku.state")

---Return true when the given buffer number refers to a live, loaded buffer.
---@param bufnr integer
---@return boolean
function M.buf_alive(bufnr)
	return bufnr ~= nil and bufnr ~= 0 and vim.api.nvim_buf_is_valid(bufnr)
end

---Set up buffer-local keymaps and options for a sidebar terminal buffer.
---@param bufnr integer
function M.setup_terminal_buf(bufnr)
	local bopts = { noremap = true, silent = true, buffer = bufnr }
	for lhs, keymap in pairs(state.config.terminal_keymaps) do
		vim.keymap.set("t", lhs, keymap.command, vim.tbl_extend("force", bopts, { desc = keymap.description }))
	end

	-- Mark buffer as belonging to the aiwaku so autocmds can identify it
	vim.b[bufnr].aiwaku = true

	-- Disable line numbers for a cleaner terminal feel
	vim.api.nvim_buf_call(bufnr, function()
		vim.opt_local.number = false
		vim.opt_local.relativenumber = false
		vim.opt_local.signcolumn = "no"
	end)
end

---Extract the basename of the configured command for use in buffer names.
---Handles both string and list cmd values.
---@return string name e.g. "copilot", "opencode"
local function cmd_name()
	local cmd = state.config and state.config.cmd
	local raw
	if type(cmd) == "table" and cmd[1] then
		raw = tostring(cmd[1])
	elseif type(cmd) == "string" then
		raw = cmd:match("^%S+") or cmd
	else
		return "terminal"
	end
	return vim.fn.fnamemodify(raw, ":t")
end


---Open a new terminal buffer running the given shell command.
---Used internally by session.lua to start new-session or join an existing one.
---@param cmd string Full shell command to run inside the terminal
---@return integer bufnr New terminal buffer number, or 0 on failure.
function M.open_in_new_terminal_buf(cmd)
	local new_buf = vim.api.nvim_create_buf(false, false)
	vim.api.nvim_win_set_buf(state.win_id, new_buf)

	vim.api.nvim_buf_call(new_buf, function()
		local job = vim.fn.jobstart(cmd, { term = true })
		if job < 0 then
			vim.notify(
				"[aiwaku] Failed to start job (status: " .. job .. "), cannot run in terminal buffer: " .. cmd,
				vim.log.levels.ERROR
			)
			return
		end
		vim.b[new_buf].terminal_job_id = job
	end)

	if not vim.b[new_buf].terminal_job_id then
		vim.api.nvim_buf_delete(new_buf, { force = true })
		return 0
	end

	vim.api.nvim_buf_set_name(new_buf, "aiwaku://" .. cmd_name() .. "-" .. new_buf)
	return new_buf
end

return M
