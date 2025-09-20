---@module 'replacer.pickers.fzf'
--- fzf-lua picker using the official builtin previewer:
---  - Pass buffer_or_file ctor + grep hints so previewer highlights FULL span.
---
--- Keys:
---  - <Tab>  multi-select (marker "*")
---  - <CR>   apply multi if present, else single
---  - <C-a>  apply ALL (respects cfg.confirm_all)

local common = require("replacer.pickers.common")

---@param old string
---@param items RP_Match[]
---@param new_text string
---@param cfg RP_Config            -- expects: literal, write_changes, fzf?, _last_query?
---@param apply_func fun(items: RP_Match[], new_text: string, write_changes: boolean): (integer, integer)
local function run(old, items, new_text, cfg, apply_func)
  local ok_fzf, fzf = pcall(require, "fzf-lua")
  if not ok_fzf then
    vim.notify("[replacer] fzf-lua not found", vim.log.levels.ERROR)
    return
  end

  local last_query = tostring(old or "")

  -- Build candidates in "file:line:col: text\tIDxx"
  local source, idmap = {}, {}
  for i = 1, #items do
    local it = items[i] --[[@as RP_Match]]
    local rel = vim.fn.fnamemodify(it.path, ":.")
    local visible = string.format("%s:%d:%d: %s", rel, it.lnum, it.col0 + 1, it.line)
    local hidden  = string.format("ID%d", it.id)
    source[#source + 1] = visible .. "\t" .. hidden
    idmap[hidden] = it
  end

  -- Official previewer ctor (do NOT call it; pass the ctor function)
  local ctor
  do
    local ok_prev, Previewer = pcall(require, "fzf-lua.previewer")
    if ok_prev and Previewer and Previewer.builtin and Previewer.builtin.buffer_or_file then
      ctor = Previewer.builtin.buffer_or_file
    end
  end

  -- Grep provider + last_query so previewer can highlight full span
  local grep_fn; pcall(function() grep_fn = require("fzf-lua.providers.grep").grep end)
  local ok_utils, utils = pcall(require, "fzf-lua.utils")
  if ok_utils and utils and (cfg.literal ~= false) then
    last_query = utils.rg_escape(last_query)
  end

  local actions = {
    ["default"] = function(selected)
      if not selected or #selected == 0 then return end
      local chosen = {} ---@type RP_Match[]
      for _, line in ipairs(selected) do
        local s = type(line) == "table" and line[1] or line
        local id = (type(s) == "string") and s:match("\t(ID%d+)$") or nil
        local it = id and idmap[id] or nil
        if it then chosen[#chosen + 1] = it end
      end
      if #chosen == 0 then return end
      local files, spots = apply_func(chosen, new_text, cfg.write_changes)
      common.notify_result(files, spots)
    end,
    ["ctrl-a"] = function()
      local all = {} ---@type RP_Match[]
      for _, s in ipairs(source) do
        local id = s:match("\t(ID%d+)$")
        local it = id and idmap[id] or nil
        if it then all[#all + 1] = it end
      end
      if #all == 0 then return end
      if cfg.confirm_all then
        local fileset = {}; for _, it in ipairs(all) do fileset[it.path] = true end
        local fc = 0; for _ in pairs(fileset) do fc = fc + 1 end
        if vim.fn.confirm(
          string.format("Apply replacement to ALL %d spot(s) across %d file(s)?", #all, fc),
          "&Yes\n&No", 2) ~= 1 then
          vim.notify("[replacer] cancelled"); return
        end
      end
      local files, spots = apply_func(all, new_text, cfg.write_changes)
      common.notify_result(files, spots)
    end,
  }

  local base = {
    prompt = "Select matches> ",
    fzf_opts = {
      ["--multi"]     = true,
      ["--with-nth"]  = "1",
      ["--delimiter"] = "\t",
      ["--no-mouse"]  = true,
      ["--marker"]    = "*",
    },
    actions = actions,
  }
  local opts = vim.tbl_deep_extend("force", base, cfg.fzf or {})

  -- Ensure preview is visible unless user explicitly hid it
  opts.winopts = opts.winopts or {}
  opts.winopts.preview = opts.winopts.preview or {}
  if opts.winopts.preview.hidden == nil then
    opts.winopts.preview.hidden = false
  end

  -- Wire official previewer + grep hints (full-span highlight)
  if ctor and grep_fn and last_query ~= "" then
    opts.previewer   = { _ctor = ctor }
    opts.__ACT_TO    = grep_fn
    opts._last_query = last_query
  end

  fzf.fzf_exec(source, opts)
end

return { run = run }
