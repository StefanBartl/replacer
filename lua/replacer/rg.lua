---@module 'replacer.rg'
--- Match collection with selectable backend.
---
--- Backends:
---   - ripgrep : fast, honors .gitignore / --type / --glob (requires `rg`)
---   - vimgrep : native Lua scanner (no external deps), used as automatic
---               fallback when ripgrep is unavailable or when forced via config.
---
--- Both backends:
---   - emit one RP_Match per occurrence (multiple hits on a line -> multiple
---     selectable entries),
---   - operate on byte offsets (col0) to stay consistent with apply.lua,
---   - honor `cfg.file_types` / `cfg.globs` / `cfg.exclude` filters,
---   - restrict to `cfg._line_range` (a {l1,l2} span) when present.
---
--- A modified, file-backed buffer is scanned from its in-memory content to avoid
--- stale coordinates against the on-disk file.

local M = {}

--------------------------------------------------------------------------------
-- Shared: occurrence scanning
--------------------------------------------------------------------------------

--- Find every occurrence of `pattern` in `line_text`.
--- Literal mode uses plain byte search; regex mode uses Vim regex via matchstrpos.
---@param line_text string
---@param pattern string
---@param literal boolean
---@return { start0: integer, end0: integer, text: string }[]
local function find_all_occurrences(line_text, pattern, literal)
  local out = {}
  if line_text == "" or not pattern or pattern == "" then return out end

  local n = 0 -- explicit index avoids recomputing #out per append
  if literal then
    local start = 1
    while true do
      local s, e = line_text:find(pattern, start, true)
      if not s then break end
      n = n + 1
      out[n] = { start0 = s - 1, end0 = e - 1, text = line_text:sub(s, e) }
      start = e + 1
    end
  else
    local pos = 0
    while true do
      local mt = vim.fn.matchstrpos(line_text, pattern, pos)
      local matched, s, e = mt[1], mt[2], mt[3]
      if s == -1 or not matched or matched == "" then break end
      n = n + 1
      out[n] = { start0 = s, end0 = e - 1, text = matched }
      pos = e
      if pos >= #line_text then break end
    end
  end
  return out
end

--------------------------------------------------------------------------------
-- Buffer-aware fast path
--------------------------------------------------------------------------------

---@param path string
---@return boolean modified, integer|nil bufnr
local function is_buffer_modified(path)
  local bufnr = vim.fn.bufnr(path)
  if bufnr == -1 then return false, nil end
  if not vim.api.nvim_buf_is_loaded(bufnr) then return false, nil end
  return vim.bo[bufnr].modified, bufnr
end

---@param old string
---@param bufnr integer
---@param cfg RP_RG_Config
---@return RP_Match[]
local function collect_from_buffer(old, bufnr, cfg)
  local path = vim.api.nvim_buf_get_name(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local matches = {}
  local id = 0

  for lnum, line in ipairs(lines) do
    local occs = find_all_occurrences(line, old, cfg.literal)
    for _, occ in ipairs(occs) do
      id = id + 1
      -- id is the running occurrence count, so it is also the next array index.
      matches[id] = {
        id = id, path = path, lnum = lnum, col0 = occ.start0, old = occ.text, line = line,
      }
    end
  end
  return matches
end

--------------------------------------------------------------------------------
-- ripgrep backend
--------------------------------------------------------------------------------

--- Build the ripgrep argument vector from config + filters.
---@param old string
---@param roots string[]
---@param cfg RP_RG_Config
---@return string[]
local function build_rg_args(old, roots, cfg)
  local args = { "rg", "--json", "-n", "--column", "--hidden", "-o" }

  if cfg.smart_case then args[#args + 1] = "-S" end
  if cfg.literal then args[#args + 1] = "--fixed-strings" end
  if cfg.hidden == false then
    for i = #args, 1, -1 do if args[i] == "--hidden" then table.remove(args, i) end end
  end
  if cfg.git_ignore == false then args[#args + 1] = "--no-ignore" end
  if cfg.exclude_git_dir then
    args[#args + 1] = "--glob"; args[#args + 1] = "!.git"
  end

  -- Filters
  for _, ft in ipairs(cfg.file_types or {}) do
    args[#args + 1] = "--type"; args[#args + 1] = ft
  end
  for _, g in ipairs(cfg.globs or {}) do
    args[#args + 1] = "--glob"; args[#args + 1] = g
  end
  for _, ex in ipairs(cfg.exclude or {}) do
    -- A bare word excludes a directory subtree anywhere; an explicit glob is used as-is.
    if not ex:find("[*/?%[]") then
      args[#args + 1] = "--glob"; args[#args + 1] = "!**/" .. ex .. "/**"
      args[#args + 1] = "--glob"; args[#args + 1] = "!" .. ex
    else
      args[#args + 1] = "--glob"; args[#args + 1] = "!" .. ex
    end
  end

  args[#args + 1] = old
  for i = 1, #roots do args[#args + 1] = roots[i] end
  return args
end

--- Parse ripgrep `--json` stdout into a flat list of matches.
---@param stdout string
---@param old string
---@param cfg RP_RG_Config
---@return RP_Match[]
local function parse_rg_json(stdout, old, cfg)
  ---@type RP_Match[]
  local matches = {}
  local id = 0

  for line in string.gmatch((stdout or ""), "([^\n]+)\n?") do
    local okj, ev = pcall(vim.json.decode, line)
    if okj and ev and ev.type == "match" and ev.data then
      local d = ev.data
      local path = (d.path and d.path.text) or ""
      local lnum = d.line_number or 0
      local text = (d.lines and d.lines.text) or ""
      local submatches = d.submatches

      if path ~= "" and lnum > 0 then
        local line_text = tostring(text):gsub("\r?\n$", "")

        if submatches and #submatches > 0 then
          if #submatches == 1 then
            -- Defensive: rg may report one submatch where the line holds several.
            local local_occ = find_all_occurrences(line_text, old, cfg.literal)
            if #local_occ > 1 then
              for _, occ in ipairs(local_occ) do
                id = id + 1
                matches[id] = {
                  id = id, path = path, lnum = lnum, col0 = occ.start0, old = occ.text, line = line_text,
                }
              end
            else
              local sm = submatches[1]
              if type(sm.start) == "number" then
                id = id + 1
                matches[id] = {
                  id = id, path = path, lnum = lnum, col0 = sm.start,
                  old = (sm.match and sm.match.text) or old or "", line = line_text,
                }
              end
            end
          else
            for _, sm in ipairs(submatches) do
              if type(sm.start) == "number" then
                id = id + 1
                matches[id] = {
                  id = id, path = path, lnum = lnum, col0 = sm.start,
                  old = (sm.match and sm.match.text) or old or "", line = line_text,
                }
              end
            end
          end
        else
          for _, occ in ipairs(find_all_occurrences(line_text, old, cfg.literal)) do
            id = id + 1
            matches[id] = {
              id = id, path = path, lnum = lnum, col0 = occ.start0, old = occ.text, line = line_text,
            }
          end
        end
      end
    end
  end

  return matches
end

--- Run ripgrep synchronously and parse the result.
---@param old string
---@param roots string[]
---@param cfg RP_RG_Config
---@return RP_Match[]
local function collect_ripgrep(old, roots, cfg)
  local args = build_rg_args(old, roots, cfg)
  if vim.system then
    local obj = vim.system(args, { text = true }):wait()
    local code = obj and obj.code or 1
    if code ~= 0 and code ~= 1 then
      vim.notify("[replacer] rg failed: " .. (obj and obj.stderr or ""), vim.log.levels.ERROR)
      return {}
    end
    return parse_rg_json(obj and obj.stdout or "", old, cfg)
  end
  local out = vim.fn.system(table.concat(vim.tbl_map(vim.fn.shellescape, args), " "))
  if vim.v.shell_error ~= 0 and vim.v.shell_error ~= 1 then
    vim.notify("[replacer] rg failed (sync): " .. (out or ""), vim.log.levels.ERROR)
    return {}
  end
  return parse_rg_json(out, old, cfg)
end

--- Run ripgrep asynchronously (non-blocking). Falls back to sync when
--- `vim.system` is unavailable. Errors are passed to `on_done` (not notified
--- here) so the calling layer decides how to surface them.
---@param old string
---@param roots string[]
---@param cfg RP_RG_Config
---@param on_done fun(items: RP_Match[]|nil, err: RP_Error|nil)
local function collect_ripgrep_async(old, roots, cfg, on_done)
  if not vim.system then
    on_done(collect_ripgrep(old, roots, cfg), nil)
    return
  end
  local args = build_rg_args(old, roots, cfg)
  vim.system(args, { text = true }, function(obj)
    -- on_exit runs off the main loop; re-enter it before any vim.* work.
    vim.schedule(function()
      local code = obj and obj.code or 1
      if code ~= 0 and code ~= 1 then
        on_done(nil, require("replacer.error").search_error(
          "ripgrep failed", obj and obj.stderr or nil))
        return
      end
      on_done(parse_rg_json(obj and obj.stdout or "", old, cfg), nil)
    end)
  end)
end

--------------------------------------------------------------------------------
-- vimgrep (native) backend
--------------------------------------------------------------------------------

--- Decide whether a file path passes the configured filters.
---@param path string
---@param cfg RP_RG_Config
---@return boolean
local function passes_filters(path, cfg)
  local name = vim.fn.fnamemodify(path, ":t")

  if cfg.hidden == false and name:sub(1, 1) == "." then return false end

  -- file_types are interpreted as extensions in native mode
  local types = cfg.file_types or {}
  if #types > 0 then
    local ext = name:match("%.([%w_]+)$")
    local ok = false
    for _, ft in ipairs(types) do if ext == ft then ok = true break end end
    if not ok then return false end
  end

  -- include globs (filename must match at least one)
  local globs = cfg.globs or {}
  if #globs > 0 then
    local ok = false
    for _, g in ipairs(globs) do
      if vim.fn.match(name, vim.fn.glob2regpat(g)) >= 0 then ok = true break end
    end
    if not ok then return false end
  end

  -- excludes (substring match anywhere in the path)
  for _, ex in ipairs(cfg.exclude or {}) do
    if path:find(ex, 1, true) then return false end
  end

  return true
end

--- Recursively list candidate files under a root directory.
---@param root string
---@param cfg RP_RG_Config
---@param acc string[]
local function list_files(root, cfg, acc)
  local ok, iter = pcall(vim.fs.dir, root, { depth = 32 })
  if not ok or not iter then return end
  local n = #acc
  for name, typ in iter do
    if typ == "file" then
      if cfg.exclude_git_dir and name:find("%.git[/\\]") then
        -- skip .git subtree
      else
        local full = root .. "/" .. name
        if passes_filters(full, cfg) then
          n = n + 1
          acc[n] = full
        end
      end
    end
  end
end

--- Scan a single file's lines for occurrences.
---@param old string
---@param path string
---@param cfg RP_RG_Config
---@param id_start integer
---@param acc RP_Match[]
---@return integer next_id
local function scan_file(old, path, cfg, id_start, acc)
  local id = id_start
  local ok, fh = pcall(io.open, path, "r")
  if not ok or not fh then return id end
  local lnum = 0
  for line in fh:lines() do
    lnum = lnum + 1
    local occs = find_all_occurrences(line, old, cfg.literal)
    for _, occ in ipairs(occs) do
      id = id + 1
      -- Invariant: id == #acc, so id is also the next array index.
      acc[id] = {
        id = id, path = path, lnum = lnum, col0 = occ.start0, old = occ.text, line = line,
      }
    end
  end
  fh:close()
  return id
end

---@param old string
---@param roots string[]
---@param cfg RP_RG_Config
---@return RP_Match[]
local function collect_vimgrep(old, roots, cfg)
  ---@type RP_Match[]
  local matches = {}
  local id = 0
  for _, root in ipairs(roots) do
    if vim.fn.isdirectory(root) ~= 0 then
      local files = {} ---@type string[]
      list_files(root, cfg, files)
      for _, f in ipairs(files) do
        id = scan_file(old, f, cfg, id, matches)
      end
    elseif passes_filters(root, cfg) then
      id = scan_file(old, root, cfg, id, matches)
    end
  end
  return matches
end

--------------------------------------------------------------------------------
-- Backend selection
--------------------------------------------------------------------------------

--- Resolve the effective search backend, applying the ripgrep->vimgrep fallback.
---@param cfg RP_RG_Config
---@return "ripgrep"|"vimgrep"
local function pick_backend(cfg)
  local want = cfg.search_engine or "auto"
  local has_rg = vim.fn.executable("rg") == 1
  if want == "vimgrep" then return "vimgrep" end
  if want == "ripgrep" then
    if has_rg then return "ripgrep" end
    vim.notify("[replacer] ripgrep not found — falling back to vimgrep", vim.log.levels.WARN)
    return "vimgrep"
  end
  return has_rg and "ripgrep" or "vimgrep"
end

--- Restrict items to cfg._line_range (a {l1,l2} span) when present.
---@param items RP_Match[]
---@param cfg RP_RG_Config
---@return RP_Match[]
local function apply_line_range(items, cfg)
  local range = cfg._line_range
  if type(range) ~= "table" then return items end
  local l1, l2 = range[1], range[2]
  if type(l1) ~= "number" or type(l2) ~= "number" then return items end
  local out = {}
  local n = 0
  for _, it in ipairs(items) do
    if it.lnum >= l1 and it.lnum <= l2 then
      n = n + 1
      out[n] = it
    end
  end
  return out
end

--------------------------------------------------------------------------------
-- Public entry
--------------------------------------------------------------------------------

--- Collect matches for `old` under `roots` using the configured backend.
---@param old string
---@param roots string[]
---@param cfg RP_RG_Config
---@return RP_Match[]
function M.collect(old, roots, cfg)
  -- Modified, file-backed single buffer: scan in-memory content.
  if #roots == 1 then
    local modified, bufnr = is_buffer_modified(roots[1])
    if modified and bufnr then
      vim.notify("[replacer] scanning modified buffer instead of disk", vim.log.levels.INFO)
      return apply_line_range(collect_from_buffer(old, bufnr, cfg), cfg)
    end
  end

  local backend = pick_backend(cfg)
  local items = (backend == "ripgrep")
    and collect_ripgrep(old, roots, cfg)
    or collect_vimgrep(old, roots, cfg)

  return apply_line_range(items, cfg)
end

--- Collect matches asynchronously, invoking `on_done(items, err)` when ready.
--- ripgrep runs non-blocking (no UI freeze on large repos); the native vimgrep
--- backend and the modified-buffer fast path complete synchronously and call
--- `on_done` immediately. Errors are reported via `err` (the caller notifies).
---@param old string
---@param roots string[]
---@param cfg RP_RG_Config
---@param on_done fun(items: RP_Match[]|nil, err: RP_Error|nil)
---@return nil
function M.collect_async(old, roots, cfg, on_done)
  -- Modified, file-backed single buffer: scan in-memory content (sync).
  if #roots == 1 then
    local modified, bufnr = is_buffer_modified(roots[1])
    if modified and bufnr then
      vim.notify("[replacer] scanning modified buffer instead of disk", vim.log.levels.INFO)
      on_done(apply_line_range(collect_from_buffer(old, bufnr, cfg), cfg), nil)
      return
    end
  end

  if pick_backend(cfg) == "ripgrep" then
    collect_ripgrep_async(old, roots, cfg, function(items, err)
      if err then
        on_done(nil, err)
      else
        on_done(apply_line_range(items, cfg), nil)
      end
    end)
  else
    on_done(apply_line_range(collect_vimgrep(old, roots, cfg), cfg), nil)
  end
end

return M
