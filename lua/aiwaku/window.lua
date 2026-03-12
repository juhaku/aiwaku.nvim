local M = {}

local state = require("aiwaku.state")
local config = require("aiwaku.config")

---Return true when the sidebar window is currently visible.
---@param win_id integer|nil
---@return boolean
function M.win_visible(win_id)
	return win_id ~= nil and vim.api.nvim_win_is_valid(win_id)
end

---Return true when the sidebar window is visible in the current tabpage.
---@param win_id integer|nil
---@return boolean
function M.win_visible_in_current_tab(win_id)
	return M.win_visible(win_id) and vim.api.nvim_win_get_tabpage(win_id) == vim.api.nvim_get_current_tabpage()
end

---Open a vertical split on the configured side and return the new window ID.
---@return integer win_id
function M.open_split()
	local cfg = state.config
	local direction = (cfg and cfg.position == "left") and "topleft" or "botright"
	local width = (cfg and cfg.width) or config.defaults.width
	vim.cmd(direction .. " " .. width .. "vsplit")
	local win_id = vim.api.nvim_get_current_win()
	-- Pin the window width so other splits don't squish it
	vim.wo[win_id].winfixwidth = true
	return win_id
end

return M
