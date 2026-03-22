local M = {}

local async = require("plenary.async")
local config = require("aiwaku.config")
local state = require("aiwaku.state")
local tmux = require("aiwaku.tmux")
local terminal = require("aiwaku.terminal")
local window = require("aiwaku.window")
local words = require("aiwaku.words")

local ui_select = async.wrap(vim.ui.select, 3)
local ui_input = async.wrap(vim.ui.input, 2)

local function close_sidebar_window()
	if not window.win_visible(state.win_id) then
		state.win_id = nil
		return
	end

	vim.api.nvim_win_close(state.win_id, false)
	state.win_id = nil
end

---Return the sanitized tail component of the current working directory.
---Replaces tmux target-separator characters (. and :) with hyphen so the
---result is safe to embed in a session name that will be used as a -t target.
---@return string cwd  e.g. "myproj" or "aiwaku-nvim"
local function current_cwd()
	local raw = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
	local cwd = (raw == "" or raw == ".") and "root" or raw
	local result = cwd:gsub("[%.:]", "-")
	return result
end

---Generate a unique tmux session name for the aiwaku.
---Format: "ai-<tool>-<cwd>-<adjective>-<noun>-<hex>"
---@param tool_name string  Name of the active CLI tool
---@return string name  e.g. "ai-claude-myproj-quirky-tesla-a7f3"
local function gen_session_name(tool_name)
	local parts = { "ai", tool_name, current_cwd(), words.random_pair() }
	return table.concat(parts, "-")
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
---@param name string tmux session name (e.g. "ai-claude-myproj-quirky-tesla-a7f3")
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
	if window.win_visible_in_current_tab(state.win_id) then
		vim.api.nvim_set_current_win(state.win_id)
	else
		close_sidebar_window()
		state.win_id = window.open_split()
	end

	local cached_buf = state.session_bufnrs[session.name]
	if terminal.buf_alive(cached_buf) then
		vim.api.nvim_win_set_buf(state.win_id, cached_buf)
	else
		local new_buf = terminal.open_in_new_terminal_buf(tmux.join_session_cmd(session.name), session.name)
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
---@param name? string Optional session name; defaults to a tool + random-words name.
---@return Aiwaku.Session|nil session The newly created session, or nil if setup() was not called.
function M.new_session(name)
	if not state.config then
		vim.notify("[aiwaku] Call setup() before new_session()", vim.log.levels.ERROR)
		return nil
	end

	local tool = state.current_tool or state.config.cmd[1]
	local session_name = name or gen_session_name(tool.name)

	-- Close the current window so a clean split is created
	close_sidebar_window()
	state.win_id = window.open_split()

	local new_buf =
		terminal.open_in_new_terminal_buf(tmux.new_session_cmd(session_name, resolve_cmd(tool)), session_name)
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

---Toggle the aiwaku: hide it if focused, focus it if `jump` is enabled and it is
---already open but not focused, show or create it otherwise.
---Resumes the current tmux session when one is active; tries to reconnect to an
---existing session for the current working directory otherwise; creates a new one
---when no matching session exists.
---@param opts? Aiwaku.ToggleOpts
function M.toggle(opts)
	if state.busy then
		return
	end

	if not state.config then
		vim.notify("[aiwaku] Call setup() before toggle()", vim.log.levels.ERROR)
		return
	end

	if window.win_visible_in_current_tab(state.win_id) then
		if opts and opts.jump then
			if vim.api.nvim_get_current_win() == state.win_id then
				close_sidebar_window()
			else
				if vim.api.nvim_win_is_valid(state.win_id) then
					vim.api.nvim_set_current_win(state.win_id)
				else
					state.win_id = nil
				end
			end
		else
			close_sidebar_window()
		end
		return
	end

	if state.current_session then
		local session = M.find_session(state.current_session)
		if session then
			M.open_session(session)
			return
		end
		-- Stale reference: the tmux session no longer exists.
		state.current_session = nil
	end

	-- No active session in state; try to reconnect to an existing aiwaku tmux
	-- session for the current working directory before creating a fresh one.
	-- Session names follow the pattern: ai-<tool>-<cwd>-<adj>-<noun>-<hex>.
	local cwd_pattern = "^ai%-[^%-]+-" .. vim.pesc(current_cwd()) .. "%-"
	local sessions = vim.iter(tmux.list_sessions()):filter(function(s)
		return s.name:match(cwd_pattern) ~= nil
	end):totable()
	if #sessions > 0 then
		-- Pick the most recently created session (ISO date string sorts correctly).
		table.sort(sessions, function(a, b)
			return a.created_at > b.created_at
		end)
		M.open_session(sessions[1])
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
	local ok, err = pcall(_)
	state.busy = false
	if not ok then
		vim.notify("[aiwaku] Error in select_tool: " .. tostring(err), vim.log.levels.ERROR)
	end
end)

---Open a picker listing all active aiwaku tmux sessions.
---Selecting a session shows it in the sidebar.
---@async
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
	local ok, err = pcall(_)
	state.busy = false
	if not ok then
		vim.notify("[aiwaku] Error in select_session: " .. tostring(err), vim.log.levels.ERROR)
	end
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
	close_sidebar_window()
	M.new_session()
end

---Rename the current tmux session.
---Prompts the user with vim.ui.input showing only the suffix after the "ai-" prefix.
---The "ai-" prefix is always enforced on the resulting session name so that
---sessions remain visible in the session picker.
---Updates the tmux session name and the internal state cache.
---@async
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
		terminal.set_buf_name(state.session_bufnrs[new_name], new_name)
	end
	local ok, err = pcall(_)
	state.busy = false
	if not ok then
		vim.notify("[aiwaku] Error in rename_session: " .. tostring(err), vim.log.levels.ERROR)
	end
end)

---Restore the last-used AI session after a Neovim session is loaded.
---Scans all buffers for names matching "aiwaku://ai-" (written by set_buf_name when a
---session was last opened). If found, verifies the tmux session still exists and:
---  - If the ghost buffer was visible in a window in the current tabpage: reconnects the
---    sidebar in that window without stealing focus from the user's editing window.
---  - If the ghost buffer was hidden or in another tabpage: sets state.current_session
---    so the next toggle() reconnects naturally in the current tab.
---  - If the tmux session no longer exists: warns the user and cleans up the ghost buffer.
function M.restore_session()
	if not state.config or not state.config.restore_on_session_load then
		return
	end

	local sessions = vim.iter(tmux.list_sessions()):fold({}, function(acc, item)
		acc[item.name] = item
		return acc
	end)

	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		local name = vim.api.nvim_buf_get_name(bufnr)
		local session_name = name:match("^aiwaku://(ai%-[^/]+)$")
		if session_name then
			local session = sessions[session_name]
			if not session then
				vim.notify("[aiwaku] Previous session '" .. session_name .. "' no longer exists.", vim.log.levels.WARN)
				vim.api.nvim_buf_delete(bufnr, { force = true })
			else
				-- Find the window currently showing this ghost buffer (may be nil).
				local ghost_win = vim.fn.win_findbuf(bufnr)[1]

				state.current_session = session_name

				-- Delete the ghost buffer now to free its name so that open_session
				-- (or the next toggle()) can claim it without hitting E95. Any window
				-- that was showing the ghost buffer will temporarily display another
				-- buffer; open_session will replace it with the live terminal.
				vim.api.nvim_buf_delete(bufnr, { force = true })

				if ghost_win and window.win_visible_in_current_tab(ghost_win) then
					-- Restore the sidebar into the existing window without stealing focus.
					local prev_win = vim.api.nvim_get_current_win()
					state.win_id = ghost_win
					M.open_session(session)
					-- Return focus to the user's editing window after open_session's startinsert.
					-- Skip when the sidebar itself was focused (keep terminal insert mode active).
					vim.schedule(function()
						if prev_win ~= ghost_win and vim.api.nvim_win_is_valid(prev_win) then
							vim.api.nvim_set_current_win(prev_win)
							vim.cmd("stopinsert")
						end
					end)
				end

				return
			end
		end
	end
end

---Kill all active AI tmux sessions, wipe their cached buffers, close the
---sidebar window, and reset plugin state. Useful for a clean teardown.
---@return nil
function M.quit_all()
	if state.busy then
		return
	end

	if not state.config then
		vim.notify("[aiwaku] Call setup() before quit_all()", vim.log.levels.ERROR)
		return
	end

	local sessions = tmux.list_sessions()
	for _, s in ipairs(sessions) do
		local name = s.name
		tmux.kill_session(name)

		local cached_buf = state.session_bufnrs[name]
		if terminal.buf_alive(cached_buf) then
			local job_id = vim.b[cached_buf].terminal_job_id
			if job_id and vim.fn.jobstop(job_id) == 0 then
				vim.notify("[aiwaku] Could not stop terminal job: " .. job_id, vim.log.levels.WARN)
			end
			vim.api.nvim_buf_delete(cached_buf, { force = true })
		end
		state.session_bufnrs[name] = nil
	end

	close_sidebar_window()
	state.current_session = nil
	vim.notify("[aiwaku] All sessions closed", vim.log.levels.INFO)
end

return M
