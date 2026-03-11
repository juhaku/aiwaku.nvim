local M = {}

local async = require("plenary.async")
local config = require("aiwaku.config")
local state = require("aiwaku.state")
local tmux = require("aiwaku.tmux")
local terminal = require("aiwaku.terminal")
local window = require("aiwaku.window")

local ui_select = async.wrap(vim.ui.select, 3)
local ui_input = async.wrap(vim.ui.input, 2)

---Generate a unique tmux session name for the aiwaku.
---@return string name  e.g. "ai-20260305234735-1234"
local function gen_session_name()
	return "ai-" .. vim.fn.strftime("%Y%m%d%H%M%S") .. "-" .. math.random(1000, 9999)
end

---Build the shell command string for a given CLI tool command.
---@param tool Aiwaku.CliTool
---@return string
local function resolve_cmd(tool)
	if type(tool.cmd) == "table" and vim.islist(tool.cmd) then
		return table.concat(tool.cmd, " ")
	end
	return tostring(tool.cmd)
end

---Find a tmux session by name.
---Returns the session table when the tmux session exists, nil otherwise.
---@param name string tmux session name (e.g. "ai-20260305234735-1234")
---@return Aiwaku.Session|nil
function M.find_session(name)
	if not tmux.session_exists(name) then
		return nil
	end
	return { name = name, created_at = tmux.get_session_created(name) }
end

---Show an existing tmux session in the sidebar split.
---Reuses the cached nvim buffer when still alive; otherwise creates a new
---terminal buffer joining the tmux session.
---@param session Aiwaku.Session
function M.open_session(session)
	if window.win_visible(state.win_id) then
		vim.api.nvim_set_current_win(state.win_id)
	else
		state.win_id = window.open_split()
	end

	local cached_buf = state.session_bufnrs[session.name]
	if terminal.buf_alive(cached_buf) then
		vim.api.nvim_win_set_buf(state.win_id, cached_buf)
	else
		local new_buf = terminal.open_in_new_terminal_buf(tmux.join_session_cmd(session.name))
		if new_buf == 0 then
			return
		end
		terminal.setup_terminal_buf(new_buf)
		state.session_bufnrs[session.name] = new_buf
	end

	state.current_session = session.name
	vim.cmd("startinsert")
end

---Create a new aiwaku session (new tmux session + new terminal buffer).
---Uses the currently selected tool (set via select_tool()); falls back to the first configured tool.
---@param name? string Optional session name; defaults to a timestamp-based name.
---@return Aiwaku.Session|nil session The newly created session, or nil if setup() was not called.
function M.new_session(name)
	if not state.config then
		vim.notify("[aiwaku] Call setup() before new_session()", vim.log.levels.ERROR)
		return nil
	end

	local tool = state.current_tool or state.config.cmd[1]
	local session_name = name or gen_session_name()

	-- Close the current window so a clean split is created
	if window.win_visible(state.win_id) then
		vim.api.nvim_win_close(state.win_id, false)
		state.win_id = nil
	end

	state.win_id = window.open_split()

	local new_buf = terminal.open_in_new_terminal_buf(tmux.new_session_cmd(session_name, resolve_cmd(tool)))
	if new_buf == 0 then
		return nil
	end
	terminal.setup_terminal_buf(new_buf)
	state.session_bufnrs[session_name] = new_buf
	state.current_session = session_name

	vim.cmd("startinsert")

	---@type Aiwaku.Session
	return {
		name = session_name,
		created_at = os.date(config.date_format) --[[@as string]],
	}
end

---Toggle the aiwaku: hide it if visible, show or create if hidden.
---Resumes the current tmux session when one is active; creates a new one otherwise.
function M.toggle()
	if state.busy then
		return
	end

	if not state.config then
		vim.notify("[aiwaku] Call setup() before toggle()", vim.log.levels.ERROR)
		return
	end

	if window.win_visible(state.win_id) then
		vim.api.nvim_win_close(state.win_id, false)
		state.win_id = nil
		return
	end

	local session = state.current_session and M.find_session(state.current_session)
	if session then
		M.open_session(session)
		return
	end

	M.new_session()
end

---Open a picker to select the active CLI tool.
---Sets state.current_tool; new sessions will use this tool until changed.
---When only one tool is configured, selects it directly without showing a picker.
---@async
M.select_tool = async.void(function()
	if state.busy then
		return
	end
	state.busy = true
	local function _()
		if not state.config then
			vim.notify("[aiwaku] Call setup() before select_tool()", vim.log.levels.ERROR)
			return
		end

		local tools = state.config.cmd

		if #tools == 1 then
			state.current_tool = tools[1]
			vim.notify("[aiwaku] Using tool: " .. tools[1].name, vim.log.levels.INFO)
			return
		end

		local tool = ui_select(tools, {
			prompt = "Select CLI tool",
			kind = "Aiwaku.CliTool",
			format_item = function(t)
				local active = (state.current_tool and state.current_tool.name == t.name) and " [active]" or ""
				return t.name .. active
			end,
		})

		if tool then
			state.current_tool = tool
			vim.notify("[aiwaku] Switched to tool: " .. tool.name, vim.log.levels.INFO)
		end
	end
	_()
	state.busy = false
end)

---Open a picker listing all active aiwaku tmux sessions.
---Selecting a session shows it in the sidebar.
M.select_session = async.void(function()
	if state.busy then
		return
	end
	state.busy = true
	local function _()
		if not state.config then
			vim.notify("[aiwaku] Call setup() before select_session()", vim.log.levels.ERROR)
			return
		end

		local sessions = tmux.list_sessions()

		if #sessions == 0 then
			vim.notify("[aiwaku] No active tmux sessions found", vim.log.levels.INFO)
			return
		end

		local item = ui_select(sessions, {
			prompt = "Select AI session",
			kind = "Aiwaku.Session",
			format_item = function(s)
				local active = (s.name == state.current_session) and " [active]" or ""
				return s.name .. active .. " (" .. s.created_at .. ")"
			end,
		})

		if item then
			M.open_session(item)
		end
	end
	_()
	state.busy = false
end)

---Clear the context of the current session by killing its tmux session and
---starting a fresh one. If no session is active a new one is created instead.
function M.clear_context()
	if state.busy then
		return
	end

	if not state.config then
		vim.notify("[aiwaku] Call setup() before clear_context()", vim.log.levels.ERROR)
		return
	end

	local name = state.current_session
	if not name then
		M.new_session()
		return
	end

	-- Kill the tmux session (this also terminates the running AI process)
	if tmux.session_exists(name) then
		tmux.kill_session(name)
	end

	-- Wipe the cached nvim buffer for this session
	local cached_buf = state.session_bufnrs[name]
	if terminal.buf_alive(cached_buf) then
		if vim.fn.jobstop(vim.b[cached_buf].terminal_job_id) == 0 then
			vim.notify(
				"[aiwaku] Could not stop terminal job: " .. vim.b[cached_buf].terminal_job_id,
				vim.log.levels.WARN
			)
		end
		vim.api.nvim_buf_delete(cached_buf, { force = true })
	end
	state.session_bufnrs[name] = nil
	state.current_session = nil

	-- Close the sidebar window so new_session creates a clean split
	if window.win_visible(state.win_id) then
		vim.api.nvim_win_close(state.win_id, false)
		state.win_id = nil
	end

	M.new_session()
end

---Rename the current tmux session.
---Prompts the user with vim.ui.input showing only the suffix after the "ai-" prefix.
---The "ai-" prefix is always enforced on the resulting session name so that
---sessions remain visible in the session picker.
---Updates the tmux session name and the internal state cache.
M.rename_session = async.void(function()
	if state.busy then
		return
	end
	state.busy = true
	local function _()
		if not state.config then
			vim.notify("[aiwaku] Call setup() before rename_session()", vim.log.levels.ERROR)
			return
		end

		local old_name = state.current_session
		if not old_name then
			vim.notify("[aiwaku] No active session to rename", vim.log.levels.WARN)
			return
		end

		-- Show only the part after "ai-" so the user edits a clean label
		local suffix = old_name:match("^ai%-(.+)$") or old_name

		local input = ui_input({ prompt = "Rename session (ai-): ", default = suffix })
		if not input or vim.trim(input) == "" then
			return
		end

		local new_name = "ai-" .. vim.trim(input)
		if new_name == old_name then
			return
		end

		if not tmux.rename_session(old_name, new_name) then
			vim.notify("[aiwaku] Failed to rename tmux session", vim.log.levels.ERROR)
			return
		end

		-- Migrate the buffer cache to the new name
		state.session_bufnrs[new_name] = state.session_bufnrs[old_name]
		state.session_bufnrs[old_name] = nil
		state.current_session = new_name
	end
	_()
	state.busy = false
end)

return M
