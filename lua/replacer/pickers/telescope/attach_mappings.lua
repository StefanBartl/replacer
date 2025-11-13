---@module 'replacer.pickers.telescope.attach_mappings'
--- Attach mappings (Enter/C-a/Alt-Enter) for telescope picker.
--- This module fixes multi-selection handling: when the user selects multiple
--- entries with <Tab> and presses <CR>, all selected entries are applied.
--- It also preserves the single-entry behavior when nothing is multi-selected.
---
--- Export:
---   attach_mappings(prompt_bufnr, apply_func, items, new_text, cfg, reopen_fun) -> boolean

local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local api = vim.api
local nvim_buf_set_keymap = api.nvim_buf_set_keymap
local notify = vim.notify

---@param prompt_bufnr number
---@param apply_func fun(items: RP_Match[], new_text: string, write_changes: boolean): (integer, integer)
---@param items RP_Match[]
---@param new_text string
---@param cfg RP_Config
---@param reopen_fun fun(items: RP_Match[], new_text: string, cfg: RP_Config, apply_func: fun()): nil
---@return boolean
local function attach_mappings(prompt_bufnr, apply_func, items, new_text, cfg, reopen_fun)
  -- Helper: resolve current selection(s).
  -- If there are multi-selections (via Tab), use them; otherwise fall back to the
  -- single selected entry. The picker API exposes get_multi_selection() on the
  -- picker object obtained from action_state.get_current_picker(prompt_bufnr).
  local function get_selected_matches()
    -- obtain picker object
    local picker = action_state.get_current_picker(prompt_bufnr)
    local sel_entries = {}
    if picker and picker.get_multi_selection then
      -- get table of selected entries (may be empty)
      local multi = picker:get_multi_selection()
      if multi and #multi > 0 then
        for _, e in ipairs(multi) do
          if e and e.value then table.insert(sel_entries, e.value) end
        end
      end
    end

    -- if no multi-selection, use the currently highlighted entry
    if #sel_entries == 0 then
      local cur = action_state.get_selected_entry()
      if cur and cur.value then table.insert(sel_entries, cur.value) end
    end

    return sel_entries
  end

  -- Default <CR> behavior: apply either multi-selection or single selection.
  actions.select_default:replace(function()
    local chosen_values = get_selected_matches()
    if not chosen_values or #chosen_values == 0 then return end
    -- apply_func expects RP_Match[] (items), so pass chosen_values directly
    local files, spots = apply_func(chosen_values, new_text, cfg.write_changes)
    notify(string.format("[replacer] %d spot(s) in %d file(s)", spots, files))
    actions.close(prompt_bufnr)
  end)

  -- Replace all with confirmation (Ctrl-A)
  local function do_all()
    if cfg.confirm_all then
      local msg = string.format("Apply replacement to ALL %d spot(s)?", #items)
      if vim.fn.confirm(msg, "&Yes\n&No", 2) ~= 1 then return end
    end
    local files, spots = apply_func(items, new_text, cfg.write_changes)
    notify(string.format("[replacer] %d spot(s) in %d file(s)", spots, files))
    actions.close(prompt_bufnr)
  end

  -- Alt-Enter: apply selected entry immediately and remove from list,
  -- then reopen picker with remaining items (if any). Keep this behavior
  -- working with either a single highlighted entry or a multi-selection
  -- (if multi-selection is used, apply only the highlighted entry to keep
  -- the original UX of applying one at a time with Alt-Enter).
  local function apply_on_selection()
    local sel = action_state.get_selected_entry()
    if not sel or not sel.value then return end
    ---@cast sel { value: RP_Match }
    local applied = sel.value

    -- Apply the single match
    local files, spots = apply_func({ applied }, new_text, cfg.write_changes)
    notify(string.format("[replacer] applied %d spot(s) in %d file(s)", spots, files))

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
        reopen_fun(remaining, new_text, cfg, apply_func)
      end)
    end
  end

  -- Map keys using telescope's mapping helpers where possible
  -- Map <C-a> to do_all and Alt-Enter to apply_on_selection. Use buffer-local
  -- keymaps with {callback = ...} so no lhs rhs strings are necessary.
  pcall(function()
    -- In picker buffer: map insert and normal modes
    nvim_buf_set_keymap(prompt_bufnr, "i", "<C-a>", "", { callback = do_all, noremap = true, silent = true })
    nvim_buf_set_keymap(prompt_bufnr, "n", "<C-a>", "", { callback = do_all, noremap = true, silent = true })

    -- Alt-Enter: often <M-CR> in terminals. Map both <M-CR> and <A-CR> for robustness.
    -- nvim_buf_set_keymap(prompt_bufnr, "i", "<M-CR>", "", { callback = apply_on_selection, noremap = true, silent = true })
    -- nvim_buf_set_keymap(prompt_bufnr, "n", "<M-CR>", "", { callback = apply_on_selection, noremap = true, silent = true })
    nvim_buf_set_keymap(prompt_bufnr, "i", "r", "", { callback = apply_on_selection, noremap = true, silent = true })
    nvim_buf_set_keymap(prompt_bufnr, "n", "r", "", { callback = apply_on_selection, noremap = true, silent = true })
  end)

  return true
end

return { attach_mappings = attach_mappings }
