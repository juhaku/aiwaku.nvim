---Minimal coroutine-based async helpers used by interactive picker flows.
---Provides the two primitives that plenary.async exposed:
---  `wrap`  — turns a callback-taking function into a coroutine-awaitable one.
---  `void`  — runs a function as a coroutine when called, returning immediately.
---@class Aiwaku.Async
local M = {}

---Wrap a callback-based function so it can be awaited inside a coroutine.
---The callback is injected at argument position `argc`.
---Handles both synchronous callbacks (callback fires before `fn` returns)
---and asynchronous ones (callback fires after the coroutine has yielded).
---@param fn function
---@param argc integer  Total argument count including the callback position
---@return function
function M.wrap(fn, argc)
	return function(...)
		local args = { ... }
		local thread = coroutine.running()
		local sync_results
		args[argc] = function(...)
			if coroutine.status(thread) == "suspended" then
				local ok, err = coroutine.resume(thread, ...)
				if not ok then
					vim.notify("[aiwaku] async resume error: " .. tostring(err), vim.log.levels.ERROR)
				end
			else
				-- Callback fired synchronously while the coroutine was still running;
				-- store results so the caller can return them without yielding.
				sync_results = { ... }
			end
		end
		fn(unpack(args))
		if sync_results then
			return unpack(sync_results)
		end
		return coroutine.yield()
	end
end

---Return a function that, when called, runs `fn` inside a fresh coroutine.
---The caller is not blocked; the coroutine drives forward each time an
---awaited callback resumes it.
---@param fn function
---@return function
function M.void(fn)
	return function(...)
		local args = { ... }
		local thread = coroutine.create(fn)
		local ok, err = coroutine.resume(thread, unpack(args))
		if not ok then
			vim.notify("[aiwaku] async error: " .. tostring(err), vim.log.levels.ERROR)
		end
	end
end

return M
