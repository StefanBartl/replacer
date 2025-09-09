---@module 'replacer.pickers.telescope'
--- Telescope-based interactive selection with simple preview.
--- Uses attach_mappings in the picker options (preferred) and passes
--- two arguments to pickers.new (theme/layout opts, then picker opts).
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
      display = string.format(
        "%s:%d:%d — %s",
        vim.fn.fnamemodify(it.path, ":."), it.lnum, it.col0 + 1, it.line
      ),
      ordinal = it.path .. " " .. it.line,
    }
  end

  local previewer = previewers.new_buffer_previewer({
    title = "Preview",
    define_preview = function(self, entry)
      ---@cast entry { value: RP_Match }
      local it = entry.value
      local okf, fh = pcall(io.open, it.path, "r")
      if not okf or not fh then
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { "[unreadable]" })
        return
      end
      local lines ---@type string[]
      lines = {}
      for s in fh:lines() do lines[#lines+1] = s end
      fh:close()

      local ctx = cfg.preview_context
      local s = math.max(1, it.lnum - ctx)
      local e = math.min(#lines, it.lnum + ctx)

      local out ---@type string[]
      out = {}
      for i = s, e do
        local mark = (i == it.lnum) and "▶ " or "  "
        out[#out+1] = string.format("%s%6d  %s", mark, i, tostring(lines[i] or ""))
      end

      vim.bo[self.state.bufnr].filetype = ""
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, out)
    end,
  })

  -- Theme/layout options as first argument; picker options as second
  local theme_opts = cfg.telescope or {}

  local picker = pickers.new(theme_opts, {
    prompt_title = "Select matches",
    sorter = conf.values.generic_sorter(theme_opts),
    finder = finders.new_table({
      results = items,
      entry_maker = entry_maker,
    }),
    previewer = previewer,

    -- Prefer attach_mappings here instead of calling picker:attach_mappings later
    attach_mappings = function(prompt_bufnr, map)
      -- <CR>: replace exactly the selected entry (no global confirmation)
      actions.select_default:replace(function()
        local sel = action_state.get_selected_entry()
        if not sel or not sel.value then return end
        ---@cast sel { value: RP_Match }
        local files, spots = apply_func({ sel.value }, new_text, cfg.write_changes)
        vim.notify(string.format("[replacer] %d spot(s) in %d file(s)", spots, files))
        actions.close(prompt_bufnr)
      end)

      -- <C-a>: replace ALL matches with optional confirmation
      local function do_all()
        if cfg.confirm_all then
          local msg = string.format("Apply replacement to ALL %d spot(s)?", #items)
          if vim.fn.confirm(msg, "&Yes\n&No", 2) ~= 1 then
            return
          end
        end
        local files, spots = apply_func(items, new_text, cfg.write_changes)
        vim.notify(string.format("[replacer] %d spot(s) in %d file(s)", spots, files))
        actions.close(prompt_bufnr)
      end

      map("i", "<C-a>", do_all)
      map("n", "<C-a>", do_all)
      return true
    end,
  })

  picker:find()
end

return { run = run }
