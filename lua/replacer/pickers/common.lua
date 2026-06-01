---@module 'replacer.pickers.common'
--- Shared helpers used by both pickers (Telescope / fzf-lua).
--- Responsibilities:
---   - Consistent list display formatting
---   - Preview text generation with context
---   - (NEW) Preview with exact target position for highlighting
---   - Uniform result notifications
---
--- Notes:
---   - We operate on byte indices (Lua's `#` on strings) which matches ripgrep's
---     byte-based columns (`it.col0`). This keeps UTF-8 safe for our purposes.
---   - `preview_lines_with_pos` returns the 0-based row/col where the match starts
---     inside the preview buffer. Pickers decide how to highlight (buf HL vs ANSI).

local M = {}

--------------------------------------------------------------------------------
-- Display line for list entries
--------------------------------------------------------------------------------

---@param it RP_Match
---@return string
function M.format_display(it)
  return string.format(
    "%s:%d:%d — %s",
    vim.fn.fnamemodify(it.path, ":."),
    it.lnum,
    it.col0 + 1,
    it.line
  )
end

--------------------------------------------------------------------------------
-- Preview helpers
--------------------------------------------------------------------------------

--- Build preview lines around a match and compute the exact target position.
--- Returns:
---   - target_col0: 0-based byte column within that row
--- @param it RP_Match
--- @param ctx integer
--- @return string[] lines, integer target_row0, integer target_col0
function M.preview_lines_with_pos(it, ctx)
  -- Read entire file (simple & robust; fast enough for typical preview sizes).
  local ok, fh = pcall(io.open, it.path, "r")
  if not ok or not fh then
    return { "[unreadable]" }, 0, 0
  end
  ---@type string[]
  local file = {}
  for s in fh:lines() do file[#file + 1] = s end
  fh:close()

  -- Clamp window to available lines
  local pad = (type(ctx) == "number" and ctx >= 0) and ctx or 2
  local start = math.max(1, it.lnum - pad)
  local stop  = math.min(#file, it.lnum + pad)

  ---@type string[]
  local out = {}
  local target_row0, target_col0 = 0, 0

  for i = start, stop do
    local is_hit = (i == it.lnum)
    local mark = is_hit and "▶ " or "  "
    -- Build full preview line
    local content = tostring(file[i] or "")
    local line = string.format("%s%6d  %s", mark, i, content)
    out[#out + 1] = line

    if is_hit then
      -- Compute byte length of the prefix as rendered above*:
      local prefix = mark .. string.format("%6d", i) .. "  "
      -- 0-based row index within the preview block
      target_row0 = (#out - 1)
      -- 0-based col: prefix bytes + original match byte column
      target_col0 = #prefix + (it.col0 or 0)
    end
  end

  return out, target_row0, target_col0
end

-- --- Back-compat wrapper: only preview text (no coordinates).
-- --- @param path string
-- --- @param lnum integer
-- --- @param ctx integer
-- --- @return string[]
-- function M.preview_lines(path, lnum, ctx)
--   local it = { path = path, lnum = lnum, col0 = 0, line = "" } ---@type RP_Match
--   local lines = M.preview_lines_with_pos(it, ctx)
--   ---@cast lines string[]  -- first return of the tuple
--   return lines
-- end

--------------------------------------------------------------------------------
-- Notifications
--------------------------------------------------------------------------------

--- Uniform success notification.
--- @param files integer
--- @param spots integer
function M.notify_result(files, spots)
  vim.notify(string.format("[replacer] %d spot(s) in %d file(s)", spots, files))
end

return M
