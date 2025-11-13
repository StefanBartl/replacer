---@module 'replacer.pickers.telescope.attach_mappings'
--- Attach mappings (Enter/C-a) for telescope picker.
--- This version accepts an apply_func callback and will call it when the user
--- confirms a selection or chooses "apply all".

local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

---@param prompt_bufnr number
---@param apply_func fun(items: RP_Match[], new_text: string, write_changes: boolean): (integer, integer)
---@param items RP_Match[]
---@param new_text string
---@param cfg RP_Config
---@return boolean
local function attach_mappings(prompt_bufnr, apply_func, items, new_text, cfg)
  -- Replace selected entry
  actions.select_default:replace(function()
    local sel = action_state.get_selected_entry()
    if not sel or not sel.value then return end
    ---@cast sel { value: RP_Match }
    local files, spots = apply_func({ sel.value }, new_text, cfg.write_changes)
    vim.notify(string.format("[replacer] %d spot(s) in %d file(s)", spots, files))
    actions.close(prompt_bufnr)
  end)

  -- Replace all with confirmation if configured
  local function do_all()
    if cfg.confirm_all then
      local msg = string.format("Apply replacement to ALL %d spot(s)?", #items)
      if vim.fn.confirm(msg, "&Yes\n&No", 2) ~= 1 then return end
    end
    local files, spots = apply_func(items, new_text, cfg.write_changes)
    vim.notify(string.format("[replacer] %d spot(s) in %d file(s)", spots, files))
    actions.close(prompt_bufnr)
  end

  -- Map <C-a> to do_all in both insert and normal modes inside the picker
  pcall(function()
    -- Attach keys using telescope actions API when available
    vim.api.nvim_buf_set_keymap(prompt_bufnr, "i", "<C-a>", "", { callback = do_all, noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(prompt_bufnr, "n", "<C-a>", "", { callback = do_all, noremap = true, silent = true })
  end)

  return true
end

return { attach_mappings = attach_mappings }
