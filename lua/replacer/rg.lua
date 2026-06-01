---@module 'replacer.rg'
<<<<<<< HEAD
--- Ripgrep integration: collect matches from filesystem.
---
--- Ensures that multiple occurrences of the searched pattern in the same line
--- produce distinct selectable matches. Strategy:
--- 1. Prefer `rg --json -n --column -o` so ripgrep signals each occurrence.
--- 2. When ripgrep's JSON still yields only a single submatch for a line (or to be
---    defensive), fall back to a local scan of the reported line:
---      - if cfg.literal -> use plain string.find loop (byte offsets)
---      - else -> use vim.fn.matchstrpos to repeatedly find regex matches
---
--- This keeps behavior robust for both literal and regex searches.
=======
--- Ripgrep integration with buffer-aware fallback.
--- When a file is already loaded in a modified buffer, scan buffer content
--- instead of disk to avoid stale match coordinates.
>>>>>>> feature

local function is_buffer_modified(path)
  local bufnr = vim.fn.bufnr(path)
  if bufnr == -1 then return false, nil end
  if not vim.api.nvim_buf_is_loaded(bufnr) then return false, nil end
  return vim.bo[bufnr].modified, bufnr
end

--- Collect matches from buffer content instead of disk
---@param old string
---@param bufnr number
---@param cfg RP_RG_Config
---@return RP_Match[]
local function collect_from_buffer(old, bufnr, cfg)
  local path = vim.api.nvim_buf_get_name(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local matches = {}
  local id = 0

  local function find_all_occurrences(line_text, pattern, literal)
    local out = {}
    if line_text == "" or not pattern then return out end

    if literal then
      local start = 1
      while true do
        local s, e = line_text:find(pattern, start, true)
        if not s then break end
        out[#out + 1] = { start0 = s - 1, end0 = e - 1, text = line_text:sub(s, e) }
        start = e + 1
      end
    else
      local pos = 0
      while true do
        local mt = vim.fn.matchstrpos(line_text, pattern, pos)
        local matched = mt[1]
        local s = mt[2]
        local e = mt[3]
        if s == -1 or not matched or matched == "" then break end
        out[#out + 1] = { start0 = s, end0 = e - 1, text = matched }
        pos = e
        if pos >= #line_text then break end
      end
    end
    return out
  end

  for lnum, line in ipairs(lines) do
    local occs = find_all_occurrences(line, old, cfg.literal)
    for _, occ in ipairs(occs) do
      id = id + 1
      matches[#matches + 1] = {
        id = id,
        path = path,
        lnum = lnum,
        col0 = occ.start0,
        old = occ.text,
        line = line,
      }
    end
  end

  return matches
end

---@param old string
---@param roots string[]
---@param cfg RP_RG_Config
---@return RP_Match[]  -- FIXED: always returns table (never nil)
local function collect(old, roots, cfg)
  ---@cast cfg RP_RG_Config

  -- Special case: if roots contains single file that's a modified buffer,
  -- scan buffer content instead of disk
  if #roots == 1 then
    local is_modified, bufnr = is_buffer_modified(roots[1])
    if is_modified and bufnr then
      vim.notify("[replacer] scanning modified buffer instead of disk", vim.log.levels.INFO)
      return collect_from_buffer(old, bufnr, cfg)
    end
  end

  if vim.fn.executable("rg") ~= 1 then
    vim.notify("[replacer] ripgrep (rg) is required", vim.log.levels.ERROR)
    return {}
  end

  ---@type string[]
<<<<<<< HEAD
  local args = { "rg", "--json", "-n", "--column", "--hidden" } -- include hidden by default; cfg may override
  -- Respect config flags
  if cfg.smart_case     then args[#args+1] = "-S" end
  if cfg.literal        then args[#args+1] = "--fixed-strings" end
  if cfg.hidden == false then
    -- remove default hidden if user explicitly disabled it
    for i = #args, 1, -1 do if args[i] == "--hidden" then table.remove(args, i) end end
  end
  if cfg.git_ignore == false then args[#args+1] = "--no-ignore" end
=======
  local args = { "rg", "--json", "-n", "--column", "--hidden" }
  if cfg.smart_case then args[#args+1] = "-S" end
  if cfg.literal then args[#args+1] = "--fixed-strings" end
  if cfg.hidden == false then
    for i = #args, 1, -1 do if args[i] == "--hidden" then table.remove(args, i) end end
  end
  -- Check git_ignore field existence to avoid LSP warnings
  local respect_gitignore = cfg.git_ignore
  if respect_gitignore ~= nil and not respect_gitignore then
    args[#args+1] = "--no-ignore"
  end
>>>>>>> feature
  if cfg.exclude_git_dir then
    args[#args+1] = "--glob"
    args[#args+1] = "!.git"
  end

<<<<<<< HEAD
  -- Ask ripgrep to emit only-matching occurrences when possible so each match event
  -- corresponds to one occurrence. This helps rg emit separate match events instead
  -- of a single event with a single representative submatch.
  args[#args+1] = "-o"         -- --only-matching
=======
  args[#args+1] = "-o"
>>>>>>> feature
  args[#args+1] = old

  for i = 1, #roots do args[#args+1] = roots[i] end

  local res
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

<<<<<<< HEAD
  --- Helper: find all occurrences in a line when rg submatches are incomplete.
  --- Returns array of { start0=number, end0=number, text=string } where start0/end0 are 0-based byte offsets.
=======
>>>>>>> feature
  local function find_all_occurrences(line_text, pattern, literal)
    local out = {}
    if line_text == "" or not pattern then return out end

    if literal then
<<<<<<< HEAD
      -- plain substring search using byte offsets
=======
>>>>>>> feature
      local start = 1
      while true do
        local s, e = line_text:find(pattern, start, true)
        if not s then break end
        out[#out + 1] = { start0 = s - 1, end0 = e - 1, text = line_text:sub(s, e) }
        start = e + 1
      end
      return out
    else
<<<<<<< HEAD
      -- regex fallback using vim.fn.matchstrpos repeatedly
      -- matchstrpos returns: [matchtext, start, end, pre, post] where start/end are byte indices (0-based)
=======
>>>>>>> feature
      local pos = 0
      while true do
        local mt = vim.fn.matchstrpos(line_text, pattern, pos)
        local matched = mt[1]
        local s = mt[2]
        local e = mt[3]
        if s == -1 or not matched or matched == "" then break end
        out[#out + 1] = { start0 = s, end0 = e - 1, text = matched }
<<<<<<< HEAD
        -- advance position to after the matched substring (avoid zero-length loop)
=======
>>>>>>> feature
        pos = e
        if pos >= #line_text then break end
      end
      return out
    end
  end

  ---@type RP_Match[]
  local matches = {}
  local id = 0

<<<<<<< HEAD
  -- ripgrep --json prints one JSON object per line; collect "match" events.
  -- With -o we generally receive separate match events per occurrence, but be defensive:
  -- if submatches are empty or appear to contain only one entry while more occurrences exist,
  -- fall back to local scanning to produce multiple RP_Match entries.
=======
>>>>>>> feature
  for line in string.gmatch((res.stdout or ""), "([^\n]+)\n?") do
    local okj, ev = pcall(vim.json.decode, line)
    if not okj or not ev then goto continue end

    if ev.type ~= "match" or not ev.data then goto continue end
    local d = ev.data
    local path = (d.path and d.path.text) or ""
    local lnum = d.line_number or 0
    local text = (d.lines and d.lines.text) or ""
    local submatches = d.submatches

    if path == "" or lnum <= 0 then goto continue end

<<<<<<< HEAD
    -- Normalize line text (remove trailing newline)
    local line_text = tostring(text):gsub("\r?\n$", "")

    -- If ripgrep provided submatches, expand them all.
    if submatches and #submatches > 0 then
      -- If there is exactly one submatch but there may be more occurrences in the line,
      -- perform a defensive fallback scan and prefer the more complete result.
=======
    local line_text = tostring(text):gsub("\r?\n$", "")

    if submatches and #submatches > 0 then
>>>>>>> feature
      if #submatches == 1 then
        local sm = submatches[1]
        local s = sm.start
        local e = sm["end"]
        local rg_matched_text = (sm.match and sm.match.text) or old or ""
<<<<<<< HEAD
        -- Look for additional occurrences locally when possible
=======
>>>>>>> feature
        local local_occ = find_all_occurrences(line_text, old, cfg.literal)
        if #local_occ > 1 then
          for _, occ in ipairs(local_occ) do
            id = id + 1
            matches[#matches + 1] = {
              id = id,
              path = path,
              lnum = lnum,
              col0 = occ.start0,
              old = occ.text,
              line = line_text,
            }
          end
          goto continue
        end
<<<<<<< HEAD
        -- otherwise use the single submatch reported by rg
=======
>>>>>>> feature
        if type(s) == "number" and type(e) == "number" then
          id = id + 1
          matches[#matches + 1] = {
            id   = id,
            path = path,
            lnum = lnum,
            col0 = s,
            old  = rg_matched_text,
            line = line_text,
          }
        end
      else
<<<<<<< HEAD
        -- multiple submatches provided by rg: add each as separate match
=======
>>>>>>> feature
        for _, sm in ipairs(submatches) do
          local s = sm.start
          local e = sm["end"]
          if type(s) == "number" and type(e) == "number" then
            local matched_text = (sm.match and sm.match.text) or old or ""
            id = id + 1
            matches[#matches + 1] = {
              id   = id,
              path = path,
              lnum = lnum,
              col0 = s,
              old  = matched_text,
              line = line_text,
            }
          end
        end
      end
    else
<<<<<<< HEAD
      -- No submatches provided: fallback to local scanning of the line
=======
>>>>>>> feature
      local occs = find_all_occurrences(line_text, old, cfg.literal)
      for _, occ in ipairs(occs) do
        id = id + 1
        matches[#matches + 1] = {
          id   = id,
          path = path,
          lnum = lnum,
          col0 = occ.start0,
          old  = occ.text,
          line = line_text,
        }
      end
    end

    ::continue::
  end

  return matches
end

return {
  collect = collect,
}
