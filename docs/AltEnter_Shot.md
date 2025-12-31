```lua
- replacer/pickers/telescope/attach_mappings.lua
--@module 'replacer.pickers.telescope.attach_mappings'
-- Attach mappings (Enter/C-a/Alt-Enter) for telescope picker.
-- Alt-Enter: apply selected entry immediately, remove it from the items list,
--            close the current picker and reopen a new picker with remaining items.
--            This keeps the interactive flow but removes the already-applied entry.
-- Implementation notes:
--  - We close the picker and re-invoke the telescope runner with the filtered items.
--  - Re-opening is scheduled to avoid re-entrancy issues inside Telescope callbacks.
--  - Comments and parameter names in English (code conventions).

local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local pickers = require("telescope.pickers")
local M = {}

---@param prompt_bufnr number
---@param apply_func fun(items: RP_Match[], new_text: string, write_changes: boolean): (integer, integer)
---@param items RP_Match[]
---@param new_text string
---@param cfg RP_Config
---@param reopen_fun fun(items: RP_Match[], new_text: string, cfg: RP_Config, apply_func: fun): nil  -- function to reopen picker
---@return boolean
local function attach_mappings(prompt_bufnr, apply_func, items, new_text, cfg, reopen_fun)
  -- Replace selected entry (Enter)
  actions.select_default:replace(function()
    local sel = action_state.get_selected_entry()
    if not sel or not sel.value then return end
    ---@cast sel { value: RP_Match }
    local files, spots = apply_func({ sel.value }, new_text, cfg.write_changes)
    vim.notify(string.format("[replacer] %d spot(s) in %d file(s)", spots, files))
    actions.close(prompt_bufnr)
  end)

  -- Replace all with confirmation (Ctrl-A)
  local function do_all()
    if cfg.confirm_all then
      local msg = string.format("Apply replacement to ALL %d spot(s)?", #items)
      if vim.fn.confirm(msg, "&Yes\n&No", 2) ~= 1 then return end
    end
    local files, spots = apply_func(items, new_text, cfg.write_changes)
    vim.notify(string.format("[replacer] %d spot(s) in %d file(s)", spots, files))
    actions.close(prompt_bufnr)
  end

  -- Alt-Enter: apply selected entry immediately and remove from list,
  -- then reopen picker with remaining items (if any).
  local function alt_enter_apply()
    local sel = action_state.get_selected_entry()
    if not sel or not sel.value then return end
    ---@cast sel { value: RP_Match }
    local applied = sel.value

    -- Apply the single match
    local files, spots = apply_func({ applied }, new_text, cfg.write_changes)
    vim.notify(string.format("[replacer] applied %d spot(s) in %d file(s)", spots, files))

    -- Close current picker
    actions.close(prompt_bufnr)

    -- Build new item list without the applied entry (compare by unique id)
    local remaining = {}
    for _, it in ipairs(items) do
      if it.id ~= applied.id then table.insert(remaining, it) end
    end

    -- Reopen picker with remaining items (if any) at next tick to avoid reentrancy
    if #remaining > 0 and reopen_fun then
      vim.schedule(function()
        -- reopen_fun has the same signature as run(...)
        reopen_fun(remaining, new_text, cfg, apply_func)
      end)
    end
  end

  -- Map keys using telescope's mapping helpers where possible
  -- Map <C-a> to do_all
  map = vim.api.nvim_buf_set_keymap
  pcall(function()
    -- In picker buffer: map i and n modes
    vim.api.nvim_buf_set_keymap(prompt_bufnr, "i", "<C-a>", "", { callback = do_all, noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(prompt_bufnr, "n", "<C-a>", "", { callback = do_all, noremap = true, silent = true })
    -- Alt-Enter: often <M-CR> in terminals. Map both <M-CR> and <A-CR> for robustness.
    vim.api.nvim_buf_set_keymap(prompt_bufnr, "i", "<M-CR>", "", { callback = alt_enter_apply, noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(prompt_bufnr, "n", "<M-CR>", "", { callback = alt_enter_apply, noremap = true, silent = true })
    -- Also try angle-bracket variant for some terminals:
    vim.api.nvim_buf_set_keymap(prompt_bufnr, "i", "<A-CR>", "", { callback = alt_enter_apply, noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(prompt_bufnr, "n", "<A-CR>", "", { callback = alt_enter_apply, noremap = true, silent = true })
  end)

  return true
end

return { attach_mappings = attach_mappings }
```

```lua
-- replacer/pickers/telescope/run.lua
-- snippet showing how attach_mappings is called with a reopen function
-- inside the picker creation (replace only the attach_mappings assignment area)

-- ... earlier code unchanged ...

  local picker = pickers.new(theme_opts, {
    prompt_title = "Select matches",
    sorter = conf.generic_sorter(theme_opts),
    finder = finders.new_table({ results = items, entry_maker = entry_maker }),
    previewer = previewer,
    attach_mappings = function(prompt_bufnr, _)
      -- Pass a reopen function that simply calls this module's run(...) again
      local reopen_fun = function(new_items, new_text_arg, cfg_arg, apply_func_arg)
        -- Use schedule to avoid nesting Telescope calls
        vim.schedule(function()
          require("replacer.pickers.telescope.run").run(new_items, new_text_arg, cfg_arg, apply_func_arg)
        end)
      end
      return attach_mod.attach_mappings(prompt_bufnr, apply_func, items, new_text, cfg, reopen_fun)
    end,
  })

-- ... remainder unchanged ...
```

```lua
-- replacer/pickers/fzf/run.lua
---@module 'replacer.pickers.fzf.run'
--- fzf-lua picker wiring with Alt-Enter action:
--- Alt-Enter: apply selected entry, remove it from the source and re-open fzf with remaining items.
--- Implementation notes:
---  - fzf-lua accepts custom action keys mapped to key-strokes; we add an "alt-enter" action here.
---  - After applying, we re-call fzf.fzf_exec with the filtered source via vim.schedule to avoid re-entrancy.
local fzf_ok, fzf = pcall(require, "fzf-lua")
local preview_mod = require("replacer.pickers.fzf.preview_lines")
local M = {}

---@param items RP_Match[]
---@param new_text string
---@param cfg RP_Config
---@param apply_func fun(items: RP_Match[], new_text: string, write_changes: boolean): (integer, integer)
function M.run(items, new_text, cfg, apply_func)
  if not fzf_ok then
    vim.notify("[replacer] fzf-lua not found", vim.log.levels.ERROR)
    return
  end

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

  local source, idmap = build_source_and_map(items)

  local function reopen_with_filtered(remaining_list)
    -- reopen fzf picker with filtered list
    vim.schedule(function()
      M.run(remaining_list, new_text, cfg, apply_func)
    end)
  end

  local function make_actions(current_source, current_idmap)
    return {
      ["default"] = function(selected)
        if not selected or #selected == 0 then return end
        local chosen = {} ---@type RP_Match[]
        for _, line in ipairs(selected) do
          local s = type(line) == "table" and line[1] or line
          local id = type(s) == "string" and s:match("\t(ID%d+)$") or nil
          local it = id and current_idmap[id] or nil
          if it then chosen[#chosen+1] = it end
        end
        if #chosen == 0 then return end
        local files, spots = apply_func(chosen, new_text, cfg.write_changes)
        vim.notify(string.format("[replacer] %d spot(s) in %d file(s)", spots, files))
      end,

      ["ctrl-a"] = function()
        local all = {} ---@type RP_Match[]
        for _, line in ipairs(current_source) do
          local id = line:match("\t(ID%d+)$")
          local it = id and current_idmap[id] or nil
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

      -- Alt-Enter action: apply selected and remove them from source, then reopen with remaining items
      ["alt-enter"] = function(selected)
        if not selected or #selected == 0 then return end
        local chosen = {} ---@type RP_Match[]
        local chosen_ids = {} ---@type table<number,true>
        for _, line in ipairs(selected) do
          local s = type(line) == "table" and line[1] or line
          local id = type(s) == "string" and s:match("\t(ID%d+)$") or nil
          local it = id and current_idmap[id] or nil
          if it then
            chosen[#chosen+1] = it
            chosen_ids[it.id] = true
          end
        end
        if #chosen == 0 then return end

        -- apply chosen
        local files, spots = apply_func(chosen, new_text, cfg.write_changes)
        vim.notify(string.format("[replacer] applied %d spot(s) in %d file(s)", spots, files))

        -- build remaining list
        local remaining = {}
        for _, it in ipairs(items) do
          if not chosen_ids[it.id] then remaining[#remaining+1] = it end
        end

        -- reopen with remaining (if any)
        if #remaining > 0 then
          reopen_with_filtered(remaining)
        end
      end,
    }
  end

  -- Build base opts, merging user cfg but making sure our actions are wired.
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
    actions = make_actions(source, idmap),
  }

  local opts = vim.tbl_deep_extend("force", base_opts, cfg.fzf or {})

  fzf.fzf_exec(source, opts)
end

return M
```
