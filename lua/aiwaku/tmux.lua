local M = {}

local config = require("aiwaku.config")

---Run a tmux command synchronously.
---@param args string[] Argument list passed to the tmux executable
---@return integer code Exit code of the tmux process
---@return string[] lines Stdout lines produced by the process
local function run_tmux(args)
	local cmd = vim.list_extend({ "tmux" }, args)
	local lines = vim.fn.systemlist(cmd)
	return vim.v.shell_error, lines
end

---Return true when a tmux session with the given name exists.
---@param name string tmux session name
---@return boolean
function M.session_exists(name)
	local code = run_tmux({ "has-session", "-t", name })
	return code == 0
end

---Return a list of aiwaku tmux sessions (names prefixed with "ai-").
---@return Aiwaku.Session[]
function M.list_sessions()
	local _, lines = run_tmux({ "list-sessions", "-F", "#{session_name}\t#{session_created}" })
	---@type Aiwaku.Session[]
	local sessions = {}
	for _, line in ipairs(lines or {}) do
		local name, epoch = line:match("^(ai%-[^\t]+)\t(.+)$")
		if name then
			local created = tonumber(vim.trim(epoch)) or 0
			table.insert(sessions, { name = name, created_at = os.date(config.date_format, created) })
		end
	end
	return sessions
end

---Return the formatted creation time of a tmux session.
---@param name string tmux session name
---@return string created_at Formatted date string, or epoch zero if unavailable.
function M.get_session_created(name)
	local _, lines = run_tmux({ "display-message", "-p", "-t", name, "#{session_created}" })
	local epoch = tonumber(vim.trim((lines or {})[1] or "")) or 0
	return os.date(config.date_format, epoch) --[[@as string]]
end

---Kill the given tmux session.
---@param name string tmux session name
---@return boolean ok True when the session was killed successfully.
function M.kill_session(name)
	local code = run_tmux({ "kill-session", "-t", name })
	return code == 0
end

---Rename a tmux session.
---@param old string Current tmux session name
---@param new string New tmux session name
---@return boolean ok True when the rename succeeded.
function M.rename_session(old, new)
	local code = run_tmux({ "rename-session", "-t", old, new })
	return code == 0
end

---Return the shell command for starting a new tmux session running cmd.
---The returned string is intended to be passed to terminal.open_in_new_terminal_buf.
---@param name string tmux session name
---@param cmd string Shell command to run inside the new session
---@return string
function M.new_session_cmd(name, cmd)
	local env_flag = ""
	local socket = vim.v.servername
	if socket and socket ~= "" then
		env_flag = " -e NVIM=" .. vim.fn.shellescape(socket)
	end
	return "tmux new-session -s " .. vim.fn.shellescape(name) .. env_flag .. " " .. vim.fn.shellescape(cmd)
end

---Return the shell command for joining an existing tmux session.
---The returned string is intended to be passed to terminal.open_in_new_terminal_buf.
---@param name string tmux session name
---@return string
function M.join_session_cmd(name)
	return "tmux attach-session -t " .. vim.fn.shellescape(name)
end

return M
