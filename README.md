# replacer.nvim

![version](https://img.shields.io/badge/version-0.2-blue.svg)
![State](https://img.shields.io/badge/status-beta-orange.svg)
![Lazy.nvim compatible](https://img.shields.io/badge/lazy.nvim-supported-success)
![Neovim](https://img.shields.io/badge/Neovim-0.9+-success.svg)
![Lua](https://img.shields.io/badge/language-Lua-yellow.svg)

Project-wide search-and-replace with ripgrep, an interactive picker (fzf-lua or Telescope), live preview, and precise application of changes.

______________________________________________________________________

- [Features](#features)
- [Roadmap](#roadmap)
- [Usage](#usage)
  - [Command Syntax](#command-syntax)
  - [Picker Keymaps](#picker-keymaps)
- [Features](#features)
- [Installation](#installation)
  - [With Lazy.nvim](#with-lazynvim)
- [Configuration](#configuration)
- [Safety & Notes](#safety--notes)
- [Development](#development)
- [License](#license)
- [Disclaimer](#license)
- [Feedback](#Feedback)

______________________________________________________________________

## Usage

### Command Syntax

**EBNF:**

```ebnf
ReplaceCmd  = ":Replace" [Bang] SP Params
Bang        = "!"                                     ; non-interactive (apply to all targets in scope)
Params      = [ModeFlag] Old SP New [SP Scope] [SP ConfirmFlag]
ModeFlag    = "--literal" | "-L" | "--regex" | "-R"
ConfirmFlag = "--confirm" | "--no-confirm"
Old         = <string>                                ; quote when needed
New         = <string>
Scope       = "%" | "cwd" | "." | <path>              ; default = opts.default_scope
SP          = <Space>
```

```sh
:Replace {old} {new} {scope?} {All?}
```

**Parameters:**

old **required** literal (or regex if configured) text to search for
new **required** replacement text; empty string deletes matches
scope **optional:** one of:
--> % current buffer (file-backed)
--> cwd current working directory
--> . alias for cwd <path> explicit file or directory
All **optional:** token; when present, runs non-interactive “replace all” (no picker)

Examples:

```sh
:Replace foo bar                             # opens picker to select replacing targets in cwd
:Replace foo bar %                           # opens picker to select replacing targets in current file
:Replace foo bar cwd                         # opens picker to select replacing targets in cwd
:Replace "very old" "brand new" ./src        # opens picker to select replacing targets in ./src
:Replace foo "" %                            # opens picker to select matches to deletion in current file
:Replace foo bar cwd All                     # apply replacements without opening the picker
```

**After picker opened:**

fzf-lua:
\*Tab: toggle selection

- Enter: apply to the currently selected entries
- Ctrl-A: replace all matches at once (confirmation depends on `confirm_all`)

Telescope:

- Enter: apply to the highlighted entry
- Ctrl-A: replace all matches at once (confirmation depends on `confirm_all`)

______________________________________________________________________

## Features

- Project-wide search using ripgrep `--json` for precise match coordinates
- Interactive selection via either `fzf-lua` or `telescope.nvim`
- Live context preview around each match
- Replace only the selected occurrences; or replace all at once
- Bottom-up in-buffer edits to avoid offset shift bugs
- Optional write-to-disk on apply (or keep changes unsaved)
- Literal mode by default; Regex mode opt-in
- Strong EmmyLua annotations and type hints for LuaLS
- Clean, modular code layout (search, apply, pickers, command, config)

______________________________________________________________________

## Roadmap

- [x] Non-interactive “All” mode via `:Replace ... All`
- [x] Backend switch: `engine = "fzf"` or `"telescope"`
- [x] Confirm-all guard and write/no-write switch
- [x] Per-match preview and robust bottom-up edits
- [ ] Optional diff-style preview (before/after)
- [ ] Regex escape helpers (when literal=false)
- [ ] Built-in help `:help replacer`

______________________________________________________________________

______________________________________________________________________

## Installation

**Requirements;**

- Neovim 0.9 or newer
- ripgrep (`rg`) in `PATH`
- One picker:
  - `ibhagwan/fzf-lua`, or
  - `nvim-telescope/telescope.nvim` (+ `nvim-lua/plenary.nvim`)

### With Lazy.nvim

**Minmal:**

```lua
{
  "StefanBartl/replacer",
  name = "replacer.nvim",
  main = "replacer",
  opts = {
    engine = "fzf",            -- "fzf" | "telescope"
  },
}
```

**With configuration:**

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

    default_scope = "%",          -- "%", "cwd", ".", or <path>
    confirm_wide_scope = false,   -- ask once for permission if scope ≠ "%"

    fzf = {                    -- extra fzf-lua options (optional)
      winopts = { width = 0.85, height = 0.70 },
    },
    telescope = {              -- extra telescope options (optional)
      layout_config = { width = 0.85, height = 0.70 },
    },
  },
}
```

______________________________________________________________________

## Configuration

**Available Options:**

| Option          | Type    | Description                                                    |
| --------------- | ------- | -------------------------------------------------------------- |
| engine          | string  | Picker backend: "fzf" / "telescope"                            |
| write_changes   | boolean | Write modified buffers on apply (true) or keep unsaved (false) |
| confirm_all     | boolean | Ask confirmation before replacing all matches at once          |
| preview_context | integer | Context lines shown in preview around the hit                  |
| hidden          | boolean | Include dotfiles (`--hidden`)                                  |
| git_ignore      | boolean | Respect .gitignore (false → `--no-ignore`)                     |
| exclude_git_dir | boolean | Exclude `.git` directory explicitly (`--glob !.git`)           |
| literal         | boolean | Literal search (`--fixed-strings`); set false for regex mode   |
| smart_case      | boolean | Smart-case (`-S`)                                              |
| fzf             | table?  | Extra options for `fzf-lua` (merged into picker opts)          |
| telescope       | table?  | Extra options for Telescope picker (theme/layout)              |

**Full example:**

```lua
require("replacer").setup({
  engine = "fzf",            -- or "telescope"
  default_scope = "%",
  write_changes = true,
  confirm_all = true,        -- affects <C-a> and :Replace!
  confirm_wide_scope = false,
  preview_context = 3,
  hidden = true,
  exclude_git_dir = true,
  literal = true,
  smart_case = true,
  fzf = { winopts = { width = 0.85, height = 0.70 } },
  telescope = { layout_config = { width = 0.85, height = 0.70 } },
})
```

## Safety & Notes

- Edits are applied bottom-up per file to avoid index shift issues.
- Each occurrence is verified against the original text before editing; mismatches are skipped and reported.
- When `write_changes = false`, buffers stay modified—review and `:write` manually or use VCS hunk staging.
- Literal mode is the default; for regex, set `literal = false` and provide proper patterns.
- ripgrep must be installed and discoverable via `PATH`.

______________________________________________________________________

## Development

- Repository layout follows standard `lua/<plugin_name>/...` convention for Lazy.nvim.
- Type hints use EmmyLua; LuaLS-friendly stubs are provided where helpful.
- To hack locally, add your repo via `dir = "/path/to/replacer"`.
- Typical debug flow:
  - `:Replace foo bar cwd`
  - In picker, inspect preview; Tab to select specific hits; Enter to apply
  - Ctrl-A to replace all with confirmation
  - Set `write_changes=false` to review changes before writing

______________________________________________________________________

## License

[MIT](./License)

______________________________________________________________________

## Disclaimer

ℹ️ This plugin is under active development – some features are planned or experimental.
Expect changes in upcoming releases.

______________________________________________________________________

## Feedback

Your feedback is very welcome!

Please use the [GitHub issue tracker](https://github.com/StefanBartl/replacer/issues) to:

- Report bugs
- Suggest new features
- Ask questions about usage
- Share thoughts on UI or functionality

For general discussion, feel free to open a [GitHub Discussion](https://github.com/StefanBartl/replacer/discussions).

If you find this plugin helpful, consider giving it a ⭐ on GitHub — it helps others discover the project.

______________________________________________________________________
