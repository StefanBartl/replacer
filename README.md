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

```sh
:[range]Replace[!] {old} {new} [scope] [--flags]
```

**Parameters:**

- `old` **required** — literal (or regex with `--regex`) text to search for
- `new` **required** — replacement text; empty string `""` deletes matches
- `scope` **optional** — `%` (current buffer) · `cwd` / `.` (working dir) · `<path>` (file/dir). Default: `default_scope` (`%`)
- `[range]` **optional** — e.g. `:'<,'>Replace` restricts matching to the selected lines
- `!` **optional** — bang is shorthand for `--all` (non-interactive)

Each occurrence on a line becomes its own selectable entry (multiple hits per line are all handled).

**Flags** (anywhere; a lone `--` stops flag parsing):

| Flag | Effect |
| ---- | ------ |
| `--literal` / `--no-literal` / `--regex` | toggle literal vs regex search |
| `--smart-case` / `--no-smart-case` | toggle ripgrep smart-case |
| `--hidden` / `--no-hidden` | include/exclude dotfiles |
| `--ignore` / `--no-ignore` | respect/ignore `.gitignore` |
| `--type=<ft>` *(repeatable)* | restrict to a filetype (ripgrep `--type`) |
| `--glob=<pat>` *(repeatable)* | include glob pattern |
| `--exclude=<pat>` *(repeatable)* | exclude path/glob pattern |
| `--engine=<fzf\|telescope>` | override picker for this run |
| `--context=<n>` | preview context lines |
| `--all` | non-interactive: apply to every match |
| `--dry` | plan only: show stats + diff, no writes |
| `--export=<path>` | write the planned diff (or `.json`) to a file (implies `--dry`) |

Examples:

```sh
:Replace foo bar                             # picker over cwd
:Replace foo bar %                           # picker over current file
:Replace "very old" "brand new" ./src        # picker over ./src
:Replace foo "" %                            # delete matches in current file
:Replace foo bar cwd --all                   # apply to all, no picker
:Replace TODO DONE cwd --type=lua --exclude=node_modules
:'<,'>Replace foo bar                        # only within the visual selection
:Replace foo bar cwd --dry                   # preview diff + stats, no writes
:Replace foo bar cwd --export=changes.patch  # write a git-applyable patch
:Replace foo bar cwd --export=plan.json      # write a JSON change plan
```

### Surround — wrap every match

```sh
:[range]Surround[!] {pattern} [delim] [scope] [--flags]
```

A convenience layer over `:Replace` that wraps every occurrence of `{pattern}`
with a delimiter (the replacement is `<left>{pattern}<right>`). It reuses the
full pipeline — scope, picker, `--dry`, `--all`, and every flag above. `:Wrap`
is an alias. Search is always **literal** (regex would need per-match capture).

- `delim` — a literal char/string (`` ` `` `"` `'` `*` `**` `_`), a **named alias**, or a **bracket opener** (`(` `[` `{` `<`) which pairs with its closer. Omit it to be prompted.
- Aliases: `b`→`` ` ``, `q`→`"`, `s`→`'`, `star`→`*`, `bold`→`**`, `italic`→`_`, `paren`→`( )`, `bracket`→`[ ]`, `brace`→`{ }`, `angle`→`< >`.

```sh
:Surround word `                 # `word`  in the current buffer
:Surround word b                 # `word`  (alias for backtick)
:Surround "foo bar" ** cwd       # **foo bar**  across the working dir
:Surround TODO ( .               # (TODO)  project-wide, all files
:Surround! name q %              # "name"  everywhere in buffer, no picker
:'<,'>Surround item *            # *item*  within the selected lines
:Surround word                   # prompt: "Surround with: "
```

**After picker opened:**

fzf-lua:

- Tab: toggle selection
- Enter: apply to the currently selected entries
- Ctrl-A: replace all matches at once (confirmation depends on `confirm_all`)
- Esc: first press leaves terminal-insert (normal mode), second press closes

Telescope:

- Tab: toggle selection
- Enter: apply to the highlighted entry
- Ctrl-A: replace all matches at once (confirmation depends on `confirm_all`)
- Esc: first press switches to normal mode, second press closes

______________________________________________________________________

## Features

- Project-wide search using ripgrep `--json` for precise match coordinates
- **Native `vimgrep` fallback** when ripgrep is not installed (no external dep)
- Interactive selection via `fzf-lua` or `telescope.nvim`, **auto-detected** (`engine = "auto"`)
- Every occurrence per line is a separate, selectable entry
- Live context preview around each match
- Replace only the selected occurrences; or replace all at once
- **Dry-run** (`--dry`) with a stats summary and a diff preview — no writes
- **Export** the planned change as a git-applyable `.patch` or `.json` (`--export=`)
- Per-run **flags** (`--regex`, `--type=`, `--glob=`, `--exclude=`, …) and config defaults
- **Range** support: `:'<,'>Replace` limits to the selected lines
- **`:Surround` / `:Wrap`** — wrap every match with a delimiter (backticks, quotes, `**`, brackets, …)
- Guarded, bottom-up in-buffer edits to avoid offset shift bugs
- Optional write-to-disk on apply (or keep changes unsaved)
- Strong EmmyLua annotations and type hints for LuaLS
- Clean, modular code layout (search, apply, export, pickers, command, config)

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
- ripgrep (`rg`) in `PATH` — *recommended*; without it the native `vimgrep` backend is used automatically
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
    engine = "auto",           -- "auto" | "fzf" | "telescope"
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
    engine = "auto",           -- picker: "auto" | "fzf" | "telescope"
    search_engine = "auto",    -- backend: "auto" | "ripgrep" | "vimgrep"
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

    file_types = {},              -- default ripgrep --type filters, e.g. { "lua" }
    globs = {},                   -- default include globs, e.g. { "*.lua" }
    exclude = {},                 -- default exclude patterns, e.g. { "node_modules" }

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
| engine          | string  | Picker UI: "auto" / "fzf" / "telescope" ("auto" → fzf-lua if present, else telescope) |
| search_engine   | string  | Match backend: "auto" / "ripgrep" / "vimgrep" ("auto" → ripgrep if present, else vimgrep) |
| write_changes   | boolean | Write modified buffers on apply (true) or keep unsaved (false) |
| confirm_all     | boolean | Ask confirmation before replacing all matches at once          |
| confirm_wide_scope | boolean | Extra confirmation for non-buffer (cwd/dir) ALL applies      |
| preview_context | integer | Context lines shown in preview around the hit                  |
| hidden          | boolean | Include dotfiles (`--hidden`)                                  |
| git_ignore      | boolean | Respect .gitignore (false → `--no-ignore`)                     |
| exclude_git_dir | boolean | Exclude `.git` directory explicitly (`--glob !.git`)           |
| literal         | boolean | Literal search (`--fixed-strings`); set false for regex mode   |
| smart_case      | boolean | Smart-case (`-S`)                                              |
| default_scope   | string  | Scope used when none is given (`%`, `cwd`, `.`, or `<path>`)    |
| file_types      | string[] | Default filetype filters (ripgrep `--type`)                   |
| globs           | string[] | Default include glob patterns                                 |
| exclude         | string[] | Default exclude path/glob patterns                            |
| fzf             | table?  | Extra options for `fzf-lua` (merged into picker opts)          |
| telescope       | table?  | Extra options for Telescope picker (theme/layout)              |

**Full example:**

```lua
require("replacer").setup({
  engine = "auto",           -- "auto" | "fzf" | "telescope"
  search_engine = "auto",    -- "auto" | "ripgrep" | "vimgrep"
  default_scope = "%",
  write_changes = true,
  confirm_all = true,        -- affects <C-a> and :Replace!
  confirm_wide_scope = false,
  preview_context = 3,
  hidden = true,
  exclude_git_dir = true,
  literal = true,
  smart_case = true,
  file_types = {},           -- e.g. { "lua" }
  globs = {},                -- e.g. { "*.lua" }
  exclude = {},              -- e.g. { "node_modules" }
  fzf = { winopts = { width = 0.85, height = 0.70 } },
  telescope = { layout_config = { width = 0.85, height = 0.70 } },
})
```

## Safety & Notes

- Use `--dry` (or `--export=`) first to review the exact diff before touching any file.
- Edits are applied bottom-up per file, each guarded with `pcall`, to avoid index shift and partial-failure issues.
- Each occurrence is verified against the original text before editing; mismatches are skipped and reported.
- When `write_changes = false`, buffers stay modified—review and `:write` manually or use VCS hunk staging.
- Literal mode is the default; for regex, use `--regex` (or set `literal = false`).
- ripgrep is recommended; if it is not on `PATH`, the native `vimgrep` backend is used automatically (no `.gitignore`/rich `--type` support in that mode).

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
