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

<<<<<<< HEAD
local Config = require("replacer.config")
local RG     = require("replacer.rg")
local Apply  = require("replacer.apply")
local Cmd    = require("replacer.command")
local Debug  = require("replacer.debug")

---@type Replacer
local M = {
  options = Config.resolve(nil),
  setup   = function(_) end,
  run     = function(_, _, _, _) end,
}

--- Setup the plugin with user options and register commands.
---@param user RP_Config|nil
---@return nil
function M.setup(user)
  M.options = Config.resolve(user)

  -- Register main replace command
  Cmd.register(function(old, new_text, scope, all)
    M.run(old, new_text, scope, all)
  end)

  -- Register debug command
  Debug.register_command()
end

--- Execute the replace flow for given arguments.
---@param old string
---@param new_text string
---@param scope RP_Scope
---@param all boolean
---@return nil
function M.run(old, new_text, scope, all)
  -- Check debug mode
  local debug = M.options.ext_highlight_opts
    and M.options.ext_highlight_opts.debug
    or false

  if debug then
    vim.notify(
      string.format(
        "[replacer] Running: old='%s' new='%s' scope='%s' all=%s",
        old, new_text, scope, tostring(all)
      ),
      vim.log.levels.DEBUG
    )
  end

  -- Resolve scope (cwd/file/dir)
  local resolve = require("replacer.command").resolve_scope
  local roots, _ = resolve(scope)
  if type(roots) ~= "table" or #roots == 0 then
    return
  end

  -- Collect matches via ripgrep
  local items = RG.collect(old, roots, M.options)
=======
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

>>>>>>> feature
  if #items == 0 then
    vim.notify("[replacer] no matches found", vim.log.levels.INFO)
    return
  end

<<<<<<< HEAD
  if debug then
    vim.notify(
      string.format("[replacer] Found %d match(es)", #items),
      vim.log.levels.DEBUG
    )
  end

  -- Non-interactive "All" mode
  if all then
    if M.options.confirm_all then
      local fileset = {} ---@type table<string, true>
      for i = 1, #items do fileset[items[i].path] = true end
      local filecount = 0
      for _ in pairs(fileset) do filecount = filecount + 1 end

      local msg = string.format(
        "Apply replacement to ALL %d spot(s) across %d file(s)?",
        #items, filecount
      )
=======
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
>>>>>>> feature
      if vim.fn.confirm(msg, "&Yes\n&No", 2) ~= 1 then
        vim.notify("[replacer] cancelled", vim.log.levels.INFO)
        return
      end
    end
<<<<<<< HEAD

    local files, spots = Apply.apply(items, new_text, M.options.write_changes, debug)
    vim.notify(string.format("[replacer] %d spot(s) in %d file(s)", spots, files))
    return
  end

  -- Interactive picker dispatch
  local apply_func = function(selected_items, replacement, write)
    return Apply.apply(selected_items, replacement, write, debug)
  end

  if M.options.engine == "telescope" then
    require("replacer.pickers.telescope").run(items, new_text, M.options, apply_func)
  else
    require("replacer.pickers.fzf").run(items, new_text, M.options, apply_func)
=======
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
>>>>>>> feature
  end
end

return M
