# aiwaku.nvim

A Neovim plugin that brings any CLI AI tool into your editor as a persistent sidebar panel.

![aiwaku screenshot](screenshots/aiwaku.png)

aiwaku does not lock you into a specific AI tool. You point it at any command-line AI assistant — `copilot`, `claude`, `opencode`, `aider`, or anything else — and it runs it in a tmux session attached to a Neovim terminal split. Sessions survive window toggles, editor restarts, and workspace switches. Your conversation context is always one keymap away.

## Features

- **Tool-agnostic** — works with any CLI AI tool you configure
- **Persistent sessions** — backed by tmux; context survives toggling the panel or restarting Neovim
- **Multiple sessions** — create, switch, and rename sessions without losing context
- **Send visual selection** — send selected code (with optional prompt prefix) directly to the AI
- **LSP code actions** — send selections via the standard code action menu when null-ls is active
- **Sidebar layout** — opens as a left or right vertical split with configurable width
- **Async** — all tmux operations are non-blocking; the editor stays responsive
- **Clear context** — kill and restart a session in one command

## Requirements

### System

| Dependency | Purpose |
|---|---|
| [tmux](https://github.com/tmux/tmux) ≥ 3.0 | Session persistence and management |
| Neovim ≥ 0.10 | Required for `vim.system` and modern API |

> [!NOTE]
> aiwaku requires tmux (>= 3.0) to provide persistent sessions. If tmux is not installed or not available on your PATH, session features (create, resume, list) will not work. Install tmux or ensure it is accessible from Neovim before using aiwaku.

### Neovim plugins

| Plugin | Purpose |
|---|---|
| [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim) | Async job execution |
| [stevearc/dressing.nvim](https://github.com/stevearc/dressing.nvim) *(optional)* | Floating UI for `vim.ui.select`; without it Neovim falls back to the built-in command-line prompt. Other providers (e.g. telescope with the `ui-select` extension) also work. |
| [nvimtools/none-ls.nvim](https://github.com/nvimtools/none-ls.nvim) *(optional)* | LSP code actions integration |

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "juhaku/aiwaku.nvim",
  dependencies = {
        "nvim-lua/plenary.nvim",
        "stevearc/dressing.nvim", -- optional: floating UI for vim.ui.select (without it Neovim falls back to the built-in command-line prompt)
    },
  opts = { cmd = { "opencode" } } -- your CLI AI tool
}
```

## Setup

### Minimal

The only required option is `cmd` — the CLI AI command to run.

```lua
require("aiwaku").setup({
  cmd = { "opencode" },
})
```

`cmd` can be a list (recommended, avoids shell quoting issues) or a plain string:

```lua
cmd = { "/usr/local/bin/claude", "--model", "claude-3-5-sonnet" }
cmd = "aider --model gpt-4o"
```

<details>
<summary>Full default configuration</summary>

```lua
require("aiwaku").setup({
  -- CLI command to run inside the tmux session.
  -- Use a list to avoid shell quoting issues, or a plain string.
  cmd = { "copilot" },

  -- Sidebar width in columns.
  width = 80,

  -- Which side to open the sidebar on.
  position = "right", -- "right" | "left"

  -- Normal/visual mode keymaps.
  -- Key: mode list, Value: map of lhs -> { command, description }
  keymaps = {
    [{ "n" }] = {
      ["<leader>ai"] = {
        command = function() require("aiwaku").toggle() end,
        description = "Toggle Aiwaku",
      },
      ["<leader>an"] = {
        command = function() require("aiwaku").new_session() end,
        description = "Aiwaku: new session",
      },
      ["<leader>as"] = {
        command = function() require("aiwaku").select_session() end,
        description = "Aiwaku: select session",
      },
      ["<leader>ar"] = {
        command = function() require("aiwaku").rename_session() end,
        description = "Aiwaku: rename session",
      },
    },
    [{ "v" }] = {
      ["<leader>ai"] = {
        command = "<Esc><Cmd>lua require('aiwaku').send_selection()<CR>",
        description = "Aiwaku: send selection",
      },
    },
  },

  -- Keymaps active only inside the terminal buffer.
  terminal_keymaps = {
    ["<C-w>h"] = { command = "<C-\\><C-n><C-w>h", description = "Focus left" },
    ["<C-w>l"] = { command = "<C-\\><C-n><C-w>l", description = "Focus right" },
    ["<C-a>r"] = {
      command = "<C-\\><C-n><Cmd>lua require('aiwaku').rename_session()<CR>",
      description = "Aiwaku: rename session",
    },
  },
})
```

</details>

## Configuration Options

| Option | Type | Default | Description |
|---|---|---|---|
| `cmd` | `string \| string[]` | `{ "copilot" }` | CLI command to run in the tmux session |
| `width` | `integer` | `80` | Sidebar panel width in columns |
| `position` | `"right" \| "left"` | `"right"` | Side of the screen to open the panel |
| `keymaps` | `table` | see above | Normal/visual mode keymaps |
| `terminal_keymaps` | `table` | see above | Keymaps active inside the terminal buffer |

## Default Keymaps

### Normal mode

| Key | Action |
|---|---|
| `<leader>ai` | Toggle the AI sidebar (open/close) |
| `<leader>an` | Start a new session |
| `<leader>as` | Select from existing sessions |
| `<leader>ar` | Rename the current session |

### Visual mode

| Key | Action |
|---|---|
| `<leader>ai` | Send selected text to the AI |

### Terminal mode (inside the sidebar)

| Key | Action |
|---|---|
| `<C-w>h` | Move focus to the left window |
| `<C-w>l` | Move focus to the right window |
| `<C-a>r` | Rename the current session |


## LSP Code Actions

aiwaku ships a [null-ls](https://github.com/nvimtools/none-ls.nvim) source that exposes AI actions through the standard LSP code action menu (`:lua vim.lsp.buf.code_action()`).

### Setup

Register the source alongside your other null-ls sources:

```lua
local null_ls = require("null-ls")
null_ls.setup({
  sources = {
    require("aiwaku.lsp-code-actions"),
    -- your other sources...
  },
})
```

### Available actions

The following actions appear in the code action menu for any filetype when null-ls is active on the buffer:

| Action | Behaviour |
|---|---|
| **Send to Aiwaku** | Send selection without a prompt prefix |
| **AI: explain this code** | Prepend `"explain this code:"` before the selection |
| **AI: refactor this code** | Prepend `"refactor this code:"` before the selection |

Each action calls `send_selection()` internally, so the sidebar is opened automatically if it is not already visible.

> **Note:** null-ls (or its community fork [none-ls](https://github.com/nvimtools/none-ls.nvim)) must be installed and have an active client attached to the buffer for code actions to appear.

## API

All functions are available on the `require("aiwaku")` table after calling `setup()`.

| Function | Description |
|---|---|
| `setup(opts)` | Initialize the plugin with your configuration |
| `toggle()` | Open or close the sidebar |
| `new_session(name?)` | Create a new AI session (optional name) |
| `select_session()` | Open a picker to switch sessions |
| `rename_session()` | Rename the current session interactively |
| `clear_context()` | Kill the current session and start a fresh one |
| `send_selection(prompt?)` | Send the current visual selection to the AI (optional prompt prefix) |

### Sending selections with a prompt

You can call `send_selection` with a prefix to give the AI context:

```lua
-- From a keymap or command
require("aiwaku").send_selection("Explain this code:")
require("aiwaku").send_selection("Write tests for:")
require("aiwaku").send_selection("Refactor to be more idiomatic:")
```



## License

Licensed under [MIT](LICENSE) license at your option.

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in this plugin
by you, shall be licensed as MIT, without any additional terms or conditions.
