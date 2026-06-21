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
---   - `engine` selects the picker UI ("fzf"|"telescope"|"auto").
---   - `search_engine` selects the match collector ("ripgrep"|"vimgrep"|"auto").
---     "auto" prefers ripgrep when the `rg` executable is available and falls
---     back to the native (vimgrep-style) scanner otherwise.

local M = {}

--------------------------------------------------------------------------------
-- Defaults & state
--------------------------------------------------------------------------------

---@type RP_Config
local Defaults = {
  -- Picker UI: "auto" picks fzf-lua when available, else telescope.
  engine = "auto",
  -- Search backend: "auto" picks ripgrep when available, else vimgrep (native).
  search_engine = "auto",

  write_changes = true,
  confirm_all = true,
  confirm_wide_scope = false,
  preview_context = 3,
  hidden = true,
  exclude_git_dir = true,
  literal = true,
  smart_case = true,
  default_scope = "%",

  -- Filters (also overridable per-run via command flags).
  file_types = {}, -- ripgrep --type values, e.g. { "lua", "md" }
  globs = {},      -- include glob patterns, e.g. { "*.lua" }
  exclude = {},    -- path/glob patterns to exclude, e.g. { "node_modules", "*.min.js" }

  fzf = { winopts = { width = 0.85, height = 0.70 } },
  telescope = { layout_config = { width = 0.85, height = 0.70 } },
  git_ignore = true,
}

---@type RP_Config
local state = vim.deepcopy(Defaults)

--------------------------------------------------------------------------------
-- Validators / Coercers (defensive)
--------------------------------------------------------------------------------

---@param v any
---@return boolean|nil # strict boolean or nil when unrecognized
local function as_bool(v)
  if type(v) == "boolean" then return v end
  if v == 1 or v == "1" or v == "true" then return true end
  if v == 0 or v == "0" or v == "false" then return false end
  return nil
end

---@param v any
---@return integer|nil
local function as_pos_int(v)
  if type(v) == "number" and v == math.floor(v) and v >= 0 then return v end
  return nil
end

---@param v any
---@return "fzf"|"telescope"|"auto"|nil
local function as_engine(v)
  if type(v) ~= "string" then return nil end
  local s = v:lower():gsub("%s+", ""):gsub("%-", "_")
  if s == "fzf" or s == "fzf_lua" then return "fzf" end
  if s == "telescope" then return "telescope" end
  if s == "auto" then return "auto" end
  return nil
end

---@param v any
---@return "ripgrep"|"vimgrep"|"auto"|nil
local function as_search_engine(v)
  if type(v) ~= "string" then return nil end
  local s = v:lower():gsub("%s+", ""):gsub("%-", "_")
  if s == "ripgrep" or s == "rg" then return "ripgrep" end
  if s == "vimgrep" or s == "native" or s == "vim" then return "vimgrep" end
  if s == "auto" then return "auto" end
  return nil
end

--- Coerce a value into a clean array of non-empty strings.
--- Accepts a single string (wrapped) or a list; ignores non-strings.
---@param v any
---@return string[]
local function as_string_list(v)
  if type(v) == "string" then
    return (v ~= "") and { v } or {}
  end
  if type(v) ~= "table" then return {} end
  local out = {} ---@type string[]
  for i = 1, #v do
    local s = v[i]
    if type(s) == "string" and s ~= "" then
      out[#out + 1] = s
    end
  end
  return out
end

---@param t table|nil
---@return table
local function tbl(t) return (type(t) == "table") and t or {} end

--- Pick a boolean override, falling back to `default` only when unset/unrecognized.
--- NOTE: do not use `as_bool(x) or default` — a legitimate `false` would be lost.
---@param v any
---@param default boolean
---@return boolean
local function pick_bool(v, default)
  local b = as_bool(v)
  if b == nil then return default end
  return b
end

---@param cfg table|nil
---@return RP_Config
local function validate(cfg)
  cfg = tbl(cfg)

  local out = vim.deepcopy(Defaults)

  out.engine             = as_engine(cfg.engine)               or out.engine
  out.search_engine      = as_search_engine(cfg.search_engine) or out.search_engine
  out.write_changes      = pick_bool(cfg.write_changes,      out.write_changes)
  out.confirm_all        = pick_bool(cfg.confirm_all,        out.confirm_all)
  out.confirm_wide_scope = pick_bool(cfg.confirm_wide_scope, out.confirm_wide_scope)
  out.preview_context    = as_pos_int(cfg.preview_context)     or out.preview_context
  out.hidden             = pick_bool(cfg.hidden,             out.hidden)
  out.exclude_git_dir    = pick_bool(cfg.exclude_git_dir,    out.exclude_git_dir)
  out.literal            = pick_bool(cfg.literal,            out.literal)
  out.smart_case         = pick_bool(cfg.smart_case,         out.smart_case)
  out.git_ignore         = pick_bool(cfg.git_ignore,        out.git_ignore)

  if type(cfg.default_scope) == "string" and cfg.default_scope ~= "" then
    out.default_scope = cfg.default_scope
  end

  -- Filter lists
  out.file_types = as_string_list(cfg.file_types)
  out.globs      = as_string_list(cfg.globs)
  out.exclude    = as_string_list(cfg.exclude)

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
