---@module 'replacer.pickers.fzf'
--- fzf-lua based interactive selection with UX parity to Telescope:
---   - <Tab> multi-select (fzf shows "*" marker)
---   - <CR> applies multi if present, else single
---   - <C-a> applies ALL (respects cfg.confirm_all)
--- Preview:
---   - Uses common.preview_lines_with_pos to compute exact (row,col)
---   - Highlights the target span via ANSI (requires --ansi)
---
--- Notes:
---   - We highlight only when a literal old-length is available (cfg._old_len > 0).
---     For regex, extend the collector to provide match length/col1 if needed.

local common = require("replacer.pickers.common")

--------------------------------------------------------------------------------
-- Implementation
--------------------------------------------------------------------------------

---@param items RP_Match[]
---@param new_text string
---@param cfg RP_Config         -- receives _old_len optionally (we cast below)
---@param apply_func fun(items: RP_Match[], new_text: string, write_changes: boolean): (integer, integer)
---@return nil
local function run(items, new_text, cfg, apply_func)
  local ok_fzf, fzf = pcall(require, "fzf-lua")
  if not ok_fzf then
    vim.notify("[replacer] fzf-lua not found", vim.log.levels.ERROR)
    return
  end

  ---@cast cfg RP_ConfigPicker

  ---@type string[]                -- display lines with trailing \tIDxxx
  local source = {}
  ---@type table<string, RP_Match> -- "ID<n>" -> match
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
      ["--ansi"] = "", -- enable ANSI colors in preview
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

      local lines, row0, col0 = common.preview_lines_with_pos(it, cfg.preview_context)

      -- ANSI highlight (only if we know the literal length)
      local len = tonumber(cfg._old_len or 0) or 0
      if len > 0 and row0 >= 0 and col0 >= 0 then
        local target = lines[row0 + 1]
        if type(target) == "string" then
          -- convert 0-based byte indices to 1-based for Lua substring()
          local s1 = col0 + 1
          local e1 = col0 + len
          local n = #target
          if s1 >= 1 and s1 <= n and e1 >= s1 and e1 <= n then
            local ac = fzf.utils.ansi_codes
            lines[row0 + 1] = table.concat({
              target:sub(1, s1 - 1),
              ac.yellow, target:sub(s1, e1), ac.reset,
              target:sub(e1 + 1),
            })
          end
        end
      end

      return lines
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
          local xid = (type(s) == "string") and s:match("\t(ID%d+)$") or nil
          local it = xid and idmap[xid] or nil
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

      -- <C-a>: apply ALL (optional confirmation)
      ["ctrl-a"] = function()
        ---@type RP_Match[]
        local all = {}
        for _, line in ipairs(source) do
          local xid = line:match("\t(ID%d+)$")
          local it = xid and idmap[xid] or nil
          if it then
            all[#all + 1] = it
          end
        end
        if #all == 0 then
          return
        end
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
        common.notify_result(files, spots)
      end,
    },
  }, cfg.fzf or {})

  fzf.fzf_exec(source, opts)
end

return { run = run }
