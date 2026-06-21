---@module 'replacer.apply'
--- Replacement application and edit computation.
---
--- Two layers:
---   - `compute_file_edits` is a PURE function: given a file's lines and the
---     matches for that file, it returns the rewritten lines plus counts. It has
---     no side effects and is unit-testable. It backs dry-run and patch export.
---   - `apply_matches` performs the real, side-effecting buffer edits with
---     defensive guards (handle validation + pcall) and optional writes.
---
--- All offsets are byte-based (col0), consistent with the collectors.

local Err = require("replacer.error")

local M = {}

--------------------------------------------------------------------------------
-- Pure edit computation
--------------------------------------------------------------------------------

--- Apply `new_text` at every match position on a copy of `lines`.
--- Matches are applied right-to-left per line so earlier byte offsets stay valid.
--- A match whose recorded text no longer sits at its offset is skipped (stale).
---@param lines string[]            # 1-based file content
---@param matches RP_Match[]        # matches belonging to this file
---@param new_text string
---@return string[] new_lines, integer spots, integer skipped
function M.compute_file_edits(lines, matches, new_text)
  -- Group matches per line (parallel count map avoids recomputing #t per push).
  ---@type table<integer, RP_Match[]>
  local by_lnum = {}
  local counts = {}
  for i = 1, #matches do
    local it = matches[i]
    local key = it.lnum
    local t = by_lnum[key]; if not t then t = {}; by_lnum[key] = t end
    local c = (counts[key] or 0) + 1
    counts[key] = c
    t[c] = it
  end

  -- Copy lines (do not mutate caller input).
  local new_lines = {}
  for i = 1, #lines do new_lines[i] = lines[i] end

  local spots, skipped = 0, 0
  for lnum, list in pairs(by_lnum) do
    table.sort(list, function(a, b) return a.col0 > b.col0 end)
    local line = new_lines[lnum]
    if type(line) == "string" then
      for _, it in ipairs(list) do
        local old_text = it.old or ""
        local s, e = it.col0, it.col0 + #old_text
        local seg = line:sub(s + 1, e)
        if seg == old_text then
          line = line:sub(1, s) .. new_text .. line:sub(e + 1)
          spots = spots + 1
        else
          skipped = skipped + 1
        end
      end
      new_lines[lnum] = line
    else
      skipped = skipped + #list
    end
  end

  return new_lines, spots, skipped
end

--------------------------------------------------------------------------------
-- Real buffer application (side-effecting, guarded)
--------------------------------------------------------------------------------

--- Group matches by file path.
---@param items RP_Match[]
---@return table<string, RP_Match[]>
local function group_by_path(items)
  local by_path = {}
  local counts = {}
  for i = 1, #items do
    local it = items[i]
    local key = it.path
    local t = by_path[key]; if not t then t = {}; by_path[key] = t end
    local c = (counts[key] or 0) + 1
    counts[key] = c
    t[c] = it
  end
  return by_path
end

--- Apply replacements to the matched buffers, bottom-up, with guards.
---@param items RP_Match[]
---@param old string                # unused; kept for signature stability
---@param new_text string
---@param write_changes boolean
---@param cfg RP_Config|nil
---@return integer files, integer spots, RP_Error[] errors
---@diagnostic disable-next-line: unused-local
function M.apply_matches(items, old, new_text, write_changes, cfg)
  local by_path = group_by_path(items)

  local files, spots, skipped_total = 0, 0, 0
  ---@type RP_Error[]
  local errors = {}

  for path, list in pairs(by_path) do
    -- Resolve & load the buffer defensively.
    local ok_add, bufnr = pcall(vim.fn.bufadd, path)
    if not ok_add or type(bufnr) ~= "number" or not vim.api.nvim_buf_is_valid(bufnr) then
      errors[#errors + 1] = Err.write_error("cannot open buffer for " .. path)
      goto next_path
    end
    pcall(vim.fn.bufload, bufnr)
    if not vim.api.nvim_buf_is_loaded(bufnr) then
      errors[#errors + 1] = Err.write_error("cannot load " .. path)
      goto next_path
    end

    -- Bottom-up so earlier edits do not shift later offsets.
    table.sort(list, function(a, b)
      if a.lnum ~= b.lnum then return a.lnum > b.lnum end
      return a.col0 > b.col0
    end)

    local skipped = 0
    for i = 1, #list do
      local it = list[i]
      local row = it.lnum - 1
      local ok_line, line = pcall(function()
        return vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
      end)
      line = (ok_line and line) or ""
      local old_text = it.old or ""
      local s, e = it.col0, it.col0 + #old_text
      local seg = line:sub(s + 1, e)

      if seg == old_text then
        local ok_set = pcall(vim.api.nvim_buf_set_text, bufnr, row, s, row, e, { new_text })
        if ok_set then
          spots = spots + 1
        else
          skipped = skipped + 1
        end
      else
        skipped = skipped + 1
      end
    end

    skipped_total = skipped_total + skipped
    if skipped > 0 and skipped >= #list * 0.5 then
      vim.notify(string.format(
        "[replacer] %s: %d/%d spot(s) skipped — buffer may have changed; re-run :Replace",
        vim.fn.fnamemodify(path, ":."), skipped, #list), vim.log.levels.WARN)
    end

    -- Write or count modified files.
    if vim.bo[bufnr].modified then
      if write_changes then
        local ok_write = pcall(function()
          vim.api.nvim_buf_call(bufnr, function() vim.cmd("silent noautocmd write") end)
        end)
        if ok_write then
          files = files + 1
        else
          errors[#errors + 1] = Err.write_error("failed to write " .. vim.fn.fnamemodify(path, ":."))
        end
      else
        files = files + 1
      end
    end

    ::next_path::
  end

  if skipped_total > 0 then
    vim.notify(string.format(
      "[replacer] %d match(es) skipped due to changed content.", skipped_total),
      vim.log.levels.WARN)
  end

  for i = 1, #errors do
    vim.notify("[replacer] " .. Err.format(errors[i]), vim.log.levels.ERROR)
  end

  return files, spots, errors
end

return M
