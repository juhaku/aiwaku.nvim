---
applyTo: "**/*"
---

# Context instructions (applies to all files)

Purpose

- Quickly capture short, actionable lessons when code generation and review misalign.

Scope

- Applies to all contributors and automated agents.

When to apply

- Whenever review findings, validation failures, or reviewer feedback differ from generated code, or a recurring mistake appears.

Process (short)

1. Detect
   - One-line symptom: where (file/PR) and why it's a problem.

2. Review and verify
   - Always perform a focused review of the generated change and run the repository's existing validation commands before finalizing changes.
   - If the repository does not define dedicated automation, do a manual diff review plus at least one concrete targeted verification step for the change (for example, `git diff --check` for docs/config edits or a load-time smoke check for Neovim Lua changes).

3. Record
   - Add a short entry under .github/instructions/ including:
     - What: one-line summary
     - Where: file paths and PR number
     - Diff/fix: paste the failing diff or the minimal fix
     - Why: brief explanation of the root cause
     - Verification: one-line check to confirm the fix
   - Keep entries concise and code-linked.

4. Update PR/commit
   - Append the diff/fix and a short description to the PR body or commit message, following the Git workflow conventions in `.github/copilot-instructions.md`, and reference the instruction entry.

5. Automated agents
   - If an automated agent generates code, it must review the result and verify it with the repository's available validation steps before finalizing changes.
   - If generated code produces errors (syntax/runtime/test failures) or requires iterative guidance (e.g., re-prompting, partial fixes) to reach a correct result, record:
     - Error: concise error messages or failing test names/log snippets
     - Attempts: prompts or steps used to guide/fix the code
     - Final diff/fix: the minimal changes that fixed the problem
     - Verification: how the fix was validated (tests run, lint, manual check)
   - Append the diff/fix and the above details to the instruction entry and re-run the relevant review and validation steps; do not merge until verification passes.
   - Store a concise memory/fact for future automation when relevant.

Verification

- Re-run the relevant review and validation steps, confirm the generated code matches the reviewed code, and mark the instruction entry verified.

Tone

- Short, example-driven, and anchored to file paths. Do not open issues by default — record and verify first.

These instructions exist to reduce repeated review failures by ensuring diffs, fixes, and explanations are preserved and discoverable.

---

## Recorded lessons

### Redundant guard in callee when all call sites guarantee validity

- **What:** Added a defensive `buf_alive` + `session_name` guard inside `terminal.set_buf_name` even though every call site already guarantees a live buffer and a non-nil name.
- **Where:** `lua/aiwaku/terminal.lua` — `set_buf_name`; `feature/sidebar-bufname-session` branch.
- **Diff/fix:**

  ```lua
  -- Before (redundant guard)
  function M.set_buf_name(bufnr, session_name)
    if not M.buf_alive(bufnr) or not session_name then
      return
    end
    vim.api.nvim_buf_set_name(bufnr, "aiwaku://" .. session_name)
  end

  -- After (trust call-site invariants)
  function M.set_buf_name(bufnr, session_name)
    vim.api.nvim_buf_set_name(bufnr, "aiwaku://" .. session_name)
  end
  ```

- **Why:** `new_session` and `open_session` both guard with `if new_buf == 0 then return end` before calling `set_buf_name`. `rename_session` reads `state.session_bufnrs[new_name]` which was just migrated from a live-session buffer. No call path reaches `set_buf_name` with an invalid buffer or nil name, so the guard is dead code that obscures the real invariants.
- **Verification:** Trace all call sites of `set_buf_name` and confirm each has an earlier validity guarantee before the call.

---

### LuaJIT disallows a label as the last statement in a block

- **What:** Used `goto continue` / `::continue::` pattern in a `for` loop where the label was the last statement before `end`; LuaJIT rejects this at load time.
- **Where:** `lua/aiwaku/session.lua` — `restore_session()`; session-restore feature.
- **Error:**
  ```
  lua/aiwaku/session.lua:389: unexpected symbol near '::'
  ```
- **Diff/fix:** Remove `goto`/label entirely; restructure the loop body with nested `if`/`else` instead:

  ```lua
  -- Before (invalid in LuaJIT)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local session_name = name:match(...)
    if not session_name then goto continue end
    -- ... handle match ...
    return
    ::continue::   -- ← syntax error: label cannot be last statement in block
  end

  -- After (idiomatic, LuaJIT-safe)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local session_name = name:match(...)
    if session_name then
      -- ... handle match ...
      return
    end
  end
  ```

- **Why:** LuaJIT (Lua 5.1 + `goto` extension) does not allow a label as the final statement in a block. The system `luac` tool also rejects it but for a different reason (no `goto` support at all in Lua 5.1). Always validate with `nvim --headless` rather than `luac`.
- **Verification:** `nvim --headless -c 'lua local ok, err = loadfile("lua/aiwaku/session.lua"); print(ok and "OK" or err)' -c 'qa!'`

---

### Ghost buffer not deleted after sidebar window reconnect

- **What:** When restoring a visible sidebar, `open_session` replaces the ghost buffer in the window with a live terminal buffer, but the ghost buffer was never deleted — left as orphaned noise in `:ls`.
- **Where:** `lua/aiwaku/session.lua` — `restore_session()`, `ghost_win` branch; session-restore feature.
- **Diff/fix:**
  ```lua
  -- After open_session replaces the ghost buffer in the window:
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  ```
- **Why:** The `else` branch (hidden sidebar) correctly deleted the ghost buffer, but the `ghost_win` branch forgot to. Asymmetric cleanup.
- **Verification:** After restore, `:ls` should show no dead `aiwaku://` buffer entries.

---

### `stopinsert` must be skipped when the sidebar was the focused window

- **What:** `restore_session` unconditionally called `vim.cmd("stopinsert")` in `vim.schedule`, which exited terminal insert mode even when the user had the sidebar focused when they saved the session.
- **Where:** `lua/aiwaku/session.lua` — `restore_session()`, scheduled focus-restore callback; session-restore feature.
- **Diff/fix:**

  ```lua
  -- Before (always exits insert mode)
  vim.schedule(function()
    if vim.api.nvim_win_is_valid(prev_win) then
      vim.api.nvim_set_current_win(prev_win)
      vim.cmd("stopinsert")
    end
  end)

  -- After (skip when sidebar itself was focused)
  vim.schedule(function()
    if prev_win ~= ghost_win and vim.api.nvim_win_is_valid(prev_win) then
      vim.api.nvim_set_current_win(prev_win)
      vim.cmd("stopinsert")
    end
  end)
  ```

- **Why:** `prev_win` is captured before `open_session` runs. If the sidebar was focused, `prev_win == ghost_win`. Returning to it and calling `stopinsert` would wrongly drop the user out of terminal insert mode.
- **Verification:** With sidebar focused, save + restore session; terminal should remain in insert mode.
