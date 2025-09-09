---@module 'replacer.types'
--- Central type definitions for the replacer plugin.
--- Purely for LuaLS; no runtime effect.

----------------
-- Core enums  --
----------------

---@alias RP_Engine
---| "fzf"        # Use ibhagwan/fzf-lua picker
---| "telescope"  # Use nvim-telescope/telescope.nvim picker

---@alias RP_Scope
---| "%"      # current buffer (file-backed only)
---| "buf"    # alias for "%"
---| "cwd"    # current working directory
---| "."      # alias for "cwd"
---| string   # absolute/relative file or directory path

----------------
-- Config      --
----------------

---@class RP_Config
---@field engine RP_Engine                 # Picker backend
---@field write_changes boolean            # Write buffers after replacement
---@field confirm_all boolean              # Ask before replacing all matches at once
---@field preview_context integer          # Lines of preview context per match
---@field hidden boolean                   # Include dotfiles in search
---@field git_ignore boolean               # Respect .gitignore (false => --no-ignore)
---@field exclude_git_dir boolean          # Exclude .git directory via --glob !.git
---@field literal boolean                  # Use --fixed-strings for ripgrep
---@field smart_case boolean               # Use -S (smart-case) for ripgrep
---@field fzf table|nil                    # Extra fzf-lua options (winopts, fzf_opts, …)
---@field telescope table|nil              # Extra telescope options (layout_config, …)

-- rg module accepts the same config surface (subset used).
---@alias RP_RG_Config RP_Config

----------------
-- Data model  --
----------------

---@class RP_Match
---@field id integer                     # per-run unique
---@field path string                    # absolute file path
---@field lnum integer                   # 1-based line number
---@field col0 integer                   # 0-based byte column start
---@field old string                     # matched text (literal/regex as configured)
---@field line string                    # full line for preview (no trailing newline)

----------------
-- Public API  --
----------------

---@alias ReplacerSetup fun(user: RP_Config|nil): nil
---@alias ReplacerRun fun(old: string, new_text: string, scope: RP_Scope, all: boolean): nil

--- Public facade of the plugin (returned by `require("replacer")`).
---@class Replacer
---@field options RP_Config
---@field setup fun(user: RP_Config|nil): nil
---@field run fun(old: string, new_text: string, scope: RP_Scope, all: boolean): nil

----------------
-- Command API --
----------------

---@alias ReplacerRunCallback fun(old: string, new_text: string, scope: RP_Scope, all: boolean): nil
---@alias ReplacerResolveScopeFn fun(scope: RP_Scope): string[], boolean
---@alias ReplacerRunRegisterFn fun(run_fun: ReplacerRunCallback): nil

---@class ReplacerCommand
---@field register ReplacerRunRegisterFn
---@field resolve_scope ReplacerResolveScopeFn
