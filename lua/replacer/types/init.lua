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
-- Errors      --
----------------

--- Structured error value (see replacer.error).
---@class RP_Error
---@field type string      # stable discriminator, e.g. "WriteError"
---@field message string
---@field cause any|nil

----------------
-- Command API --
----------------

--- Per-run override surface produced by command flags (merged over config).
---@class RP_Overrides
---@field literal? boolean
---@field smart_case? boolean
---@field hidden? boolean
---@field git_ignore? boolean
---@field engine? "fzf"|"telescope"
---@field preview_context? integer

--- Filters produced by command flags (merged over config filter lists).
---@class RP_Filters
---@field file_types string[]
---@field globs string[]
---@field exclude string[]

--- Structured request parsed from a :Replace invocation.
---@class RP_Request
---@field old string
---@field new string
---@field scope string
---@field all boolean              # non-interactive: apply to every match
---@field dry boolean              # plan only; compute edits, no writes
---@field export string|nil        # export path for the planned diff/JSON
---@field line_range integer[]|nil # {line1, line2} when a [range] was given
---@field overrides RP_Overrides
---@field filters RP_Filters

---@alias ReplacerRunCallback fun(request: RP_Request): nil
---@alias ReplacerResolveScopeFn fun(scope: RP_Scope): string[], boolean
---@alias ReplacerRunRegisterFn fun(run_fun: ReplacerRunCallback): nil

---@class ReplacerCommand
---@field register ReplacerRunRegisterFn
---@field resolve_scope ReplacerResolveScopeFn
---@field parse_request fun(raw: string|nil, cmd_opts: table|nil): boolean, RP_Request|nil, string|nil


----------------
-- apply.lua  -- Local extended match type to satisfy LuaLS when accessing optional fields.
----------------

---@class RP_MatchEx : RP_Match
---@field mlen integer|nil
---@field col1 integer|nil

return {}
