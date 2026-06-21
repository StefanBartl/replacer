---@module 'replacer'
--- Core orchestration: parse a request, collect matches, then either plan
--- (dry-run / export) or apply (interactive picker / non-interactive ALL).
---
--- Public API:
---   - setup(opts): initialize/override configuration
---   - run(request): execute a replace workflow from a parsed request
---       (also accepts the legacy positional form run(old, new, scope, all))
---
--- Notes:
---   - `setup` delegates to `replacer.config.setup`.
---   - `run` merges per-run flag overrides + filters via `replacer.config.resolve`
---     without mutating global state.

local M = {}

local cfg_mod = require("replacer.config")
local rg = require("replacer.rg")
local apply = require("replacer.apply")
local export = require("replacer.export")
local common = require("replacer.pickers.common")
local cmd_mod = require("replacer.command")

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Initialize/override configuration (delegates to replacer.config).
---@param opts RP_Config|table|nil
---@return nil
function M.setup(opts)
  cfg_mod.setup(opts)
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

--- Resolve the picker UI engine, honoring "auto" (fzf-lua preferred, else telescope).
---@param cfg RP_Config
---@return "fzf"|"telescope"|nil
local function pick_picker(cfg)
  local e = cfg.engine or "auto"
  if e == "fzf" or e == "telescope" then return e end
  if pcall(require, "fzf-lua") then return "fzf" end
  if pcall(require, "telescope") then return "telescope" end
  return nil
end

--- Append every element of `src` onto `dst` (in place).
---@param dst string[]
---@param src string[]|nil
local function extend(dst, src)
  for i = 1, #(src or {}) do dst[#dst + 1] = src[i] end
end

--- Build the effective per-run config from a request (overrides + filters + range).
---@param request RP_Request
---@return RP_Config
local function effective_cfg(request)
  local cfg = cfg_mod.resolve(request.overrides or {})
  extend(cfg.file_types, request.filters and request.filters.file_types)
  extend(cfg.globs, request.filters and request.filters.globs)
  extend(cfg.exclude, request.filters and request.filters.exclude)
  cfg._line_range = request.line_range
  cfg._old_len = cfg.literal and #request.old or 0
  return cfg
end

--- Open a read-only scratch split showing diff text.
---@param patch string
local function show_diff_scratch(patch)
  if patch == "" then return end
  pcall(function()
    vim.cmd("botright new")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(patch, "\n", { plain = true }))
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "diff"
    vim.bo[buf].modifiable = false
    pcall(vim.api.nvim_buf_set_name, buf, "[replacer-plan]")
  end)
end

--- Dry-run / export path: compute the plan, report stats, optionally export, preview.
---@param request RP_Request
---@param items RP_Match[]
---@return nil
local function plan(request, items)
  local results, totals = export.build_results(items, request.new)
  vim.notify(string.format(
    "[replacer] dry-run: %d spot(s) in %d file(s)%s — no changes written",
    totals.spots, totals.files,
    totals.skipped > 0 and string.format(" (%d skipped)", totals.skipped) or ""))

  if request.export and request.export ~= "" then
    local ok, err = export.write_export(request.export, results, request.new)
    if ok then
      vim.notify("[replacer] plan exported to " .. request.export)
    else
      vim.notify("[replacer] " .. (err or "export failed"), vim.log.levels.ERROR)
    end
  end

  show_diff_scratch(export.build_patch(results))
end

--- Handle collected matches: plan (dry/export), apply ALL, or open the picker.
---@param request RP_Request
---@param cfg RP_Config
---@param single_file boolean
---@param items RP_Match[]
---@return nil
local function dispatch(request, cfg, single_file, items)
  -- Plan-only path (dry-run / export). Never writes.
  if request.dry or (request.export and request.export ~= "") then
    return plan(request, items)
  end

  -- Applier closure shared by ALL mode and the pickers.
  local function apply_func(chosen, replacement, write_changes)
    return apply.apply_matches(chosen, request.old, replacement, write_changes, cfg)
  end

  -- Non-interactive ALL.
  if request.all then
    local fileset = {}
    for _, it in ipairs(items) do fileset[it.path] = true end
    local filecount = 0
    for _ in pairs(fileset) do filecount = filecount + 1 end

    local wide = (not single_file) and cfg.confirm_wide_scope
    if cfg.confirm_all or wide then
      local msg = string.format("Apply ALL %d spot(s) across %d file(s)?", #items, filecount)
      if vim.fn.confirm(msg, "&Yes\n&No", 2) ~= 1 then
        vim.notify("[replacer] cancelled", vim.log.levels.INFO)
        return
      end
    end

    local files, spots = apply_func(items, request.new, cfg.write_changes)
    common.notify_result(files, spots)
    return
  end

  -- Interactive picker dispatch (auto-detected when engine = "auto").
  local engine = pick_picker(cfg)
  if not engine then
    vim.notify("[replacer] no picker available — install fzf-lua or telescope.nvim",
      vim.log.levels.ERROR)
    return
  end
  if engine == "fzf" then
    require("replacer.pickers.fzf").run(request.old, items, request.new, cfg, apply_func)
  else
    require("replacer.pickers.telescope").run(items, request.new, cfg, apply_func)
  end
end

--------------------------------------------------------------------------------
-- Run
--------------------------------------------------------------------------------

--- Execute a replace workflow.
--- Accepts a structured RP_Request, or the legacy positional form
--- run(old, new_text, scope, all) for backward compatibility.
---@param request RP_Request|string
---@param new_text? string
---@param scope? string
---@param all? boolean
---@return nil
function M.run(request, new_text, scope, all)
  if type(request) == "string" then
    request = {
      old = request, new = new_text or "", scope = scope or "",
      all = all and true or false, dry = false, export = nil, line_range = nil,
      overrides = {}, filters = { file_types = {}, globs = {}, exclude = {} },
    }
  end
  ---@cast request RP_Request

  local cfg = effective_cfg(request)

  -- 1) Resolve scope (fall back to configured default when none was given).
  local scope_tok = (request.scope ~= "" and request.scope) or cfg.default_scope
  local roots, single_file = cmd_mod.resolve_scope(scope_tok)
  if not roots or #roots == 0 then
    return -- resolve_scope already notified on edge cases
  end

  -- 2) Collect matches via the configured backend.
  ---@cast roots string[]

  -- 2) Collect matches asynchronously (ripgrep is non-blocking; vimgrep is sync),
  --    then 3) dispatch to plan / ALL / picker inside the callback.
  rg.collect_async(request.old, roots, cfg, function(items, err)
    if err then
      vim.notify("[replacer] " .. require("replacer.error").format(err), vim.log.levels.ERROR)
      return
    end
    if not items or #items == 0 then
      vim.notify("[replacer] no matches found", vim.log.levels.INFO)
      return
    end
    dispatch(request, cfg, single_file, items)
  end)
end

return M
