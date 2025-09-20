---@module 'replacer.apply'
--- Apply replacements to buffers bottom-up and optionally write changes.
--- Safety:
---   - Literal mode: verify current text equals `old` before replacing.
---   - Regex mode: requires a match length (it.mlen or col1-col0); otherwise skip.


---@param items RP_Match[]
---@param old string
---@param new_text string
---@param write_changes boolean
---@param cfg RP_Config|nil
---@return integer files, integer spots
local function apply_matches(items, old, new_text, write_changes, cfg)
  cfg = cfg or {} ---@cast cfg RP_Config
  local literal = (cfg.literal ~= false) -- default true

  ---@type table<string, RP_Match[]>
  local by_path = {}
  for i = 1, #items do
    local it = items[i]
    local t = by_path[it.path]; if not t then t = {}; by_path[it.path] = t end
    t[#t+1] = it
  end

  local files, spots = 0, 0

  for path, list in pairs(by_path) do
    -- bottom-up to keep columns stable
    table.sort(list, function(a, b)
      if a.lnum ~= b.lnum then return a.lnum > b.lnum end
      return a.col0 > b.col0
    end)

    local bufnr = vim.fn.bufadd(path)
    vim.fn.bufload(bufnr)

    for i = 1, #list do
      ---@cast list RP_MatchEx[]
      local it = list[i] ---@type RP_MatchEx
      local row = it.lnum - 1
      local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""

      local s = it.col0
      local e

      if literal then
        local old_len = #old
        e = s + old_len
        local seg = line:sub(s + 1, e) -- Lua substring is 1-based
        if seg ~= old then
          vim.notify(
            string.format("[replacer] skip changed spot (literal mismatch): %s:%d:%d", path, it.lnum, it.col0 + 1),
            vim.log.levels.WARN
          )
          goto continue
        end
      else
        -- Regex flow: require a known match length (mlen or col1-col0)
        local mlen = it.mlen or (it.col1 and (it.col1 - it.col0)) or nil
        if not mlen or mlen < 0 then
          vim.notify(
            string.format("[replacer] skip spot without known match length (regex): %s:%d:%d", path, it.lnum, it.col0 + 1),
            vim.log.levels.WARN
          )
          goto continue
        end
        e = s + mlen
      end

      -- Replace range [row,s) .. [row,e) with new_text
      vim.api.nvim_buf_set_text(bufnr, row, s, row, e, { new_text })
      spots = spots + 1
      ::continue::
    end

    if write_changes and vim.bo[bufnr].modified then
      vim.api.nvim_buf_call(bufnr, function() vim.cmd("silent noautocmd write") end)
      files = files + 1
    elseif not write_changes and vim.bo[bufnr].modified then
      files = files + 1 -- count as changed file, but do not write
    end
  end

  return files, spots
end

return {
  apply_matches = apply_matches,
}
