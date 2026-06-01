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

<<<<<<<< HEAD:@types/init.lua
----------------
-- Config      --
----------------

---@class RP_HighlightConfig
---@field enabled boolean            -- enable external preview highlighting
---@field old_bg string|nil          -- hex color for "old" background (e.g. "#FF7A29")
---@field old_fg string|nil          -- hex color for "old" foreground
---@field new_fg string|nil          -- hex color for virtual "new" text
---@field strikethrough boolean|nil  -- draw strikethrough over old text
---@field underline boolean|nil      -- underline old text (alternative)
---@field virt_prefix string|nil     -- prefix string for virtual hint (default " → ")
---@field hl_priority? integer|nil
---@field preview_marker string|nil  -- marker for the preview line (default "▶ ")
---@field ansi_old_bg string|nil      -- ANSI color code (or full sequence) for old (fzf fallback)
---@field ansi_new_fg string|nil     -- ANSI color for new hint (fzf fallback)
---@field ansi_fallback boolean
---@field debug boolean|nil          -- enable debug notifications in preview code

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
---@field ext_highlight boolean
---@field ext_highlight_strikethrough boolean
---@field ext_highlight_opts RP_HighlightConfig|nil
========
>>>>>>>> feature:lua/replacer/types/init.lua

-- rg module accepts the same config surface (subset used).
---@alias RP_RG_Config RP_Config

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

<<<<<<<< HEAD:@types/init.lua
----------------
-- fzf         --
----------------

---@class PreviewBufState
---@field win number|nil
---@field buf number|nil
---@field ns number
========

----------------
-- apply.lua  -- Local extended match type to satisfy LuaLS when accessing optional fields.
----------------

---@class RP_MatchEx : RP_Match
---@field mlen integer|nil
---@field col1 integer|nil

return {}
>>>>>>>> feature:lua/replacer/types/init.lua
