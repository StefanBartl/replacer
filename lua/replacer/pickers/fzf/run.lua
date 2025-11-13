---@module 'replacer.pickers.fzf.run'

local fzf_ok, fzf = pcall(require, "fzf-lua")
local preview_mod = require("replacer.pickers.fzf.preview_lines")
local attach = require("replacer.pickers.fzf.attach_mappings")
local M = {}

---@param list RP_Match[]
local function build_source_and_map(list)
  local src = {}
  local idmap = {}
  for i = 1, #list do
    local it = list[i]
    local rel = vim.fn.fnamemodify(it.path, ":.")
    local visible = string.format("%s:%d:%d — %s", rel, it.lnum, it.col0 + 1, it.line)
    local hidden = string.format("ID%d", it.id)
    src[#src+1] = visible .. "\t" .. hidden
    idmap[hidden] = it
  end
  return src, idmap
end

-- ---@param list RP_Match[]
-- ---@param new_text string
-- ---@param cfg RP_Config
-- ---@param apply_func fun(items: RP_Match[], new_text: string, write_changes: boolean): (integer, integer)
-- local function reopen_with_filtered(list, new_text, cfg, apply_func)
--   -- reopen fzf picker with filtered list
--   vim.schedule(function()
--     M.run(list, new_text, cfg, apply_func)
--   end)
-- end

---@param items RP_Match[]
---@param new_text string
---@param cfg RP_Config
---@param apply_func fun(items: RP_Match[], new_text: string, write_changes: boolean): (integer, integer)
function M.run(items, new_text, cfg, apply_func)
  if not fzf_ok then
    vim.notify("[replacer] fzf-lua not found", vim.log.levels.ERROR)
    return
  end

  local source, idmap = build_source_and_map(items)

  -- Provide a reopen function suitable for the attach builder
  local function reopen_fn(remaining)
    -- remaining is an RP_Match[] list; reopen this module with same new_text/cfg/apply_func
    vim.schedule(function()
      M.run(remaining, new_text, cfg, apply_func)
    end)
  end

  -- Build actions table using the modular attach_mappings builder.
  local actions = attach.build_actions({
    current_source = source,
    current_idmap  = idmap,
    items          = items,
    new_text       = new_text,
    cfg            = cfg,
    apply_func     = apply_func,
    reopen_fn      = reopen_fn,
  })

  local function make_opts()
    local base_opts = {
      prompt = "Select matches> ",
      fzf_opts = { ["--multi"] = "", ["--with-nth"] = "1", ["--delimiter"] = "\t" },
      previewer = "builtin",
      fn_previewer = function(item)
        local line = type(item) == "table" and item[1] or item
        local id = type(line) == "string" and line:match("\t(ID%d+)$") or nil
        local it = id and idmap[id] or nil
        if not it then return { "[unknown id]" } end
        return preview_mod.preview_lines(it, new_text, cfg)
      end,
      actions = actions,
    }
    return vim.tbl_deep_extend("force", base_opts, cfg.fzf or {})
  end

  local opts = make_opts()
  fzf.fzf_exec(source, opts)
end

return M
