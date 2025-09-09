---@module 'replacer.apply'
--- Apply replacements to buffers bottom-up and optionally write changes.

---@param items RP_Match[]
---@param new_text string
---@param write_changes boolean
---@return integer files, integer spots
local function apply(items, new_text, write_changes)
  ---@type table<string, RP_Match[]>
  local by_path = {}
  for i = 1, #items do
    local it = items[i]
    local t = by_path[it.path]; if not t then t = {}; by_path[it.path] = t end
    t[#t+1] = it
  end

  local files, spots = 0, 0
  for path, list in pairs(by_path) do
    table.sort(list, function(a, b)
      if a.lnum ~= b.lnum then return a.lnum > b.lnum end
      return a.col0 > b.col0
    end)

    local bufnr = vim.fn.bufadd(path)
    vim.fn.bufload(bufnr)
    for i = 1, #list do
      local it = list[i]
      local row = it.lnum - 1
      local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
      local s, e = it.col0, it.col0 + #it.old
      local seg = line:sub(s + 1, e)
      if seg == it.old then
        vim.api.nvim_buf_set_text(bufnr, row, s, row, e, { new_text })
        spots = spots + 1
      else
        vim.notify(string.format("[replacer] skip changed spot: %s:%d:%d", path, it.lnum, it.col0 + 1), vim.log.levels.WARN)
      end
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
  apply = apply,
}

