---@module 'replacer.config'
--- Central configuration for replacer.
--- Responsibilities:
---   - Provide Defaults and a validated, mutable runtime state
---   - Expose `setup(opts)` for user init
---   - Expose `get()` to read the effective config (copy)
---   - Expose `resolve(partial)` to merge+validate ad-hoc overrides
---
--- Notes:
---   - `get()` returns a deep copy to avoid accidental mutation by callers.

local M = {}

--------------------------------------------------------------------------------
-- Defaults & state
--------------------------------------------------------------------------------

---@type RP_Config
local Defaults = {
  engine = "fzf",
  write_changes = true,
  confirm_all = true,
  preview_context = 3,
  hidden = true,
  exclude_git_dir = true,
  literal = true,
  smart_case = true,
  default_scope = "%",
	confirm_wide_scope = false,

  fzf = { winopts = { width = 0.85, height = 0.70 } },
  telescope = { layout_config = { width = 0.85, height = 0.70 } },
}

---@type RP_Config
local state = vim.deepcopy(Defaults)

--------------------------------------------------------------------------------
-- Validators / Coercers (defensive)
--------------------------------------------------------------------------------

---@param v any @returns boolean (strict)
local function as_bool(v)
  if type(v) == "boolean" then return v end
  if v == 1 or v == "1" or v == "true" then return true end
  if v == 0 or v == "0" or v == "false" then return false end
  return nil
end

---@param v any @returns integer?
local function as_pos_int(v)
  if type(v) == "number" and v == math.floor(v) and v >= 0 then return v end
  return nil
end

---@param v any @returns "fzf"|"telescope"|nil
local function as_engine(v)
  if v == "fzf" or v == "telescope" then return v end
  return nil
end

---@param t table|nil
---@return table
local function tbl(t) return (type(t) == "table") and t or {} end

---@param cfg table|nil
---@return RP_Config
local function validate(cfg)
  cfg = tbl(cfg)

  local out = vim.deepcopy(Defaults)

  out.engine             = as_engine(cfg.engine) or out.engine
  out.write_changes      = as_bool(cfg.write_changes)     or out.write_changes
  out.confirm_all        = as_bool(cfg.confirm_all)       or out.confirm_all
  out.confirm_wide_scope = as_bool(cfg.confirm_wide_scope) or out.confirm_wide_scope
  out.preview_context    = as_pos_int(cfg.preview_context) or out.preview_context
  out.hidden             = as_bool(cfg.hidden)            or out.hidden
  out.exclude_git_dir    = as_bool(cfg.exclude_git_dir)   or out.exclude_git_dir
  out.literal            = as_bool(cfg.literal)           or out.literal
  out.smart_case         = as_bool(cfg.smart_case)        or out.smart_case

  if type(cfg.default_scope) == "string" and cfg.default_scope ~= "" then
    out.default_scope = cfg.default_scope
  end

  -- nested picker tables (shallow-merge over defaults)
  do
    local fzf = tbl(cfg.fzf)
    out.fzf = vim.tbl_deep_extend("force", vim.deepcopy(Defaults.fzf), fzf)
  end
  do
    local tel = tbl(cfg.telescope)
    out.telescope = vim.tbl_deep_extend("force", vim.deepcopy(Defaults.telescope), tel)
  end

  return out
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Initialize/override configuration.
--- @param opts RP_Config|table|nil
--- @return nil
function M.setup(opts)
  state = validate(vim.tbl_deep_extend("force", {}, state, tbl(opts)))
end

--- Get the current effective configuration (deep copy, read-only for callers).
--- @return RP_Config
function M.get()
  return vim.tbl_deep_extend("force", {}, state)
end

--- Resolve a partial override against the current state (without mutating it).
--- Useful for per-run overrides (e.g., flags from :Replace).
--- @param partial table|nil
--- @return RP_Config
function M.resolve(partial)
  local merged = vim.tbl_deep_extend("force", {}, state, tbl(partial))
  return validate(merged)
end

return M ---@type ReplacerConfigModule
