---@module 'replacer.pickers.fzf'
--- fzf-lua based interactive selection with Ctrl-A = "replace all (confirm)".
--- This file provides local forward type declarations to satisfy LuaLS,
--- plus casts at hot spots where inference is weak.


--------------------------------------------------------------------------------
-- Implementation
--------------------------------------------------------------------------------

---@param items RP_Match[]
---@param new_text string
---@param cfg RP_Config
---@param apply_func fun(items: RP_Match[], new_text: string, write_changes: boolean): (integer, integer)
---@return nil
local function run(items, new_text, cfg, apply_func)
  local ok_fzf, fzf = pcall(require, "fzf-lua")
  if not ok_fzf then
    vim.notify("[replacer] fzf-lua not found", vim.log.levels.ERROR)
    return
  end

  ---@type string[]  -- display lines with trailing \tIDxxx
  local source = {}
  ---@type table<string, RP_Match>
  local idmap = {}

  -- Explicitly cast 'cfg' for LuaLS so field access is known
  ---@cast cfg RP_Config

  for i = 1, #items do
    local it = items[i]
    ---@cast it RP_Match        -- tell LuaLS that 'it' has the RP_Match shape

    local rel = vim.fn.fnamemodify(it.path, ":.")
    local visible = string.format("%s:%d:%d — %s", rel, it.lnum, it.col0 + 1, it.line)
    local hidden = string.format("ID%d", it.id)
    source[#source+1] = visible .. "\t" .. hidden
    idmap[hidden] = it
  end

  ---@param it RP_Match
  ---@return string[]
  local function preview_lines(it)
    local ok, fh = pcall(io.open, it.path, "r")
    if not ok or not fh then return { "[unreadable]" } end
    local lines = {} ---@type string[]
    for s in fh:lines() do lines[#lines+1] = s end
    fh:close()

    local ctx = cfg.preview_context
    local s = math.max(1, it.lnum - ctx)
    local e = math.min(#lines, it.lnum + ctx)

    local out = {} ---@type string[]
    for i = s, e do
      local mark = (i == it.lnum) and "▶ " or "  "
      out[#out+1] = string.format("%s%6d  %s", mark, i, tostring(lines[i] or ""))
    end
    return out
  end

  local opts = vim.tbl_deep_extend("force", {
    prompt = "Select matches> ",
    fzf_opts = {
      ["--multi"] = "",
      ["--with-nth"] = "1",
      ["--delimiter"] = "\t",
      ["--no-mouse"] = "",
    },
    previewer = "builtin",
    fn_previewer = function(item)
      local line = type(item) == "table" and item[1] or item
      if type(line) ~= "string" then return { "[no selection]" } end
      local id = line:match("\t(ID%d+)$")
      local it = id and idmap[id] or nil
      return it and preview_lines(it) or { "[unknown id]" }
    end,
    actions = {
      ["default"] = function(selected)
        if not selected or #selected == 0 then return end
        local chosen = {} ---@type RP_Match[]
        for _, line in ipairs(selected) do
          local s = type(line) == "table" and line[1] or line
          local id = type(s) == "string" and s:match("\t(ID%d+)$") or nil
          local it = id and idmap[id] or nil
          if it then chosen[#chosen+1] = it end
        end
        if #chosen == 0 then return end
        local files, spots = apply_func(chosen, new_text, cfg.write_changes)
        vim.notify(string.format("[replacer] %d spot(s) in %d file(s)", spots, files))
      end,

      -- Unused param warning: remove it or name it '_'
      ["ctrl-a"] = function()
        local all = {} ---@type RP_Match[]
        for _, line in ipairs(source) do
          local id = line:match("\t(ID%d+)$")
          local it = id and idmap[id] or nil
          if it then all[#all+1] = it end
        end
        if #all == 0 then return end
        if cfg.confirm_all then
          local fileset = {} ---@type table<string, true>
          for _, it in ipairs(all) do fileset[it.path] = true end
          local filecount = 0; for _ in pairs(fileset) do filecount = filecount + 1 end
          local msg = string.format("Apply replacement to ALL %d spot(s) across %d file(s)?", #all, filecount)
          if vim.fn.confirm(msg, "&Yes\n&No", 2) ~= 1 then
            vim.notify("[replacer] cancelled")
            return
          end
        end
        local files, spots = apply_func(all, new_text, cfg.write_changes)
        vim.notify(string.format("[replacer] %d spot(s) in %d file(s)", spots, files))
      end,
    },
  }, cfg.fzf or {})

  fzf.fzf_exec(source, opts)
end

return { run = run }
