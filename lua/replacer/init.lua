---@module 'replacer'
--- Core orchestration: collect matches, run picker (or non-interactive),
--- apply replacements, and notify results.
--- Public API:
---   - setup(opts): initialize/override configuration
---   - run(old, new_text, scope, non_interactive_all, overrides?): execute a replace workflow
---
--- Notes:
---   - `setup` delegates to `replacer.config.setup`.
---   - `run` merges per-run overrides via `replacer.config.resolve` (no global mutation).

local M = {}

local cfg_mod = require("replacer.config")
local rg = require("replacer.rg")
local apply = require("replacer.apply")
local picker_fz = require("replacer.pickers.fzf")
local picker_te = require("replacer.pickers.telescope")
local common = require("replacer.pickers.common")
local cmd_mod = require("replacer.command")

---@class RP_RunOverrides
---@field literal boolean|nil
---@field confirm_all boolean|nil

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Initialize/override configuration (delegates to replacer.config).
--- @param opts RP_Config|table|nil
--- @return nil
function M.setup(opts)
  cfg_mod.setup(opts)
end

--- Public entry point.
--- @param old string
--- @param new_text string
--- @param scope string
--- @param non_interactive_all boolean  -- true: apply all, no picker
--- @param overrides RP_RunOverrides|nil -- per-run overrides (literal/confirm_all)
--- @return nil
function M.run(old, new_text, scope, non_interactive_all, overrides)
  -- Build effective config for this run without mutating global state.
  local cfg = cfg_mod.resolve(overrides or {})

  -- Store match length hint for picker highlighting (literal mode only)
  if cfg.literal then
    cfg._old_len = #old
  else
    cfg._old_len = 0
  end

  -- 1) Resolve scope (cwd/buffer/path)
  local roots, _ = cmd_mod.resolve_scope(scope)
  if not roots or #roots == 0 then
    -- resolve_scope already notified the user in edge-cases (e.g., unnamed buffer)
    return
  end

  -- 2) Collect matches via ripgrep (or buffer scan if modified)
  ---@cast roots string[]
  local items = rg.collect(old, roots, cfg)

  if #items == 0 then
    vim.notify("[replacer] no matches found", vim.log.levels.INFO)
    return
  end

  -- 3) Build applier closure with correct signature
  -- FIXED: Pass all 5 parameters that apply_matches expects
  local function apply_func(chosen, replacement, write_changes)
    return apply.apply_matches(chosen, old, replacement, write_changes, cfg)
  end

  -- 4) Non-interactive ALL mode (e.g., :Replace! or --all flag)
  if non_interactive_all then
    if cfg.confirm_all then
      local fileset = {}
      for _, it in ipairs(items) do
        fileset[it.path] = true
      end
      local filecount = 0
      for _ in pairs(fileset) do
        filecount = filecount + 1
      end
      local msg = string.format("Apply ALL %d spot(s) across %d file(s)?", #items, filecount)
      if vim.fn.confirm(msg, "&Yes\n&No", 2) ~= 1 then
        vim.notify("[replacer] cancelled", vim.log.levels.INFO)
        return
      end
    end
    local files, spots = apply_func(items, new_text, cfg.write_changes)
    common.notify_result(files, spots)
    return
  end

  -- 5) Interactive picker dispatch
  local engine = (cfg.engine or "fzf")
  if engine == "fzf" then
    picker_fz.run(old, items, new_text, cfg, apply_func)
  else
    picker_te.run(items, new_text, cfg, apply_func)
  end
end

return M
