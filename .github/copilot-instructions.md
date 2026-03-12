# Copilot instructions for aiwaku.nvim

## Build, test, and lint

This repository does not define dedicated build, test, or lint commands today. There is no `Makefile`, test directory, CI workflow, or formatter/linter configuration in the repo.

- There is currently no automated full test command.
- There is currently no single-test command.
- There is currently no dedicated lint command.

Runtime requirements still matter for code changes:
- tmux >= 3.0 is required for session persistence and management.
- Neovim >= 0.10 is required by the documented plugin API and runtime usage.

## High-level architecture

`aiwaku.nvim` is a Neovim plugin that runs a user-chosen CLI AI tool inside a tmux session and shows that session in a persistent sidebar terminal.

- `lua/aiwaku/init.lua` is the public module surface. It re-exports the user API, deep-merges user options with `config.defaults`, registers configured keymaps, and installs the `BufEnter` autocmd that re-enters insert mode only for buffers marked with `vim.b[bufnr].aiwaku` and `buftype == "terminal"`.
- `lua/aiwaku/state.lua` is the shared runtime singleton. It stores resolved config, the active tmux session name, the visible sidebar window id, cached terminal buffers keyed by session name, and the `busy` re-entrancy guard.
- `lua/aiwaku/session.lua` is the lifecycle orchestrator. It owns toggle/create/open/select/rename/clear behavior, decides when to reuse a cached terminal buffer versus creating a new one, and coordinates `tmux.lua`, `window.lua`, and `terminal.lua`. `select_session()` and `rename_session()` are `plenary.async` UI flows; the rest of the session lifecycle is synchronous.
- `lua/aiwaku/tmux.lua` is the tmux boundary. Keep tmux shelling-out, shell escaping, and session parsing here rather than spreading tmux command construction across other modules.
- `lua/aiwaku/window.lua` owns sidebar split creation and sets `winfixwidth` so the sidebar does not get squashed by other splits.
- `lua/aiwaku/terminal.lua` owns terminal buffer creation and setup. It starts jobs with `vim.fn.jobstart(..., { term = true })`, stores the job id in `vim.b[bufnr].terminal_job_id`, marks buffers with `vim.b[bufnr].aiwaku = true`, applies `state.config.terminal_keymaps`, disables line numbers, and names buffers as `aiwaku://<cmd_basename>-<bufnr>`.
- `lua/aiwaku/selection.lua` is the path from a visual selection to the running terminal job. It extracts the exact visual range, optionally prepends a prompt, ensures the target session exists, auto-opens the sidebar if needed, and sends text over the terminal channel.
- `lua/aiwaku/lsp-code-actions.lua` is optional null-ls/none-ls integration layered on top of `selection.send_selection()`. It does a guarded `pcall(require, "null-ls")` at module load time and returns `{}` when null-ls is unavailable.

## Key conventions

- Session names must stay prefixed with `ai-`. Session discovery in `tmux.list_sessions()` filters by that prefix, and rename logic preserves it by letting the user edit only the suffix.
- Most public operations assume `require("aiwaku").setup()` has already run. Follow the existing pattern of checking `state.config` and surfacing a `vim.notify()` error instead of failing silently.
- User-facing notifications consistently use the `[aiwaku]` prefix and an explicit log level.
- `state.busy` is the re-entrancy guard for interactive flows. It is used by `toggle()`, `select_session()`, `rename_session()`, and `clear_context()`, but not by `new_session()` or `send_selection()`. Match that distinction intentionally when adding new operations.
- New picker/input flows should follow the existing `plenary.async` pattern used by `select_session()` and `rename_session()`.
- Terminal buffers are reused across toggles through `state.session_bufnrs`. If session lifecycle logic changes, keep tmux session state, current session tracking, and cached buffers in sync.
- `send_selection()` auto-opens the sidebar through `session.open_session()` when the window is hidden. Preserve that side effect so callers only need an active session, not a visible sidebar.
- The `keymaps` config uses Lua array tables as hash keys, for example `[{ "n" }] = { ... }`. `init.lua` iterates those keys with `pairs()` and passes the mode list directly to `vim.keymap.set(mode, lhs, ...)`.
- Terminal keymaps are config-driven rather than hardcoded in `terminal.lua`. The current defaults live in `lua/aiwaku/config.lua`; if they change, update both `README.md` and `doc/aiwaku.nvim.txt`.
- `cmd` intentionally accepts either `string` or `string[]`, but the documented preference is the list form because it avoids shell quoting issues. Preserve both forms when changing command handling.
- `tmux.new_session_cmd()` and `tmux.join_session_cmd()` return shell command strings, not argument arrays. Keep tmux quoting and command construction in `tmux.lua`, and keep `terminal.lua` unaware of tmux details.
- `lsp-code-actions.lua` must remain safe to require even when null-ls is not installed or loaded; preserve the guarded `pcall(require, "null-ls")` and early `return {}` behavior.
- Public configuration, dependencies, keymaps, and API behavior are documented in both `README.md` and `doc/aiwaku.nvim.txt`. Keep them in sync when user-facing behavior changes.
- Lua type annotations in `lua/aiwaku/types.lua` are part of the development workflow. Prefer updating those annotations instead of adding ad-hoc type assumptions in implementation files.

# Copilot Working Guidelines

## Lua Code Changes
- Follow the Lua Code Review Standards in `.github/instructions/lua.instructions.md`

## Git Workflow
- DO not automatically push changes.
- DO not automatically create a PR.
  - Always confirm first the commit message format and PR description.
- Always create feature branches with descriptive names.
- Branch naming: `feature/{description}` or `fix/{description}` or `chore/{description}` etc.
- Commit message format conventional: `type(scope): description`
- One logical change per commit
- Provide comprehensive PR descriptions: 
  - PR description should be prettily formatted.
  - The description should answer what is changed and why it's changed.
  - Use subtitles to separate chapters in longer message.
  - Use bullet points to describe a list of changes when applicable.
  - Use code samples when applicable to demonstrate new functionality.

## Tools Available
- GitHub MCP Server for PR creation and GitHub operations
- Git commands for local operations
