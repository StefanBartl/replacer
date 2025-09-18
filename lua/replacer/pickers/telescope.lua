---@module 'replacer.pickers.telescope'
--- Telescope-based interactive selection with consistent UX:
---   - <Tab> toggles selection + moves forward, <S-Tab> toggles + moves back
---   - <CR> applies multi-selection if present, else just the current entry
---   - <C-a> applies ALL matches (optional confirmation via cfg.confirm_all)
---
--- Design notes:
---   - This picker mirrors the behavior of the fzf-lua variant; both share
---     `replacer.pickers.common` for display formatting, preview text, and notifications.
---   - We keep everything in `attach_mappings` to override default actions cleanly.

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
  local ok, _ = pcall(require, "telescope")
  if not ok then
    vim.notify("[replacer] telescope.nvim not found", vim.log.levels.ERROR)
    return
  end

  local pickers_ok, pickers = pcall(require, "telescope.pickers")
  local finders_ok, finders = pcall(require, "telescope.finders")
  local previewers_ok, previewers = pcall(require, "telescope.previewers")
  local conf_ok, conf = pcall(require, "telescope.config")
  local actions_ok, actions = pcall(require, "telescope.actions")
  local action_state_ok, action_state = pcall(require, "telescope.actions.state")
  if not (pickers_ok and finders_ok and previewers_ok and conf_ok and actions_ok and action_state_ok) then
    vim.notify("[replacer] telescope submodules missing", vim.log.levels.ERROR)
    return
  end

  ---@param it RP_Match
  local function entry_maker(it)
    return {
      value = it,
      display = common.format_display(it),
      ordinal = it.path .. " " .. it.line,
    }
  end

  local previewer = previewers.new_buffer_previewer({
    title = "Preview",
    define_preview = function(self, entry)
      ---@cast entry { value: RP_Match }
      local it = entry and entry.value or nil
      if not it then
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { "[no selection]" })
        return
      end
      local out = common.preview_lines(it.path, it.lnum, cfg.preview_context)
      vim.bo[self.state.bufnr].filetype = "" -- neutral to avoid syntax noise
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, out)
    end,
  })

  -- Theme/layout options as first argument; picker options as second
  local theme_opts = vim.tbl_deep_extend("force", { multi_icon = "*" }, cfg.telescope or {})

  local picker = pickers.new(theme_opts, {
    prompt_title = "Select matches",
    sorter = conf.values.generic_sorter(theme_opts),
    finder = finders.new_table({ results = items, entry_maker = entry_maker }),
    previewer = previewer,

    attach_mappings = function(prompt_bufnr, map)
      local function apply_selected_or_one()
        local sel = action_state.get_selected_entry()
        if not sel then return end

        local cur_picker = action_state.get_current_picker(prompt_bufnr)
        local multi = (cur_picker and cur_picker:get_multi_selection()) or {}

        if type(multi) == "table" and #multi > 0 then
          ---@type RP_Match[]
          local chosen = {}
          for _, e in ipairs(multi) do
            if e and e.value then chosen[#chosen + 1] = e.value end
          end
          local files, spots = apply_func(chosen, new_text, cfg.write_changes)
          common.notify_result(files, spots)
          actions.close(prompt_bufnr)
        else
          if not sel.value then return end
          ---@cast sel { value: RP_Match }
          local files, spots = apply_func({ sel.value }, new_text, cfg.write_changes)
          common.notify_result(files, spots)
          actions.close(prompt_bufnr)
        end
      end

      -- <CR>: multi-aware default action
      actions.select_default:replace(apply_selected_or_one)

      -- <Tab>/<S-Tab>: toggle + move
      local function toggle_next()
        actions.toggle_selection(prompt_bufnr)
        actions.move_selection_next(prompt_bufnr)
      end
      local function toggle_prev()
        actions.toggle_selection(prompt_bufnr)
        actions.move_selection_previous(prompt_bufnr)
      end
      map("i", "<Tab>", toggle_next);  map("n", "<Tab>", toggle_next)
      map("i", "<S-Tab>", toggle_prev); map("n", "<S-Tab>", toggle_prev)

      -- <C-a>: replace ALL matches with optional confirmation
      local function do_all()
        if cfg.confirm_all then
          local msg = string.format("Apply replacement to ALL %d spot(s)?", #items)
          if vim.fn.confirm(msg, "&Yes\n&No", 2) ~= 1 then
            return
          end
        end
        local files, spots = apply_func(items, new_text, cfg.write_changes)
        common.notify_result(files, spots)
        actions.close(prompt_bufnr)
      end
      map("i", "<C-a>", do_all); map("n", "<C-a>", do_all)

      return true
    end,
  })

  picker:find()
end

return { run = run }
