---@type Aiwaku.State
local state = {
	current_session = nil,
	current_tool = nil,
	session_bufnrs = {},
	win_id = nil,
	config = nil,
	busy = false,
}

return state
