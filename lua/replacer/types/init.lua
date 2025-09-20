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
-- Command API --
----------------

---@alias ReplacerRunCallback fun(old: string, new_text: string, scope: RP_Scope, all: boolean): nil
---@alias ReplacerResolveScopeFn fun(scope: RP_Scope): string[], boolean
---@alias ReplacerRunRegisterFn fun(run_fun: ReplacerRunCallback): nil

---@class ReplacerCommand
---@field register ReplacerRunRegisterFn
---@field resolve_scope ReplacerResolveScopeFn


----------------
-- apply.lua  -- Local extended match type to satisfy LuaLS when accessing optional fields.
----------------

---@class RP_MatchEx : RP_Match
---@field mlen integer|nil
---@field col1 integer|nil

