---@module 'replacer.apply'
--- Apply replacements to buffers bottom-up with improved error detection.

---@param items RP_Match[]
---@param old string               -- FIXED: added parameter
---@param new_text string
---@param write_changes boolean
---@param cfg RP_Config            -- FIXED: added parameter
---@return integer files, integer spots
---@diagnostic disable-next-line: unused-local
local function apply_matches(items, old, new_text, write_changes, cfg)
  ---@type table<string, RP_Match[]>
  local by_path = {}
  for i = 1, #items do
    local it = items[i]
    local t = by_path[it.path]; if not t then t = {}; by_path[it.path] = t end
    t[#t+1] = it
  end

  local files, spots = 0, 0
  local skipped_total = 0

  for path, list in pairs(by_path) do
    table.sort(list, function(a, b)
      if a.lnum ~= b.lnum then return a.lnum > b.lnum end
      return a.col0 > b.col0
    end)

    local bufnr = vim.fn.bufadd(path)
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
    end
  end

  -- Summary notification about skipped spots
  if skipped_total > 0 then
    vim.notify(
      string.format(
        "[replacer] Warning: %d match(es) were skipped due to changed content. Consider re-running the search.",
        skipped_total
      ),
      vim.log.levels.WARN
    )
  end

  return files, spots
end

return {
  apply_matches = apply_matches,
}
