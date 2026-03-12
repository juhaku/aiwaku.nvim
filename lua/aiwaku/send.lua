local M = {}

local state = require("aiwaku.state")
local session = require("aiwaku.session")
local window = require("aiwaku.window")

local SEVERITY_NAMES = { "ERROR", "WARN", "INFO", "HINT" }

---Format a single diagnostic entry as a human-readable line.
---@param d vim.Diagnostic
---@param file string Display name of the buffer file
---@return string
local function format_diagnostic(d, file)
	local sev = SEVERITY_NAMES[d.severity] or "UNKNOWN"
	local src = "[" .. (d.source or "unknown") .. "] "
	return string.format("[%s] %s%s:%d: %s", sev, src, file, d.lnum + 1, d.message)
end

---@param bufnr integer
---@param line_number? integer When set, gather diagnostics for the line first and fall back to the full buffer
---@return string?
local function build_diagnostics_text(bufnr, line_number)
	local diagnostics = line_number and vim.diagnostic.get(bufnr, { lnum = line_number }) or vim.diagnostic.get(bufnr)
	if line_number and #diagnostics == 0 then
		diagnostics = vim.diagnostic.get(bufnr)
	end
	if #diagnostics == 0 then
		return nil
	end

	local name = vim.api.nvim_buf_get_name(bufnr)
	local file = (name ~= "" and name) or "<unnamed>"
	local parts = {}
	for _, d in ipairs(diagnostics) do
		table.insert(parts, format_diagnostic(d, file))
	end

	return table.concat(parts, "\n") .. "\n"
end

---Get the visually selected text from the previous visual selection.
---Must be called right after leaving visual mode (e.g. from a mapping).
---@return string text The selected text with a trailing newline appended
local function get_visual_selection()
	local _, ls, cs = unpack(vim.fn.getpos("'<"))
	local _, le, ce = unpack(vim.fn.getpos("'>"))
	local lines = vim.api.nvim_buf_get_lines(0, ls - 1, le, false)
	if #lines == 0 then
		return ""
	end
	-- Trim to the exact column range of the selection
	lines[#lines] = lines[#lines]:sub(1, ce)
	lines[1] = lines[1]:sub(cs)
	return table.concat(lines, "\n") .. "\n"
end

---Dispatch text to the active sidebar terminal, then focus the sidebar.
---Opens the sidebar if it is not currently visible.
---@param text string Content to send to the terminal job
local function send_to_session(text)
	local session_name = state.current_session
	local current_session = session_name and session.find_session(session_name)
	if not current_session then
		vim.notify("[aiwaku] No active aiwaku session", vim.log.levels.WARN)
		return
	end

	if not window.win_visible_in_current_tab(state.win_id) then
		session.open_session(current_session)
	end

	local bufnr = state.session_bufnrs[session_name]
	if not bufnr then
		vim.notify("[aiwaku] Session buffer is nil, failed to open session", vim.log.levels.WARN)
		return
	end
	local job_id = vim.b[bufnr].terminal_job_id
	if not job_id then
		vim.notify("[aiwaku] Sidebar terminal has no job channel", vim.log.levels.WARN)
		return
	end
	if state.config.auto_submit then
		if text:sub(-1) == "\n" then
			text = text:sub(1, -2) .. "\r"
		else
			text = text .. "\r"
		end
	end
	vim.api.nvim_chan_send(job_id, text)

	vim.api.nvim_set_current_win(state.win_id)
	vim.cmd("startinsert")
end

---Send the current visual selection to the active sidebar terminal.
---Must be called from a visual-mode mapping so the selection marks are set.
---@param prompt? string Optional prompt prefix prepended before the selection (e.g. "explain this code:")
M.send_selection = function(prompt)
	if not state.config then
		vim.notify("[aiwaku] Call setup() before send_selection()", vim.log.levels.ERROR)
		return
	end

	local text = get_visual_selection()
	if text == "" then
		vim.notify("[aiwaku] No text selected", vim.log.levels.WARN)
		return
	end

	if prompt then
		text = prompt .. "\n" .. text
	end

	send_to_session(text)
end

---Send the entire current buffer to the active sidebar terminal.
---@param prompt? string Optional prompt prefix prepended before the buffer content
M.send_buffer = function(prompt)
	if not state.config then
		vim.notify("[aiwaku] Call setup() before send_buffer()", vim.log.levels.ERROR)
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	if #lines == 0 or (#lines == 1 and lines[1] == "") then
		vim.notify("[aiwaku] Buffer is empty", vim.log.levels.WARN)
		return
	end

	local name = vim.api.nvim_buf_get_name(bufnr)
	local filetype = vim.bo[bufnr].filetype
	local display_name = (name ~= "" and name) or "<unnamed>"
	local display_ft = (filetype ~= "" and filetype) or "unknown"

	-- Build header so the AI knows the file context
	local header = string.format("File: %s (%s)\n", display_name, display_ft)
	local content = header .. table.concat(lines, "\n") .. "\n"

	if prompt then
		content = prompt .. "\n" .. content
	end

	send_to_session(content)
end

---Send the diagnostic under the cursor to the active sidebar terminal.
---Falls back to all buffer diagnostics when no diagnostic exists on the current line.
---@param prompt? string Optional prompt prefix prepended before the diagnostics
M.send_diagnostic = function(prompt)
	if not state.config then
		vim.notify("[aiwaku] Call setup() before send_diagnostic()", vim.log.levels.ERROR)
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1
	local text = build_diagnostics_text(bufnr, row)
	if not text then
		vim.notify("[aiwaku] No diagnostics found", vim.log.levels.WARN)
		return
	end

	if prompt then
		text = prompt .. "\n" .. text
	end

	send_to_session(text)
end

---Send all diagnostics for the current buffer to the active sidebar terminal.
---@param prompt? string Optional prompt prefix prepended before the diagnostics
M.send_file_diagnostics = function(prompt)
	if not state.config then
		vim.notify("[aiwaku] Call setup() before send_file_diagnostics()", vim.log.levels.ERROR)
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local text = build_diagnostics_text(bufnr)
	if not text then
		vim.notify("[aiwaku] No diagnostics in buffer", vim.log.levels.WARN)
		return
	end

	if prompt then
		text = prompt .. "\n" .. text
	end

	send_to_session(text)
end

return M
