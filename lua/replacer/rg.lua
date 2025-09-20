---@module 'replacer.rg'
--- Ripgrep integration: collect matches from filesystem.
--- Emits a list of RP_Match based on rg --json output.

--------------------------------------------------------------------------------
-- Implementation
--------------------------------------------------------------------------------

---@param old string
---@param roots string[]
---@param cfg RP_RG_Config
---@return RP_Match[]
local function collect(old, roots, cfg)
  -- Help LuaLS understand cfg's shape in this scope
  ---@cast cfg RP_RG_Config

  if vim.fn.executable("rg") ~= 1 then
    vim.notify("[replacer] ripgrep (rg) is required", vim.log.levels.ERROR)
    return {}
  end

  ---@type string[]
  local args = { "rg", "--json", "-n", "--column" }
  if cfg.smart_case     then args[#args+1] = "-S" end
  if cfg.literal        then args[#args+1] = "--fixed-strings" end
  if cfg.hidden         then args[#args+1] = "--hidden" end
  if cfg.exclude_git_dir == false then args[#args+1] = "--no-ignore" end
  if cfg.exclude_git_dir then
    args[#args+1] = "--glob"
    args[#args+1] = "!.git"
  end
  args[#args+1] = old
  for i = 1, #roots do args[#args+1] = roots[i] end

  local res ---@type { code: integer, stdout?: string, stderr?: string }|nil
  if vim.system then
    local obj = vim.system(args, { text = true }):wait()
    res = { code = obj and obj.code or 1, stdout = obj and obj.stdout or "", stderr = obj and obj.stderr or "" }
    if not res or (res.code ~= 0 and res.code ~= 1) then
      vim.notify("[replacer] rg failed: " .. (res.stderr or res.stdout or ""), vim.log.levels.ERROR)
      return {}
    end
  else
    local cmd = table.concat(vim.tbl_map(vim.fn.shellescape, args), " ")
    local out = vim.fn.system(cmd)
    res = { code = vim.v.shell_error, stdout = out, stderr = "" }
    if res.code ~= 0 and res.code ~= 1 then
      vim.notify("[replacer] rg failed (sync): " .. (res.stdout or ""), vim.log.levels.ERROR)
      return {}
    end
  end

  ---@type RP_Match[]
  local matches = {}
  local id = 0

  -- ripgrep --json prints one JSON object per line; collect only "match" events
  for line in string.gmatch((res.stdout or ""), "([^\n]+)\n?") do
    local okj, ev = pcall(vim.json.decode, line)
    if okj and ev and ev.type == "match" and ev.data then
      local d = ev.data
      local path = (d.path and d.path.text) or ""
      local lnum = d.line_number or 0
      local text = (d.lines and d.lines.text) or ""
      local sm = d.submatches and d.submatches[1]
      if path ~= "" and lnum > 0 and sm and sm.start ~= nil and sm["end"] ~= nil then
        id = id + 1
        matches[#matches+1] = {
          id   = id,
          path = path,
          lnum = lnum,
          col0 = sm.start,             -- 0-based byte offset
          old  = old,
          line = text:gsub("\r?\n$", ""),
        }
      end
    end
  end

  return matches
end

return {
  collect = collect,
}
