---@module 'replacer.pickers.fzf'
--- fzf-lua based interactive selection.
--- UX parity with the Telescope picker:
---   - <Tab> toggles selection (fzf-lua shows "*" marker)
---   - <CR> applies multi-selection if present, else just the current line
---   - <C-a> applies ALL matches (optional confirmation via cfg.confirm_all)
---
--- Nonstandard bits worth noting:
---   - We embed a hidden trailing token "\tID<id>" into each source line.
---     This allows mapping fzf’s raw string result back to the originating RP_Match.
---   - The builtin previewer calls back into our `common.preview_lines` to
---     render a stable, identical preview across both pickers.

local common = require("replacer.pickers.common")

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

  ---@cast cfg RP_Config

  ---@type string[]  -- display lines with trailing \tIDxxx
  local source = {}
  ---@type table<string, RP_Match>
  local idmap = {}

  for i = 1, #items do
    ---@cast items RP_Match[]
    local it = items[i]
    local visible = common.format_display(it)
    local hidden = string.format("ID%d", it.id)
    source[#source + 1] = visible .. "\t" .. hidden
    idmap[hidden] = it
  end

  local opts = vim.tbl_deep_extend("force", {
    prompt = "Select matches> ",
    fzf_opts = {
      ["--multi"] = "",
      ["--with-nth"] = "1",
      ["--delimiter"] = "\t",
      ["--no-mouse"] = "",
      ["--marker"] = "*",
    },
    previewer = "builtin",
    fn_previewer = function(item)
      local line = type(item) == "table" and item[1] or item
      if type(line) ~= "string" then
        return { "[no selection]" }
      end
      local id = line:match("\t(ID%d+)$")
      local it = id and idmap[id] or nil
      if not it then
        return { "[unknown id]" }
      end
      return common.preview_lines(it.path, it.lnum, cfg.preview_context)
    end,
    actions = {
      -- <CR>: apply selection (multi if present, else single)
      ["default"] = function(selected)
        if not selected or #selected == 0 then
          return
        end
        ---@type RP_Match[]
        local chosen = {}
        for _, line in ipairs(selected) do
          local s = type(line) == "table" and line[1] or line
          local id = (type(s) == "string") and s:match("\t(ID%d+)$") or nil
          local it = id and idmap[id] or nil
          if it then
            chosen[#chosen + 1] = it
          end
        end
        if #chosen == 0 then
          return
        end
        local files, spots = apply_func(chosen, new_text, cfg.write_changes)
        common.notify_result(files, spots)
      end,

      -- <C-a>: apply ALL
      ["ctrl-a"] = function()
        ---@type RP_Match[]
        local all = {}
        for _, line in ipairs(source) do
          local id = line:match("\t(ID%d+)$")
          local it = id and idmap[id] or nil
          if it then
            all[#all + 1] = it
          end
        end
        if #all == 0 then
          return
        end

        if cfg.confirm_all then
          ---@type table<string, true>
          local fileset = {}
          for _, it in ipairs(all) do
            fileset[it.path] = true
          end
          local filecount = 0
          for _ in pairs(fileset) do
            filecount = filecount + 1
          end
          local msg = string.format("Apply replacement to ALL %d spot(s) across %d file(s)?", #all, filecount)
          if vim.fn.confirm(msg, "&Yes\n&No", 2) ~= 1 then
            vim.notify("[replacer] cancelled")
            return
          end
        end

        local files, spots = apply_func(all, new_text, cfg.write_changes)
        common.notify_result(files, spots)
      end,
    },
  }, cfg.fzf or {})

  fzf.fzf_exec(source, opts)
end

return { run = run }
