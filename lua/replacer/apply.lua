---@module 'replacer.apply'
<<<<<<< HEAD
--- Apply replacements to buffers bottom-up with enhanced validation and diagnostics.
---
--- Key improvements:
--- 1. Normalize line text before comparison (consistent with rg.lua)
--- 2. Better error reporting with hex dump of mismatches
--- 3. Retry logic with trimmed comparison (handles trailing whitespace edge cases)
--- 4. Track skip reasons for statistics

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

--- Normalize line text: remove trailing \r?\n
---@param text string
---@return string
local function normalize_line(text)
  return (tostring(text):gsub("\r?\n$", ""))
end

--- Generate hex dump of string for diagnostics
---@param s string
---@param max_len? number
---@return string
local function hex_dump(s, max_len)
  max_len = max_len or 50
  if #s > max_len then
    s = s:sub(1, max_len) .. "..."
  end
  local out = {}
  for i = 1, #s do
    out[#out + 1] = string.format("%02X", s:byte(i))
  end
  return table.concat(out, " ")
end

--------------------------------------------------------------------------------
-- Main apply function
--------------------------------------------------------------------------------
=======
--- Apply replacements to buffers bottom-up with improved error detection.
>>>>>>> feature

---@param items RP_Match[]
---@param old string               -- FIXED: added parameter
---@param new_text string
---@param write_changes boolean
<<<<<<< HEAD
---@param debug? boolean Enable verbose diagnostics
---@return integer files, integer spots
local function apply(items, new_text, write_changes, debug)
  if not items or #items == 0 then return 0, 0 end

  -- Group matches by file path
=======
---@param cfg RP_Config            -- FIXED: added parameter
---@return integer files, integer spots
---@diagnostic disable-next-line: unused-local
local function apply_matches(items, old, new_text, write_changes, cfg)
>>>>>>> feature
  ---@type table<string, RP_Match[]>
  local by_path = {}
  for i = 1, #items do
    local it = items[i]
    local t = by_path[it.path]
    if not t then
      t = {}
      by_path[it.path] = t
    end
    t[#t + 1] = it
  end

  local files, spots = 0, 0
<<<<<<< HEAD
  local skip_stats = {
    changed = 0,
    trimmed_match = 0,
    out_of_range = 0
  }
=======
  local skipped_total = 0
>>>>>>> feature

  for path, list in pairs(by_path) do
    -- Sort bottom-up to avoid index shifts
    table.sort(list, function(a, b)
      if a.lnum ~= b.lnum then return a.lnum > b.lnum end
      return a.col0 > b.col0
    end)

    -- Load buffer
    local bufnr = vim.fn.bufadd(path)
<<<<<<< HEAD
    if not bufnr or bufnr == 0 then
      vim.notify(
        string.format("[replacer] failed to load buffer: %s", path),
        vim.log.levels.ERROR
      )
      goto next_file
    end

    pcall(vim.fn.bufload, bufnr)

    -- Apply each match
    for i = 1, #list do
      local it = list[i]
      local row = it.lnum - 1  -- 0-based for nvim_buf_get_lines

      -- Get current line
      local lines = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)
      if not lines or #lines == 0 then
        skip_stats.out_of_range = skip_stats.out_of_range + 1
        vim.notify(
          string.format(
            "[replacer] skip (out of range): %s:%d:%d",
            path, it.lnum, it.col0 + 1
          ),
          vim.log.levels.WARN
        )
        goto next_match
      end

      local line = normalize_line(lines[1])

      -- Validate byte offsets
      local s, e = it.col0, it.col0 + #it.old
      if s < 0 or e > #line then
        skip_stats.out_of_range = skip_stats.out_of_range + 1
        vim.notify(
          string.format(
            "[replacer] skip (bad offset): %s:%d:%d (s=%d e=%d len=%d)",
            path, it.lnum, it.col0 + 1, s, e, #line
          ),
          vim.log.levels.WARN
        )
        goto next_match
      end

      -- Extract segment and compare (1-based Lua indexing)
      local seg = line:sub(s + 1, e)

      -- Primary validation: exact match
      if seg == it.old then
        -- Apply replacement
        pcall(vim.api.nvim_buf_set_text, bufnr, row, s, row, e, { new_text })
        spots = spots + 1
        goto next_match
      end

      -- Retry with trimmed comparison (handles trailing whitespace edge cases)
      local seg_trimmed = vim.trim(seg)
      local old_trimmed = vim.trim(it.old)
      if seg_trimmed == old_trimmed then
        skip_stats.trimmed_match = skip_stats.trimmed_match + 1
        -- Still apply but count as trimmed match
        pcall(vim.api.nvim_buf_set_text, bufnr, row, s, row, e, { new_text })
        spots = spots + 1
        goto next_match
      end

      -- Validation failed: log detailed mismatch
      skip_stats.changed = skip_stats.changed + 1

      if debug then
        vim.notify(
          string.format(
            "[replacer] skip (mismatch): %s:%d:%d\n  expected: '%s' [%s]\n  actual:   '%s' [%s]",
            path, it.lnum, it.col0 + 1,
            it.old, hex_dump(it.old, 30),
            seg, hex_dump(seg, 30)
          ),
          vim.log.levels.WARN
        )
      else
        -- Compact warning without hex dump
        vim.notify(
          string.format(
            "[replacer] skip (mismatch): %s:%d:%d (expected '%s', got '%s')",
            path, it.lnum, it.col0 + 1,
            it.old:sub(1, 20), seg:sub(1, 20)
          ),
          vim.log.levels.WARN
        )
      end

      ::next_match::
=======
    vim.fn.bufload(bufnr)

    local skipped = 0

    for i = 1, #list do
      local it = list[i]
      local row = it.lnum - 1
      local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
      -- Use it.old from the match (already validated by rg collector)
      local old_text = it.old or ""
      local s, e = it.col0, it.col0 + #old_text
      local seg = line:sub(s + 1, e)

      if seg == old_text then
        vim.api.nvim_buf_set_text(bufnr, row, s, row, e, { new_text })
        spots = spots + 1
      else
        skipped = skipped + 1
        skipped_total = skipped_total + 1

        -- Enhanced diagnostics
        local expected = old_text
        local found = seg
        local context_start = math.max(1, s - 10)
        local context_end = math.min(#line, e + 10)
        local context = line:sub(context_start, context_end)

        local reason = "unknown"
        if #found ~= #expected then
          reason = string.format("length mismatch (expected %d chars, found %d)", #expected, #found)
        elseif found:gsub("%s+", "") == expected:gsub("%s+", "") then
          reason = "whitespace difference"
        else
          reason = "literal mismatch"
        end

        vim.notify(
          string.format(
            "[replacer] skip changed spot (%s): %s:%d:%d\n  Expected: '%s'\n  Found: '%s'\n  Context: '%s'",
            reason,
            path,
            it.lnum,
            it.col0 + 1,
            expected:gsub("\n", "\\n"),
            found:gsub("\n", "\\n"),
            context:gsub("\n", "\\n")
          ),
          vim.log.levels.WARN
        )
      end
    end

    -- Warn if many skips suggest stale search results
    if skipped > 0 and skipped >= #list * 0.5 then
      vim.notify(
        string.format(
          "[replacer] %s: %d/%d matches skipped - buffer may have changed since search. Consider re-running :Replace",
          vim.fn.fnamemodify(path, ":."),
          skipped,
          #list
        ),
        vim.log.levels.WARN
      )
    end

    if write_changes and vim.bo[bufnr].modified then
      vim.api.nvim_buf_call(bufnr, function() vim.cmd("silent noautocmd write") end)
      files = files + 1
    elseif not write_changes and vim.bo[bufnr].modified then
      files = files + 1
>>>>>>> feature
    end

    -- Handle buffer write
    if write_changes and vim.bo[bufnr].modified then
      local ok = pcall(function()
        vim.api.nvim_buf_call(bufnr, function()
          vim.cmd("silent noautocmd write")
        end)
      end)
      if ok then
        files = files + 1
      else
        vim.notify(
          string.format("[replacer] write failed: %s", path),
          vim.log.levels.ERROR
        )
      end
    elseif not write_changes and vim.bo[bufnr].modified then
      files = files + 1
    end

    ::next_file::
  end

<<<<<<< HEAD
  -- Report skip statistics if any
  local total_skips = skip_stats.changed + skip_stats.trimmed_match + skip_stats.out_of_range
  if total_skips > 0 then
    local msg = string.format(
      "[replacer] skipped %d spot(s): %d changed, %d trimmed, %d out-of-range",
      total_skips,
      skip_stats.changed,
      skip_stats.trimmed_match,
      skip_stats.out_of_range
    )
    vim.notify(msg, vim.log.levels.WARN)
=======
  -- Summary notification about skipped spots
  if skipped_total > 0 then
    vim.notify(
      string.format(
        "[replacer] Warning: %d match(es) were skipped due to changed content. Consider re-running the search.",
        skipped_total
      ),
      vim.log.levels.WARN
    )
>>>>>>> feature
  end

  return files, spots
end

return {
  apply_matches = apply_matches,
}
