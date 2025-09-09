# replacer.nvim

![version](https://img.shields.io/badge/version-0.2-blue.svg)
![State](https://img.shields.io/badge/status-beta-orange.svg)
![Lazy.nvim compatible](https://img.shields.io/badge/lazy.nvim-supported-success)
![Neovim](https://img.shields.io/badge/Neovim-0.9+-success.svg)
![Lua](https://img.shields.io/badge/language-Lua-yellow.svg)

Project-wide search-and-replace with ripgrep, an interactive picker (fzf-lua or Telescope), live preview, and precise, bottom-up application of changes.

Structure and sectioning follow the same style as a prior plugin README for consistency.&#x20;

---

* [Features](#features)
* [Demo](#demo)
* [Roadmap](#roadmap)
* [Requirements](#requirements)
* [Installation](#installation)

  * [With Lazy.nvim](#with-lazynvim)
* [Configuration](#configuration)

  * [Available Options](#available-options)
* [Usage](#usage)

  * [Picker Keymaps](#picker-keymaps)
  * [Command Syntax](#command-syntax)
  * [Programmatic API](#programmatic-api)
* [Safety & Notes](#safety--notes)
* [Architecture Overview](#architecture-overview)
* [Development](#development)
* [License](#license)
* [Contribution](#contribution)

---

## Features

* Project-wide search using ripgrep `--json` for precise match coordinates
* Interactive selection via either `fzf-lua` or `telescope.nvim`
* Live context preview around each match
* Replace only the selected occurrences; or replace all at once
* Bottom-up in-buffer edits to avoid offset shift bugs
* Optional write-to-disk on apply (or keep changes unsaved)
* Literal mode by default; Regex mode opt-in
* Strong EmmyLua annotations and type hints for LuaLS
* Clean, modular code layout (search, apply, pickers, command, config)

---

## Demo

Replace across the current working directory, preview hits, select some, apply:

```
:Replace foo bar cwd
```

Replace everything without opening a picker:

```
:Replace foo bar cwd All
```

Delete matches (empty replacement):

```
:Replace "old phrase" "" %
```

---

## Roadmap

* [x] Non-interactive “All” mode via `:Replace ... All`
* [x] Backend switch: `engine = "fzf"` or `"telescope"`
* [x] Confirm-all guard and write/no-write switch
* [x] Per-match preview and robust bottom-up edits
* [ ] Optional diff-style preview (before/after)
* [ ] Regex escape helpers (when literal=false)
* [ ] Built-in help `:help replacer`

---

## Requirements

* Neovim 0.9 or newer
* ripgrep (`rg`) in `PATH`
* One picker:

  * `ibhagwan/fzf-lua`, or
  * `nvim-telescope/telescope.nvim` (+ `nvim-lua/plenary.nvim`)

---

## Installation

### With Lazy.nvim

Local development (using a local path):

```lua
{
  "StefanBartl/replacer",
  name = "replacer.nvim",
  main = "replacer",
  opts = {
    engine = "fzf",            -- "fzf" | "telescope"
    write_changes = true,      -- write buffers after replace
    confirm_all = true,        -- ask before replacing all
    preview_context = 3,       -- lines of context in preview
    hidden = true,             -- include dotfiles
    git_ignore = true,         -- respect .gitignore
    exclude_git_dir = true,    -- skip .git/ explicitly
    literal = true,            -- fixed-strings by default
    smart_case = true,         -- ripgrep -S
    fzf = {                    -- extra fzf-lua options (optional)
      winopts = { width = 0.85, height = 0.70 },
    },
    telescope = {              -- extra telescope options (optional)
      layout_config = { width = 0.85, height = 0.70 },
    },
  },
}
```

---

## Configuration

Minimal:

```lua
require("replacer").setup({})
```

Full example:

```lua
require("replacer").setup({
  engine = "telescope",
  write_changes = false,
  confirm_all = true,
  preview_context = 4,
  hidden = true,
  git_ignore = true,
  exclude_git_dir = true,
  literal = true,
  smart_case = true,
  telescope = { layout_config = { width = 0.9, height = 0.8 } },
})
```

### Available Options

Plaintext table:

engine             string     Picker backend: "fzf" | "telescope"
write\_changes      boolean    Write modified buffers on apply (true) or keep unsaved (false)
confirm\_all        boolean    Ask confirmation before replacing all matches at once
preview\_context    integer    Context lines shown in preview around the hit
hidden             boolean    Include dotfiles (`--hidden`)
git\_ignore         boolean    Respect .gitignore (false → `--no-ignore`)
exclude\_git\_dir    boolean    Exclude `.git` directory explicitly (`--glob !.git`)
literal            boolean    Literal search (`--fixed-strings`); set false for regex mode
smart\_case         boolean    Smart-case (`-S`)
fzf                table?     Extra options for `fzf-lua` (merged into picker opts)
telescope          table?     Extra options for Telescope picker (theme/layout)

---

## Usage

### Picker Keymaps

fzf-lua:

* Enter: apply to the currently selected entries
* Tab: toggle selection
* Ctrl-A: replace all matches at once (confirmation depends on `confirm_all`)

Telescope:

* Enter: apply to the highlighted entry
* Ctrl-A: replace all matches at once (confirmation depends on `confirm_all`)

### Command Syntax

```
:Replace {old} {new} {scope?} {All?}
```

Parameters:

old       literal (or regex if configured) text to search for
new       replacement text; empty string deletes matches
scope     one of:
%       current buffer (file-backed)
cwd     current working directory
.       alias for cwd <path>  explicit file or directory
All       optional token; when present, runs non-interactive “replace all” (no picker)

Examples:

```
:Replace foo bar cwd
:Replace "very old" "brand new" ./src
:Replace foo "" %          "delete matches in current file"
:Replace foo bar cwd All   "apply without opening the picker"
```

### Programmatic API

```lua
local replacer = require("replacer")

-- Setup once (e.g. in your plugin manager config)
replacer.setup({ engine = "fzf", write_changes = true })

-- Run ad-hoc from Lua:
replacer.run("foo", "bar", "cwd", false)  -- open picker
replacer.run("foo", "bar", "cwd", true)   -- replace all (non-interactive)
```

---

## Safety & Notes

* Edits are applied bottom-up per file to avoid index shift issues.
* Each occurrence is verified against the original text before editing; mismatches are skipped and reported.
* When `write_changes = false`, buffers stay modified—review and `:write` manually or use VCS hunk staging.
* Literal mode is the default; for regex, set `literal = false` and provide proper patterns.
* ripgrep must be installed and discoverable via `PATH`.

---

## Architecture Overview

```
replacer/
│
├── init.lua               → public API (setup, run), engine dispatch
├── config.lua             → defaults + deep-merge resolution
├── command.lua            → :Replace parsing + scope resolution
├── rg.lua                 → ripgrep --json integration
├── apply.lua              → bottom-up edits, optional writes
├── pickers/
│   ├── fzf.lua            → fzf-lua UI (preview, Ctrl-A = replace all)
│   └── telescope.lua      → Telescope UI (preview, Ctrl-A = replace all)
└── types/                 → optional type stubs for LuaLS (if used)
```

---

## Development

* Repository layout follows standard `lua/<plugin_name>/...` convention for Lazy.nvim.
* Type hints use EmmyLua; LuaLS-friendly stubs are provided where helpful.
* To hack locally, add your repo via `dir = "/path/to/replacer"`.
* Typical debug flow:

  * `:Replace foo bar cwd`
  * In picker, inspect preview; Tab to select specific hits; Enter to apply
  * Ctrl-A to replace all with confirmation
  * Set `write_changes=false` to review changes before writing

---

## License

[MIT](./License)

---

## Contribution

Issues and PRs are welcome. If you have ideas for diff previews, additional picker actions, or regex helpers, open a discussion.

