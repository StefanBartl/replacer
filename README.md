# replacer.nvim

![version](https://img.shields.io/badge/version-0.4-blue.svg)
![State](https://img.shields.io/badge/status-beta-orange.svg)
![Lazy.nvim compatible](https://img.shields.io/badge/lazy.nvim-supported-success)
![Neovim](https://img.shields.io/badge/Neovim-0.9+-success.svg)
![Lua](https://img.shields.io/badge/language-Lua-yellow.svg)

Project-wide search-and-replace with ripgrep, an interactive picker (fzf-lua or Telescope), live preview, and precise application of changes.

---

* [Features](#features)
* [Roadmap](#roadmap)
* [Usage](#usage)
  * [Command Syntax](#command-syntax)
  * [Picker Keymaps](#picker-keymaps)
* [Installation](#installation)
  * [With Lazy.nvim](#with-lazynvim)
* [Configuration](#configuration)
* [Safety & Notes](#safety--notes)
* [Development](#development)
* [License](#license)
* [Disclaimer](#disclaimer)
* [Feedback](#feedback)

---

## Usage

### Command Syntax

```sh
:Replace {old} {new} {scope?} {All?}
```

Parameters:

old       **required** literal (or regex if configured) text to search for
new       **required** replacement text; empty string deletes matches
scope     **optional:** one of:
→  `%`         current buffer (file-backed)
→  `cwd`       current working directory
→  `.`         alias for cwd
→  `<path>`    explicit file or directory
All       **optional:** token; when present, runs non-interactive “replace all” (no picker)

Arguments can now include **quotes** or **escaped quotes**:

```sh
:Replace "foo bar" "baz qux" %
:Replace \"test\" ok %
:Replace \"test\" \'test\' %
```

These examples demonstrate that:

* Quoted tokens are parsed as single arguments.
* Escaped quotes (`\"` or `\'`) are recognized both inside and outside quoted tokens.
* Literal quote characters can be searched and replaced.

---

### Picker Keymaps

After picker opened:

**fzf-lua:**

* Enter: apply to the currently selected entries
* Tab: toggle selection
* Ctrl-A: replace all matches at once (confirmation depends on `confirm_all`)

**Telescope:**

* Enter: apply to the highlighted entry
* Ctrl-A: replace all matches at once (confirmation depends on `confirm_all`)

---

## Features

* Project-wide search using ripgrep `--json` for precise match coordinates
* Interactive selection via either `fzf-lua` or `telescope.nvim`
* Live context preview around each match
* Replace only the selected occurrences; or replace all at once
* Handles multiple matches per line robustly (each occurrence selectable)
* Bottom-up in-buffer edits to avoid offset shift bugs
* Literal mode by default; Regex mode opt-in
* Optional write-to-disk on apply (or keep changes unsaved)
* Configurable syntax highlighting in Telescope preview
* Strong EmmyLua annotations and type hints for LuaLS
* Clean, modular code layout (search, apply, pickers, command, config)
* Supports escaped quotes and backslashes in command arguments

---

## Roadmap

* [x] Non-interactive “All” mode via `:Replace ... All`
* [x] Backend switch: `engine = "fzf"` or `"telescope"`
* [x] Confirm-all guard and write/no-write switch
* [x] Quote and escape support for command arguments
* [x] Multiple occurrences per line handled correctly
* [x] Configurable highlighting for Telescope previews
* [ ] fzf-lua highlight parity
* [ ] vimgrep implementation
* [ ] Optional diff-style preview (before/after)
* [ ] Built-in help `:help replacer`
* [ ] Health-Module to provide `:checkhealth`-usercommand

---

## Installation

**Requirements:**

* Neovim 0.9 or newer
* ripgrep (`rg`) in `PATH`
* One picker:
  * `nvim-telescope/telescope.nvim` (+ `nvim-lua/plenary.nvim`) (default)
  * `ibhagwan/fzf-lua`

### With Lazy.nvim

```lua
{
  "StefanBartl/replacer",
  name = "replacer.nvim",
  main = "replacer",
  opts = {
    engine = "telescope",      -- "fzf" | "telescope"
    write_changes = true,      -- write buffers after replace
    confirm_all = true,        -- ask before replacing all
    preview_context = 3,       -- lines of context in preview
    hidden = true,             -- include dotfiles
    git_ignore = true,         -- respect .gitignore
    exclude_git_dir = true,    -- skip .git/ explicitly
    literal = true,            -- fixed-strings by default
    smart_case = true,         -- ripgrep -S
    preview_marker = "│",      -- custom marker in preview highlight
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

**Available Options:**

| Option          | Type    | Description                                                    |
| --------------- | ------- | -------------------------------------------------------------- |
| engine          | string  | Picker backend: `"fzf"` / `"telescope"`                        |
| write_changes   | boolean | Write modified buffers on apply (true) or keep unsaved (false) |
| confirm_all     | boolean | Ask confirmation before replacing all matches at once          |
| preview_context | integer | Context lines shown in preview around the hit                  |
| preview_marker  | string  | Custom marker/prefix in preview highlighting                   |
| hidden          | boolean | Include dotfiles (`--hidden`)                                  |
| git_ignore      | boolean | Respect `.gitignore` (false → `--no-ignore`)                   |
| exclude_git_dir | boolean | Exclude `.git` directory explicitly (`--glob !.git`)           |
| literal         | boolean | Literal search (`--fixed-strings`); set false for regex mode   |
| smart_case      | boolean | Smart-case (`-S`)                                              |
| fzf             | table?  | Extra options for `fzf-lua` (merged into picker opts)          |
| telescope       | table?  | Extra options for Telescope picker (theme/layout)              |

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
  preview_marker = "│",
  hidden = true,
  git_ignore = true,
  exclude_git_dir = true,
  literal = true,
  smart_case = true,
  telescope = { layout_config = { width = 0.9, height = 0.8 } },
})
```

---

## Safety & Notes

* Edits are applied bottom-up per file to avoid index shift issues.
* Each occurrence is verified against the original text before editing; mismatches are skipped and reported.
* When `write_changes = false`, buffers stay modified—review and `:write` manually or use VCS hunk staging.
* Literal mode is the default; for regex, set `literal = false` and provide proper patterns.
* ripgrep must be installed and discoverable via `PATH`.

---

## Development

* Repository layout follows standard `lua/<plugin_name>/...` convention for Lazy.nvim.
* Type hints use EmmyLua; LuaLS-friendly stubs are provided where helpful.
* Local hacking via `dir = "/path/to/replacer"`.
* Typical debug flow:
  * `:Replace foo bar cwd`
  * In picker, inspect preview; Tab to select specific hits; Enter to apply
  * Ctrl-A to replace all with confirmation
  * Set `write_changes=false` to review changes before writing

---

## License

[MIT](./License)

---

## Disclaimer

ℹ️ This plugin is under active development – some features are planned or experimental.
Expect changes in upcoming releases.

---

## Feedback

Your feedback is very welcome!

Please use the [GitHub issue tracker](https://github.com/StefanBartl/replacer/issues) to:

* Report bugs
* Suggest new features
* Ask questions about usage
* Share thoughts on UI or functionality

For general discussion, feel free to open a [GitHub Discussion](https://github.com/StefanBartl/replacer/discussions).

If you find this plugin helpful, consider giving it a ⭐ on GitHub — it helps others discover the project.

---
