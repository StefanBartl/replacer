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

---@class RP_HighlightConfig
---@field enabled boolean           -- whether to enable ext highlight preview
---@field strikethrough boolean     -- add strikethrough to the old text
---@field underline boolean         -- add underline to the old text
---@field old_bg string|nil         -- background color for old text (hex like "#FF7A29")
---@field old_fg string|nil         -- foreground color for old text
---@field new_fg string|nil         -- foreground color for new text (virt-text)
---@field virt_prefix string        -- prefix for virtual-text (e.g. " → ")
---@field hl_priority integer|nil   -- highlight priority (use vim.hl.priorities.*)
---@field ansi_old_bg string|nil    -- fallback ANSI color for fzf previews (e.g. "41" for red bg)
---@field ansi_new_fg string|nil    -- fallback ANSI color for fzf previews (e.g. "32" for green)
---@field preview_marker string|nil -- string used as line marker in preview (e.g. "▶ " or ">> ")

---@class RP_Config
---@field engine RP_Engine
---@field write_changes boolean
---@field confirm_all boolean
---@field preview_context integer
---@field hidden boolean
---@field git_ignore boolean
---@field exclude_git_dir boolean
---@field literal boolean
---@field smart_case boolean
---@field fzf table|nil
---@field telescope table|nil
---@field ext_highlight_opts RP_HighlightConfig

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
