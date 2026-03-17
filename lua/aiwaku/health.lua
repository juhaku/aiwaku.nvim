local M = {}

---Parse a version string like "3.2a" or "3.4" into a {major, minor} table.
---@param version_str string
---@return {[1]: integer, [2]: integer}|nil
local function parse_version(version_str)
	local major, minor = version_str:match("(%d+)%.(%d+)")
	if major and minor then
		return { tonumber(major), tonumber(minor) }
	end
end

---@return nil
function M.check()
	local state = require("aiwaku.state")

	-- Neovim version
	vim.health.start("aiwaku: Neovim version")
	local nv = vim.version()
	if nv.major > 0 or nv.minor >= 10 then
		vim.health.ok(("Neovim %d.%d.%d >= 0.10"):format(nv.major, nv.minor, nv.patch))
	else
		vim.health.error(
			("Neovim %d.%d.%d detected, >= 0.10 is required"):format(nv.major, nv.minor, nv.patch),
			{ "Upgrade Neovim to 0.10 or later." }
		)
	end

	-- tmux
	vim.health.start("aiwaku: tmux")
	if vim.fn.executable("tmux") ~= 1 then
		vim.health.error("tmux not found in PATH", { "Install tmux >= 3.0 and ensure it is on your PATH." })
	else
		local result = vim.system({ "tmux", "-V" }, { text = true }):wait()
		local output = vim.trim(result.stdout or "")
		-- "tmux 3.4" or "tmux next-3.4"
		local version_str = output:match("tmux%s+[^%d]*(%d+%.%d+)")
		local v = version_str and parse_version(version_str)
		if not v then
			vim.health.warn(
				("Could not parse tmux version from: %q"):format(output),
				{ "Ensure tmux >= 3.0 is installed." }
			)
		elseif v[1] > 3 or (v[1] == 3 and v[2] >= 0) then
			vim.health.ok(("tmux %s >= 3.0"):format(version_str))
		else
			vim.health.error(
				("tmux %s detected, >= 3.0 is required"):format(version_str),
				{ "Upgrade tmux to 3.0 or later." }
			)
		end
	end

	-- plenary.nvim (required)
	vim.health.start("aiwaku: plenary.nvim")
	local ok_plenary = pcall(require, "plenary")
	if ok_plenary then
		vim.health.ok("plenary.nvim is available")
	else
		vim.health.error(
			"plenary.nvim not found",
			{ "Add nvim-lua/plenary.nvim to your plugin manager and ensure it is loaded." }
		)
	end

	-- dressing.nvim (optional)
	vim.health.start("aiwaku: dressing.nvim (optional)")
	local ok_dressing = pcall(require, "dressing")
	if ok_dressing then
		vim.health.ok("dressing.nvim is available")
	else
		vim.health.warn(
			"dressing.nvim not found",
			{ "Install stevearc/dressing.nvim for improved input/select UI. Without it, Neovim's built-in vim.ui is used." }
		)
	end

	-- none-ls / null-ls (optional)
	vim.health.start("aiwaku: none-ls / null-ls (optional)")
	local ok_nullls = pcall(require, "null-ls")
	if ok_nullls then
		vim.health.ok("none-ls / null-ls is available")
	else
		vim.health.info("none-ls / null-ls not found — LSP code actions integration will not be available")
	end

	-- Configuration
	vim.health.start("aiwaku: configuration")
	if state.config then
		local tools = state.config.cmd
		local names = {}
		for _, tool in ipairs(tools) do
			table.insert(names, tool.name)
		end
		vim.health.ok(("setup() called — active tool(s): %s"):format(table.concat(names, ", ")))
	else
		vim.health.info("setup() has not been called yet — call require('aiwaku').setup() in your config")
	end
end

return M
