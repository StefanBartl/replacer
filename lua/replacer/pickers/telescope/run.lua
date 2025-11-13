---@module 'replacer.pickers.telescope.run'
--- Telescope picker runner for replacer.
--- Shows preview where the original matched text ("old") is highlighted
--- (and optionally strikethrough) followed immediately by the "new" text
--- highlighted in a distinct group (green). The rest of the line follows.
---
--- Behavior:
---  - The preview line is rendered as: <marker><lineno>  <left><old><new><right>
---  - An extmark highlights the <old> span with ReplacerOld (+ strikethrough group if configured).
---  - A second extmark highlights the <new> span with ReplacerNew.
---  - No virt_text prefix is used.
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
	if not items or #items == 0 then
		return
	end

	ensure_hl(cfg.ext_highlight_opts)

	local ns = U.get_ns()

	local function entry_maker(it)
		return {
			value = it,
			display = string.format(
				"%s:%d:%d — %s",
				vim.fn.fnamemodify(it.path, ":."),
				it.lnum,
				it.col0 + 1,
				it.line
			),
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
			for s in fh:lines() do
				lines[#lines + 1] = s
			end
			fh:close()

			local ctx = cfg.preview_context or 3
			local s = math.max(1, it.lnum - ctx)
			local e = math.min(#lines, it.lnum + ctx)
			local out = {}
			-- Use preview_marker from config for the marker string
			local marker = (cfg.ext_highlight_opts and cfg.ext_highlight_opts.preview_marker) or "▶ "
			for i = s, e do
				local mark = (i == it.lnum) and marker or (" " .. string.rep(" ", #marker - 1))
				out[#out + 1] = string.format("%s%6d  %s", mark, i, tostring(lines[i] or ""))
			end

			vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, out)
			vim.bo[self.state.bufnr].filetype = ""

			if not cfg.ext_highlight_opts or not cfg.ext_highlight_opts.enabled then
				return
			end

			pcall(vim.api.nvim_buf_clear_namespace, self.state.bufnr, ns, 0, -1)

			-- compute indices and highlight spans for the preview buffer
			local preview_first_line = s
			local target_preview_row = it.lnum - preview_first_line
			if target_preview_row < 0 or target_preview_row >= #out then
				return
			end

			-- raw_line is the original file line (1-based indexing in Lua)
			local raw_line = lines[it.lnum] or ""

			-- Build a preview content where we insert new_text immediately after the old match.
			-- Use byte indices because it.col0 is a byte offset (0-based).
			-- left: bytes before match; match: old; right: bytes after match
			local left = ""
			if it.col0 > 0 then
				-- Lua string.sub takes 1-based indices; it.col0 is 0-based
				left = raw_line:sub(1, it.col0)
			end
			local matched = raw_line:sub(it.col0 + 1, it.col0 + (it.old and #it.old or 0))
			local right = raw_line:sub(it.col0 + (it.old and #it.old or 0) + 1)

			-- Compose preview content: left + old + new + right
			local composed_line = (left or "") .. (matched or it.old or "") .. (new_text or "") .. (right or "")

			-- Replace the corresponding line in the preview buffer with the composed line.
			-- The out table contains the prefix (marker + lineno + two spaces) followed by the original
			-- raw_line text. We need to update that preview line to include the composed_line instead.
			local prefix = string.format("%s%6d  ", marker, it.lnum)
			local preview_line = prefix .. composed_line
			-- Set the single line in the preview buffer
			pcall(vim.api.nvim_buf_set_lines, self.state.bufnr, target_preview_row, target_preview_row + 1, false, { preview_line })

			-- Compute display/byte column offsets for extmarks.
			-- Use U.byte_to_display_col to convert byte offset in raw_line to display column.
			-- local start_col_display = U.byte_to_display_col(raw_line, it.col0)
			-- local old_display_width = vim.fn.strdisplaywidth(it.old or "")
			-- local new_display_width = vim.fn.strdisplaywidth(new_text or "")

			-- prefix_cols should match the number of display columns occupied by the prefix
			-- (marker + 6 digits + two spaces).
			-- local marker_len = #((cfg.ext_highlight_opts and cfg.ext_highlight_opts.preview_marker) or "▶ ")
			-- local prefix_cols = marker_len + 6 + 2

			-- extmark start/end columns are specified in byte indices relative to the preview buffer line.
			-- However, nvim_buf_set_extmark accepts 'col' and 'end_col' as byte offsets in the buffer line.
			-- To simplify, convert display columns to byte columns on the preview_line using vim.fn.strdisplaywidth
			-- for substrings. We compute the byte column by measuring the prefix string length (bytes),
			-- then adding the byte length of left part (which is the raw_line prefix up to match).
			local prefix_byte_len = #prefix -- bytes

			-- Compute byte length of left part (raw_line bytes before match)
			local left_byte_len = it.col0 -- since it.col0 is byte count of left
			local old_byte_len = it.old and #it.old or #matched
			local new_byte_len = new_text and #new_text or 0

			-- extmark byte columns relative to start of the line
			local hl_start_byte = prefix_byte_len + left_byte_len
			local hl_old_end_byte = hl_start_byte + old_byte_len
			local hl_new_end_byte = hl_old_end_byte + new_byte_len

			-- Determine highlight groups for old/new
			local hl_groups_old = { "ReplacerOld" }
			if cfg.ext_highlight_opts.strikethrough then
				table.insert(hl_groups_old, "ReplacerOldStrikethrough")
			end
			local hl_group_new = "ReplacerNew" -- configured highlight should be green in ensure_highlight_groups

			-- Set extmark for the old text (with optional strikethrough)
			pcall(vim.api.nvim_buf_set_extmark, self.state.bufnr, ns, target_preview_row, hl_start_byte, {
				end_col = hl_old_end_byte,
				hl_group = hl_groups_old,
				priority = cfg.ext_highlight_opts.hl_priority,
			})

			-- Set extmark for the new text (green highlight)
			if new_byte_len > 0 then
				pcall(vim.api.nvim_buf_set_extmark, self.state.bufnr, ns, target_preview_row, hl_old_end_byte, {
					end_col = hl_new_end_byte,
					hl_group = hl_group_new,
					priority = cfg.ext_highlight_opts.hl_priority,
				})
			end
		end,
	})

	local theme_opts = cfg.telescope or {}
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

	picker:find()
end

return { run = run }
