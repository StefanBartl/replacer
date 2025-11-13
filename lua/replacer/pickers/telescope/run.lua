-- replacer/pickers/telescope/run.lua
---@module 'replacer.pickers.telescope.run'
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local ensure_hl = require("replacer.pickers.telescope.ensure_highlight_groups").ensure
local attach_mod = require("replacer.pickers.telescope.attach_mappings")
local U = require("replacer.pickers.utils")

---@param items RP_Match[]
---@param new_text string
---@param cfg RP_Config
---@param apply_func fun(items: RP_Match[], new_text: string, write_changes: boolean): (integer, integer)
local function run(items, new_text, cfg, apply_func)
  if not items or #items == 0 then return end

  ensure_hl(cfg.ext_highlight_opts)

  local ns = U.get_ns()

  local function entry_maker(it)
    return {
      value = it,
      display = string.format("%s:%d:%d — %s", vim.fn.fnamemodify(it.path, ":."), it.lnum, it.col0 + 1, it.line),
      ordinal = it.path .. " " .. it.line,
    }
  end

  local previewer = previewers.new_buffer_previewer({
    title = "Preview",
    define_preview = function(self, entry)
      local it = entry.value
      local ok, fh = pcall(io.open, it.path, "r")
      if not ok or not fh then
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { "[unreadable]" })
        return
      end
      local lines = {}
      for s in fh:lines() do lines[#lines+1] = s end
      fh:close()

      local ctx = cfg.preview_context or 3
      local s = math.max(1, it.lnum - ctx)
      local e = math.min(#lines, it.lnum + ctx)
      local out = {}
      -- Use preview_marker from config for the marker string
      local marker = (cfg.ext_highlight_opts and cfg.ext_highlight_opts.preview_marker) or "▶ "
      for i = s, e do
        local mark = (i == it.lnum) and marker or (" " .. string.rep(" ", #marker - 1))
        out[#out+1] = string.format("%s%6d  %s", mark, i, tostring(lines[i] or ""))
      end

      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, out)
      vim.bo[self.state.bufnr].filetype = ""

      if not cfg.ext_highlight_opts or not cfg.ext_highlight_opts.enabled then return end

      pcall(vim.api.nvim_buf_clear_namespace, self.state.bufnr, ns, 0, -1)

      local preview_first_line = s
      local target_preview_row = it.lnum - preview_first_line
      if target_preview_row < 0 or target_preview_row >= #out then return end

      local raw_line = lines[it.lnum] or ""
      local start_col = U.byte_to_display_col(raw_line, it.col0)
      local match_len = vim.fn.strdisplaywidth(it.old or "") or 0

      -- compute prefix columns from marker length + 6 digits + two spaces
      local marker_len = #((cfg.ext_highlight_opts and cfg.ext_highlight_opts.preview_marker) or "▶ ")
      local prefix_cols = marker_len + 6 + 2
      local hl_start = prefix_cols + start_col
      local hl_end = hl_start + (match_len > 0 and match_len or 1)

      local hl_groups = { "ReplacerOld" }
      if cfg.ext_highlight_opts.strikethrough then table.insert(hl_groups, "ReplacerOldStrikethrough") end
      -- set extmark with end_col and hl_group table
      pcall(vim.api.nvim_buf_set_extmark, self.state.bufnr, ns, target_preview_row, hl_start, {
        end_col = hl_end,
        hl_group = hl_groups,
        priority = cfg.ext_highlight_opts.hl_priority,
      })

      -- virt text
      local virt_text = (cfg.ext_highlight_opts.virt_prefix or " → ") .. tostring(new_text)
      pcall(vim.api.nvim_buf_set_extmark, self.state.bufnr, ns, target_preview_row, hl_end, {
        virt_text = { { virt_text, "ReplacerNew" } },
        virt_text_pos = "overlay",
        hl_mode = "combine",
      })
    end,
  })

  local theme_opts = cfg.telescope or {}
  local picker = pickers.new(theme_opts, {
    prompt_title = "Select matches",
    sorter = conf.generic_sorter(theme_opts),
    finder = finders.new_table({ results = items, entry_maker = entry_maker }),
    previewer = previewer,
    attach_mappings = function(prompt_bufnr, _)
      return attach_mod.attach_mappings(prompt_bufnr, apply_func, items, new_text, cfg)
    end,
  })

  picker:find()
end

return { run = run }
