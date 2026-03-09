---@class Aiwaku.Keymap
---@field command fun()|string      function() end command or keymap string of operation to execute
---@field description string        Description of the command

---@alias Aiwaku.Keymap.Mode "v" | "i" | "n" | "t" Keymap mode used to map the command with

---@class Aiwaku.LspCodeAction
---@field title string              Title shown in the LSP code action menu
---@field prompt? string            Optional prompt prefix prepended before the content
---@field buffer? boolean           When true, sends the entire buffer instead of the visual selection

---@class Aiwaku.Config
---@field cmd string|string[]       CLI command to run (default: "copilot")
---@field width integer             Sidebar column width (default: 80)
---@field position "right"|"left"   Which side to open (default: "right")
---@field keymaps {[Aiwaku.Keymap.Mode[]]: {[string]: Aiwaku.Keymap} } Map of default action keymaps
---@field lsp_code_actions Aiwaku.LspCodeAction[] Default LSP code actions exposed through null-ls/none-ls
---@field terminal_keymaps {[string]: Aiwaku.Keymap} Map of terminal buffer keymaps

---@class Aiwaku.Session
---@field name string    tmux session name (e.g. "ai-20260305234735-1234"); acts as the unique identifier
---@field created_at string tmux session creation time (human-readable string from tmux)

---@class Aiwaku.State
---@field current_session string|nil          Name of the currently active tmux session
---@field session_bufnrs { [string]: integer } Cache of tmux session name → nvim buffer number for reuse
---@field win_id integer|nil                  Window ID of the visible sidebar window (nil when hidden)
---@field config Aiwaku.Config|nil            Resolved configuration (set by setup())
---@field busy boolean                        True while an async operation is in flight; prevents re-entrant calls

return {}
