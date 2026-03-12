---
applyTo: "**/*.lua"
---

# Lua Code Generate and Review Instructions

## Simplicity and minimal changes

- Prefer the simplest correct solution. Flag over-engineering, unnecessary abstraction, or boilerplate.
- Change only what the task requires. Do not refactor, rename, or reorganise unrelated code in the same commit.
  - Exception: refactor only when it removes genuine duplication or directly supports the requested change. Follow the KISS principle.
- Remove unnecessary intermediate variables when the expression is already readable.
- Flatten nested conditionals: prefer multiple early returns over deeply nested `if` blocks.
- An extra line of code is not automatically better than a dense one; judge by comprehension, not line count.
- DO not do any breaking changes if anyway possible, if NOT always confirm first.

## No redundant guards

- If a value is validated earlier in the same function, do not re-check it again further down.
- Trust established invariants: once `state.config`, a buffer handle, or a window handle is confirmed valid at entry, deeper callees in the same execution path need not repeat that nil-check.
- Each guard must appear exactly once per execution path. Duplicate guards are noise and obscure the real logic.
- When a guard makes a subsequent check structurally impossible (e.g., early `return` on nil), remove the redundant check rather than leaving it as defensive dead code.

## Execution path coverage

- Every branch must be reachable and intentional. Dead code after a `return` statement is a bug.
- Trace all guard/early-return combinations and verify the happy path is clear and direct.
- For async flows wrapped with `plenary.async.void`, ensure every error path either returns cleanly or notifies the user — coroutines must not be silently abandoned.
- When adding a new code path, verify existing guards still cover it or add the appropriate guard once at the right point.

## LuaDoc annotations

Annotations drive type-checking and IDE support. Keep them accurate.

- All public module functions (every key returned in `M`) must carry `---@param` and `---@return` annotations.
- When constructing a table that satisfies a `---@class` definition, add `---@type ClassName` on the line before the return statement.
- Functions wrapped in `plenary.async.void` must be annotated `---@async`.
- Optional fields use the `?` suffix: `---@field foo? string`.
- `lua/aiwaku/types.lua` is the single source of type truth. Do not duplicate class shapes inline in implementation files; reference the types instead.
- Module-level `---@class` or `---@module` doc blocks describe the module's public surface.
- Do not add annotations for private/local functions unless their signatures are non-obvious.

## Idiomatic Neovim Lua

- Prefer `vim.api.*` over `vim.fn.*` when a stable nvim API equivalent exists and provides the same functionality without shell round-trips.
- Use `vim.bo[bufnr]`, `vim.wo[winid]`, `vim.b[bufnr]`, and `vim.o` for option and variable access. `nvim_buf_get_option` / `nvim_win_get_option` are deprecated in Neovim 0.10+.
- `vim.system()` (Neovim 0.10+) is the modern alternative to `vim.fn.systemlist` for spawning subprocesses. Prefer it for new subprocess code.
- Use `ipairs` for sequential arrays and `pairs` for hash tables. Do not mix them.
- Avoid `..` string concatenation inside loops; collect parts in a table and use `table.concat(parts, sep)`.
- Follow the module pattern: all public symbols go through `M`; return `M` at the end of the file; do not leak internals.
- Use `vim.notify(msg, vim.log.levels.LEVEL)` with an explicit level for all user-facing messages. Include the `[aiwaku]` prefix in the message string.

## Performance

- Shell-outs (`vim.fn.systemlist`, `vim.system`, any `vim.fn.*` that spawns a process) are expensive. Never call them inside loops or on every editor event (e.g., `CursorMoved`, `TextChanged`).
- Read buffer content in one call: `vim.api.nvim_buf_get_lines(buf, start, end, strict)`. Do not call it once per line.
- `vim.api.nvim_buf_is_valid` and `vim.api.nvim_win_is_valid` are cheap; use them before operations that require a live handle, but do not repeat them in the same scope.
- Cache repeated table field lookups in a local variable inside loops to avoid repeated hash traversals
- Prefer `vim.api.nvim_chan_send` over `vim.fn.chansend` for terminal channel I/O.
- Flag any O(n²) or repeated work (e.g., scanning the full session list inside another loop) and suggest lifting it outside the loop or using a lookup table.
- Validate suspected performance issues with profiling or a concrete benchmark before assuming they matter at plugin scale.
