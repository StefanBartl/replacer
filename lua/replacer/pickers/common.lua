---@module 'replacer.pickers.common'
--- Small shared utilities for all pickers (Telescope / fzf-lua).
--- Responsibilities:
---   - Consistent list display formatting (path:lnum:col — line)
---   - Building preview window content with context lines
---   - Uniform result notification
---
--- Notes:
---   - `preview_lines` reads files synchronously and is intentionally simple.
---     If your match volume is huge or files are very big, consider a lazy/async
---     variant later. For now, correctness and clarity win.
---   - All comments are in English (per project guidelines).

local M = {}

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

--- Build preview buffer lines around a match line.
--- The match line is marked with "▶ " and left-padded line numbers for orientation.
--- @param path string
--- @param lnum integer     -- 1-based
--- @param ctx integer      -- number of lines of context on each side (>= 0)
--- @return string[]
function M.preview_lines(path, lnum, ctx)
  if type(path) ~= "string" or path == "" or type(lnum) ~= "number" then
    return { "[invalid selection]" }
  end
  ctx = (type(ctx) == "number" and ctx >= 0) and ctx or 2

  local ok, fh = pcall(io.open, path, "r")
  if not ok or not fh then
    return { "[unreadable]" }
  end

  ---@type string[]
  local lines = {}
  for s in fh:lines() do
    lines[#lines + 1] = s
  end
  fh:close()

  local s = math.max(1, lnum - ctx)
  local e = math.min(#lines, lnum + ctx)

  ---@type string[]
  local out = {}
  for i = s, e do
    local mark = (i == lnum) and "▶ " or "  "
    out[#out + 1] = string.format("%s%6d  %s", mark, i, tostring(lines[i] or ""))
  end
  return out
end

--- Uniform success notification for applied replacements.
--- @param files integer
--- @param spots integer
--- @return nil
function M.notify_result(files, spots)
  vim.notify(string.format("[replacer] %d spot(s) in %d file(s)", spots, files))
end

return M
