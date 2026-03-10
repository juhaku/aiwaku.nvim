# aiwaku.nvim — Feature Research Report

## Context

`aiwaku.nvim` runs a user-chosen CLI AI tool (Claude Code, Gemini CLI, aider, etc.) inside a
dedicated tmux session and shows that session as a persistent sidebar terminal inside Neovim.
This document records the feature research performed on the plugin and the detailed
implementation plans for the four must-have features that were subsequently implemented.

---

## Research: Feature Opportunities

### What the plugin already does well

- Persistent sidebar toggling (open/close without killing the AI session)
- Multiple named sessions with a picker (`select_session`)
- Visual selection → AI with an optional prompt prefix (`send_selection`)
- LSP code-action menu integration via null-ls/none-ls
- Config-driven keymaps for both normal and terminal mode
- `rename_session` / `clear_context` / `new_session` lifecycle operations

### Feature space explored

The research evaluated features across three categories:

| Category | Examples | Ease | Relativity |
|---|---|---|---|
| **Buffer/file sending** | Send entire file, send named buffer | Easy — extends `send_selection` | Very high — daily use |
| **File navigation** | Open AI-referenced file in a tab | Medium — needs path parsing | Very high — constant friction point |
| **Statusline integration** | Show active session name | Very easy — pure getter | High — orientation aid |
| **Terminal UX keymaps** | Clear context from inside sidebar | Trivial — keymap + existing function | High — avoids mode switch |
| **Diff/patch workflow** | Apply AI-generated patch via `patch` | Hard — needs robust diff parsing | Medium |
| **Project context** | Auto-inject `README.md` / git log | Medium — needs lifecycle hooks | Medium |
| **Conversation history** | Save/restore tmux scrollback | Hard — tmux capture-pane quirks | Low |
| **Floating terminal** | Alternative to sidebar split | Easy — `nvim_open_win` | Low — sidebar is the point |

### The `$NVIM` socket problem and solution

Neovim sets `$NVIM=v:servername` in the environment of every `jobstart()` child process.
However, tmux's **default `update-environment` list does not include `NVIM`**, so any
new window or pane opened *inside* the tmux session loses the socket and cannot call back
into Neovim via `nvim --server "$NVIM" --remote-tab <file>`.

**Solution:** `tmux new-session` accepts `-e VAR=value` to seed an environment variable for
the entire session (supported since tmux 3.0, already the stated minimum). Injecting
`-e NVIM=<socket>` at session creation time makes the socket available in all windows and
panes without requiring any user-side tmux configuration.

This unlocks the shell-side workflow:

```sh
nvim --server "$NVIM" --remote-tab src/parser.lua
```

### Must-have features identified

1. **`send_buffer(prompt?)`** — send the entire current buffer (with filename/filetype header)
2. **`open_cword_in_tab()`** — open an AI-referenced file path (with `:line`/`:line:col`) in a new tab
3. **`session_name()`** — statusline getter returning the display name of the active session
4. **`<C-a>c` terminal keymap** — clear context from inside the sidebar without switching modes

---

## Implementation Plan: `send_buffer()`

### Function signature

```lua
---@param prompt? string Optional prompt prefix prepended before the buffer content
M.send_buffer = function(prompt)
```

**Location:** `lua/aiwaku/selection.lua` — added after `send_selection`, before `return M`.

### Design

- `nvim_buf_get_lines(bufnr, 0, -1, false)` fetches all lines.
- Header format: `File: <path> (<filetype>)\n` — gives the AI filename and language
  without imposing Markdown code-fences that some CLI tools misinterpret.
- Unnamed buffers display as `<unnamed>`.
- Buffers with no filetype show `unknown`.
- The empty-buffer guard catches both a zero-row lines table and a single empty string.
- The channel-send tail (`find_session → win_visible → open_session → session_bufnrs →
  terminal_job_id → nvim_chan_send`) mirrors `send_selection` exactly, preserving the
  auto-open side effect.

### Error handling

| Condition | Behaviour |
|---|---|
| `setup()` not called | `ERROR` notification + early return |
| Buffer is empty | `WARN` notification + early return |
| No active session | `WARN` notification + early return |
| Session buffer not cached | `WARN` notification + early return |
| Terminal job channel missing | `WARN` notification + early return |
| Unnamed buffer | Graceful — sends with `<unnamed>` header |

### Keymap

`<leader>ab` (normal mode) — mnemonic: **a**i **b**uffer.  
No visual-mode keymap — `send_buffer` always operates on the whole buffer.

### LSP code actions

Two new entries with `buffer = true`:

```lua
{ title = "AI: send this file", buffer = true },
{ title = "AI: explain this file", prompt = "explain this file:", buffer = true },
```

`lsp-code-actions.lua` dispatches to `send_buffer(action.prompt)` when
`action_def.buffer` is true, otherwise falls through to `send_selection`.

### Types

`Aiwaku.LspCodeAction` gains:

```lua
---@field buffer? boolean  When true, sends the entire buffer instead of the visual selection
```

### Files changed

| File | Change |
|---|---|
| `lua/aiwaku/selection.lua` | Add `M.send_buffer` |
| `lua/aiwaku/init.lua` | `M.send_buffer = selection.send_buffer` re-export |
| `lua/aiwaku/config.lua` | `<leader>ab` keymap + two `buffer = true` LSP actions |
| `lua/aiwaku/lsp-code-actions.lua` | Dispatch to `send_buffer` when `action.buffer` |
| `lua/aiwaku/types.lua` | `buffer? boolean` on `Aiwaku.LspCodeAction` |
| `README.md` / `doc/aiwaku.nvim.txt` | Features, keymap table, API table, LSP table, new subsection |

---

## Implementation Plan: `open_cword_in_tab()` + `$NVIM` propagation

### Part A — `$NVIM` socket fix in `tmux.lua`

Replace `new_session_cmd()`:

```lua
-- BEFORE
function M.new_session_cmd(name, cmd)
    return "tmux new-session -s " .. vim.fn.shellescape(name) .. " " .. vim.fn.shellescape(cmd)
end

-- AFTER
function M.new_session_cmd(name, cmd)
    local env_flag = ""
    local socket = vim.v.servername
    if socket and socket ~= "" then
        env_flag = " -e NVIM=" .. vim.fn.shellescape(socket)
    end
    return "tmux new-session -s " .. vim.fn.shellescape(name) .. env_flag .. " " .. vim.fn.shellescape(cmd)
end
```

The flag is omitted when the socket is empty (headless / test mode safety). No other
modules are touched — all tmux shell construction stays in `tmux.lua`.

### Part B — `M.open_cword_in_tab()` in `init.lua`

```lua
function M.open_cword_in_tab()
    local word = vim.fn.expand("<cWORD>")
    if word == "" then return end

    local path = word
    local line = nil
    local p, l = word:match("^(.-):(%d+):%d+$")
    if p then
        path, line = p, tonumber(l)
    else
        p, l = word:match("^(.-):(%d+)$")
        if p then path, line = p, tonumber(l) end
    end

    if vim.fn.filereadable(path) == 0 then
        local rel = vim.fn.getcwd() .. "/" .. path
        if vim.fn.filereadable(rel) == 1 then
            path = rel
        else
            vim.notify("[aiwaku] File not found: " .. path, vim.log.levels.WARN)
            return
        end
    end

    vim.cmd("tabedit " .. vim.fn.fnameescape(path))
    if line then vim.api.nvim_win_set_cursor(0, { line, 0 }) end
end
```

**Pattern notes:** `^(.-):(%d+):%d+$` and `^(.-):(%d+)$` use Lua's non-greedy `.-` to
capture the path portion. `<cWORD>` (capital) includes slashes and dots within the
word, necessary for file paths.

### Error handling

| Situation | Behaviour |
|---|---|
| `<cWORD>` is empty | silent return |
| File not found (absolute or relative) | `WARN` notification + return |
| Readable, no line number | opens tab, cursor at top |
| Readable, `:line` suffix | opens tab, cursor jumps to line |
| Readable, `:line:col` suffix | opens tab, cursor jumps to line (col ignored) |

### Terminal keymap

`<C-o>` — `"<C-\\><C-n><Cmd>lua require('aiwaku').open_cword_in_tab()<CR>"`

The `<C-\\><C-n>` prefix exits terminal mode before executing, consistent with
all other `terminal_keymaps` entries that call into the Lua API.

### Files changed

| File | Change |
|---|---|
| `lua/aiwaku/tmux.lua` | Add `-e NVIM=` flag to `new_session_cmd()` |
| `lua/aiwaku/init.lua` | Add `M.open_cword_in_tab()` function |
| `lua/aiwaku/config.lua` | Add `<C-o>` terminal keymap |
| `README.md` / `doc/aiwaku.nvim.txt` | Keymap table, API table, new subsection, new section 9 |

---

## Implementation Plan: `session_name()`

### API design decision

Three options were evaluated:

| Option | Signature | Decision |
|---|---|---|
| A — stripped name only | `M.session_name() → string\|nil` | ✅ **Chosen** |
| B — raw boolean param | `M.session_name(raw?) → string\|nil` | ✗ boolean flag anti-pattern |
| C — two return values | `local display, raw = M.session_name()` | ✗ surprising for a getter |

**Rationale for Option A:** The function is explicitly a statusline/winbar getter —
display is its only job. The raw `ai-` prefix is an internal convention; callers needing
it for tmux operations use internal APIs. YAGNI applies: a `raw` parameter can be added
later without breaking callers.

### Implementation

```lua
---@return string|nil
function M.session_name()
    if not state.current_session then
        return nil
    end
    return state.current_session:gsub("^ai%-", "")
end
```

**Notes:**
- No `state.config` nil-guard needed — `current_session` is nil before `setup()` anyway.
- No `state.busy` guard — pure synchronous read, no async interaction.
- No `vim.notify` — statuslines call this on every render; notifications would spam.
- Lua pattern `"^ai%-"` escapes `-` and anchors to start of string.
- Safe to call before `setup()` (returns nil, does not error).

### Statusline examples

**lualine:**

```lua
{
  function() return " " .. (require("aiwaku").session_name() or "") end,
  cond = function() return require("aiwaku").session_name() ~= nil end,
}
```

**Plain `vim.o.statusline`:**

```lua
_G.AiwakuStatusline = function()
  local name = require("aiwaku").session_name()
  return name and (" " .. name) or ""
end
vim.o.statusline = "%{%v:lua.AiwakuStatusline()%} %f %=%l:%c"
```

### Files changed

| File | Change |
|---|---|
| `lua/aiwaku/init.lua` | Add `M.session_name()` function |
| `README.md` | New row in API table + `## Statusline Integration` section |
| `doc/aiwaku.nvim.txt` | New `session_name()` API entry + section 9 Statusline Integration |

---

## Implementation Plan: `<C-a>c` terminal keymap for `clear_context()`

### Overview

Bind `<C-a>c` in terminal mode to call the existing `clear_context()` function, allowing
users to reset the AI session without leaving the sidebar.

### Keymap entry

```lua
["<C-a>c"] = {
    command = "<C-\\><C-n><Cmd>lua require('aiwaku').clear_context()<CR>",
    description = "Aiwaku: clear context",
},
```

`<C-\\><C-n>` exits terminal mode first. `clear_context` is already exported on `M`
in `init.lua` — no export change needed.

### Re-entrancy safety

`clear_context()` begins with `if state.busy then return end`. This makes it safe
to bind as a terminal keymap:

- Concurrent async flows (`select_session`, `rename_session`) set `state.busy = true`;
  `clear_context` exits immediately if a picker or input prompt is open.
- `clear_context` itself is synchronous — the Lua VM completes it atomically before any
  callback can interleave, so no additional `busy` guard is needed inside the function.

### Files changed

| File | Change |
|---|---|
| `lua/aiwaku/config.lua` | Add `["<C-a>c"]` to `terminal_keymaps` |
| `README.md` | Add row to terminal keymaps table + full config snippet |
| `doc/aiwaku.nvim.txt` | Add line to keymaps section + config defaults block |

---

## Summary: All Four Features

| Feature | New public API | Default keymap | Other files touched |
|---|---|---|---|
| Send buffer | `send_buffer(prompt?)` | `<leader>ab` (normal) | `selection.lua`, `lsp-code-actions.lua`, `types.lua` |
| Open file from AI output | `open_cword_in_tab()` | `<C-o>` (terminal) | `tmux.lua` (socket fix) |
| Session name getter | `session_name()` | — (statusline getter) | — |
| Clear context keymap | — (existing `clear_context`) | `<C-a>c` (terminal) | — |

All features were implemented on branch `feature/must-have-features` (PR #6).
