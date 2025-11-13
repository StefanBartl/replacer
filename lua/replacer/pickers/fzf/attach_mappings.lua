---@module 'replacer.pickers.fzf.attach_mappings'
--- Module that builds fzf-lua actions table for replacer.
--- This mirrors the Telescope attach_mappings behavior by providing:
---  - "default" action: apply current multi-selection (if any) or single selection
---  - "ctrl-a" action: apply all visible matches (with optional confirmation)
---  - "alt-enter" action: apply selected entries, remove them from the source, and reopen
---  - "r" action: apply the single highlighted entry, remove it, and reopen
---
--- The module exports a single function `build_actions(opts)` which returns an
--- actions table consumable by fzf-lua. The function is intentionally pure:
--- it does not call fzf itself and accepts a `reopen_fn` callback that the
--- caller must provide to reopen the picker with a filtered list.
---
--- Usage:
---   local attach = require("replacer.pickers.fzf.attach_mappings")
---   local actions = attach.build_actions({
---     current_source = source_table,
---     current_idmap  = idmap_table,
---     items          = items_table,
---     new_text       = new_text,
---     cfg            = cfg_table,
---     apply_func     = apply_func,
---     reopen_fn      = function(remaining) ... end,
---   })
---
--- The returned `actions` table can be passed directly to fzf-lua's opts.actions.

local M = {}

local notify = vim.notify

--- Build actions table for fzf-lua.
--- Returns a table keyed by fzf action names (e.g. "default", "ctrl-a", "alt-enter", "r").
--- All heavy work is delegated to `apply_func` and `reopen_fn` supplied by caller.
---@param opts FzfAttachOpts
---@return table<string, fun()>
function M.build_actions(opts)
  -- Validate minimal shape; be tolerant to missing optional fields.
  local src = opts.current_source or {}
  local idmap = opts.current_idmap or {}
  local items = opts.items or {}
  local new_text = opts.new_text or ""
  local cfg = opts.cfg or {}
  local apply_func = opts.apply_func or function() return 0, 0 end
  local reopen_fn = opts.reopen_fn or function(_) end

  --- Helper: convert a formatted fzf line (or table line) into RP_Match via idmap.
  --- Accepts either "line" or {"line", ...} variants that fzf may pass.
  --- returns RP_Match or nil
  local function id_to_item(candidate)
    local line = type(candidate) == "table" and candidate[1] or candidate
    if type(line) ~= "string" then return nil end
    local id = line:match("\t(ID%d+)$")
    if not id then return nil end
    return idmap[id]
  end

  --- Helper: build list of all items from current_source using idmap
  local function all_from_current_source()
    local out = {} ---@type RP_Match[]
    for _, line in ipairs(src) do
      local id = type(line) == "string" and line:match("\t(ID%d+)$") or nil
      local it = id and idmap[id] or nil
      if it then out[#out+1] = it end
    end
    return out
  end

  --- Helper: compute remaining items after removing chosen ids
  local function filter_remaining(chosen_ids)
    local remaining = {}
    local seen = chosen_ids or {}
    for _, it in ipairs(items) do
      if not seen[it.id] then remaining[#remaining+1] = it end
    end
    return remaining
  end

  -- Build the actions table
  local actions = {}

  -- "default" action: apply either multi-selected entries passed by fzf or the explicit selected lines.
  actions["default"] = function(selected)
    if not selected or #selected == 0 then return end
    local chosen = {} ---@type RP_Match[]
    for _, cand in ipairs(selected) do
      local it = id_to_item(cand)
      if it then chosen[#chosen+1] = it end
    end
    if #chosen == 0 then return end
    local files, spots = apply_func(chosen, new_text, cfg.write_changes)
    notify(string.format("[replacer] %d spot(s) in %d file(s)", spots, files))
  end

  -- "ctrl-a": apply all visible items (current_source)
  actions["ctrl-a"] = function()
    local all = all_from_current_source()
    if #all == 0 then return end
    if cfg.confirm_all then
      local fileset = {} ---@type table<string, true>
      for _, it in ipairs(all) do fileset[it.path] = true end
      local filecount = 0; for _ in pairs(fileset) do filecount = filecount + 1 end
      local msg = string.format("Apply replacement to ALL %d spot(s) across %d file(s)?", #all, filecount)
      if vim.fn.confirm(msg, "&Yes\n&No", 2) ~= 1 then
        notify("[replacer] cancelled")
        return
      end
    end
    local files, spots = apply_func(all, new_text, cfg.write_changes)
    notify(string.format("[replacer] %d spot(s) in %d file(s)", spots, files))
  end

  -- "r": apply a single highlighted entry (first selected provided or fallback to first visible),
  -- then reopen with remaining items.
  actions["r"] = function(selected)
    local chosen_item = nil ---@type RP_Match|nil

    if selected and #selected > 0 then
      chosen_item = id_to_item(selected[1])
    end

    if not chosen_item and #src > 0 then
      -- fallback to first visible line
      local first = src[1]
      local id = type(first) == "string" and first:match("\t(ID%d+)$") or nil
      chosen_item = id and idmap[id] or nil
    end

    if not chosen_item then return end

    local files, spots = apply_func({ chosen_item }, new_text, cfg.write_changes)
    notify(string.format("[replacer] applied %d spot(s) in %d file(s)", spots, files))

    local remaining = filter_remaining({ [chosen_item.id] = true })
    if #remaining > 0 then
      vim.schedule(function() reopen_fn(remaining) end)
    end
  end

  return actions
end

return M
