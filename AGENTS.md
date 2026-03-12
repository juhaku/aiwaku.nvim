# AGENTS.md

Guidance for automated contributors working in this repository.

## Project overview

`aiwaku.nvim` is a Neovim plugin that runs a user-selected CLI AI tool inside a tmux session and shows it in a persistent sidebar terminal. The plugin is tool-agnostic: users can configure `copilot`, `claude`, `opencode`, `aider`, or another CLI tool.

Key runtime requirements:

- `tmux >= 3.0`
- `Neovim >= 0.10`
- `nvim-lua/plenary.nvim`
- Optional integrations: `stevearc/dressing.nvim`, `nvimtools/none-ls.nvim`

## Validation expectations

This repository does not currently define dedicated build, test, or lint commands.

- Do not invent new validation tooling just for a change.
- For documentation-only edits, do a manual diff review and run `git diff --check`.
- For Lua changes, do a manual diff review plus at least one concrete targeted verification step when possible.
- Keep validation proportional to the change, and explicitly note when no automated test command exists.

## Repository layout

- `README.md` — primary user-facing documentation and setup guide.
- `doc/aiwaku.nvim.txt` — Vim help documentation. Keep it in sync with `README.md` for user-facing behavior.
- `lua/aiwaku/config.lua` — configuration defaults and command normalization logic.
- `lua/aiwaku/init.lua` — public API surface and setup entrypoint.
- `lua/aiwaku/state.lua` — shared runtime state singleton.
- `lua/aiwaku/session.lua` — session lifecycle orchestration.
- `lua/aiwaku/tmux.lua` — tmux command construction, shelling-out, and session parsing.
- `lua/aiwaku/window.lua` — sidebar split/window management.
- `lua/aiwaku/terminal.lua` — terminal buffer creation and terminal-local setup.
- `lua/aiwaku/send.lua` — dispatches visual selections and whole buffers into the active terminal job.
- `lua/aiwaku/lsp-code-actions.lua` — optional null-ls/none-ls integration.
- `lua/aiwaku/types.lua` — Lua type annotations used by the development workflow.
- `lua/aiwaku/words.lua` — word lists used for generated human-readable session names.
- `.github/copilot-instructions.md` — repo-specific working guidance.
- `.github/instructions/lua.instructions.md` — Lua-specific generation and review rules.
- `.github/instructions/context.instructions.md` — guidance for recording and verifying fixes when generated changes and review diverge.

## Architecture notes

- Public operations are exposed from `require("aiwaku")` in `lua/aiwaku/init.lua`.
- User config is merged with defaults during `setup()`.
- Sessions are tmux-backed and must keep the `ai-` prefix.
- Terminal buffers are cached per session and reused across toggles.
- `send_selection()` and `send_buffer()` ensure the target session exists and auto-open the sidebar when needed.
- `select_session()` and `rename_session()` are interactive async flows built with `plenary.async`.

## Repository conventions

- Preserve the `ai-` session-name prefix. Session discovery depends on it.
- Most public operations assume `require("aiwaku").setup()` has already run. If setup is missing, surface an explicit `vim.notify()` error rather than failing silently.
- User-facing notifications should use the `[aiwaku]` prefix and an explicit log level.
- Keep tmux-specific quoting and command construction inside `lua/aiwaku/tmux.lua`.
- Keep terminal-specific behavior inside `lua/aiwaku/terminal.lua`; do not spread tmux details into terminal management.
- Preserve the distinction around `state.busy`: it guards interactive flows like toggle/select/rename/clear, but not every public operation.
- Preserve config-driven keymaps. Normal/visual keymaps and terminal keymaps should not become hardcoded when a config-based pattern already exists.
- `cmd` intentionally supports `string`, `string[]`, and named tool definitions. Prefer the list form when adding or updating examples because it avoids shell quoting issues.
- `lsp-code-actions.lua` must remain safe to require when null-ls/none-ls is unavailable.
- Update `lua/aiwaku/types.lua` when public Lua shapes change instead of relying on ad-hoc assumptions in implementation files.

## Documentation rules

- Keep `README.md` and `doc/aiwaku.nvim.txt` in sync for user-facing configuration, keymaps, dependencies, commands, and behavior.
- If default config changes, update both docs in the same change.
- If API behavior changes, update both docs in the same change.

## Lua change guidance

For `**/*.lua`, follow `.github/instructions/lua.instructions.md`. In particular:

- Prefer the simplest correct change.
- Avoid unrelated refactors.
- Do not add redundant guards after an invariant is already established.
- Preserve accurate LuaDoc annotations for public module functions.
- Prefer idiomatic Neovim Lua APIs and explicit user-facing notifications.

## Review and fix-recording guidance

If generated code and review feedback diverge, follow `.github/instructions/context.instructions.md`:

- review the change,
- run the repository’s existing validation steps,
- record concise lessons under `.github/instructions/` when needed,
- and verify the final diff matches the reviewed result.

## Git workflow

- Do not automatically push changes.
- Do not automatically open a PR.
- Use focused branches such as `feature/...`, `fix/...`, or `chore/...`.
- Use conventional commit messages such as `docs(agents): add repository guidance`.
- Keep one logical change per commit.
- When creating commits, include the required co-author trailer:

  `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`

## Practical default

When in doubt, make the smallest correct change, preserve documented behavior, keep docs in sync, and prefer explicit verification over assumptions.
