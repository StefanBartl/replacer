---@module 'replacer.command'
--- Parse user command arguments, resolve scope (cwd/buffer/path),
--- and register the :Replace user command.
--- Exports: `register()` and `resolve_scope()` for reuse by the core.

local uv = vim.uv or vim.loop

--------------------------------------------------------------------------------
-- Argument parsing
--------------------------------------------------------------------------------

---@nodiscard
---@param s string
---@return string[]
local function parse_args(s)
  -- Robust shell-like split with quote handling ("..." or '...')
  local out ---@type string[]
  out = {}
  local i, n = 1, #s
  while i <= n do
    -- skip whitespace
    while i <= n and s:sub(i, i):match("%s") do i = i + 1 end
    if i > n then break end

    local c = s:sub(i, i)
    if c == "'" or c == '"' then
      -- quoted segment with simple \" / \' escaping
      local q = c
      i = i + 1
      local buf ---@type string[]
      buf = {}
      while i <= n do
        local ch = s:sub(i, i)
        if ch == "\\" and i < n then
          buf[#buf+1] = s:sub(i + 1, i + 1)
          i = i + 2
        elseif ch == q then
          i = i + 1
          break
        else
          buf[#buf+1] = ch
          i = i + 1
        end
      end
      out[#out+1] = table.concat(buf)
    else
      -- unquoted token
      local j = i
      while j <= n and not s:sub(j, j):match("%s") do j = j + 1 end
      out[#out+1] = s:sub(i, j - 1)
      i = j
    end
  end
  return out
end

--------------------------------------------------------------------------------
-- Scope resolution
--------------------------------------------------------------------------------

---@param scope RP_Scope
---@return string[] roots, boolean single_file
local function resolve_scope(scope)
  -- "%" / "buf" → current file (only if buffer is file-backed)
  if scope == "%" or scope == "buf" then
    local f = vim.api.nvim_buf_get_name(0)
    if f == "" then
      vim.notify("[replacer] current buffer has no file path", vim.log.levels.ERROR)
      return {}, false
    end
    return { f }, true
  end

  -- nil/""/"cwd"/"." → current working directory
  if scope == nil or scope == "" or scope == "cwd" or scope == "." then
    local cwd = uv.cwd()
    return { cwd }, false
  end

  -- explicit path (file or directory)
  local p = vim.fn.fnamemodify(scope, ":p")
  local is_dir = vim.fn.isdirectory(p) ~= 0
  return { p }, not is_dir
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

---@class ReplacerCommand
local M = {}

--- Register the :Replace user command.
---@param run_fun fun(old: string, new_text: string, scope: RP_Scope, all: boolean): nil
---@return nil
function M.register(run_fun)
  vim.api.nvim_create_user_command("Replace", function(opts)
    local args = parse_args(opts.args or "")
    if #args < 2 then
      vim.notify("Usage: :Replace {old} {new} {scope?} {All?}", vim.log.levels.ERROR)
      return
    end

    local old, new_text = args[1], args[2]
    local scope = args[3] or "cwd"    ---@type RP_Scope
    local maybe_all = args[4]
    local all = (type(maybe_all) == "string") and (maybe_all:lower() == "all") or false

    -- Hand off to core
    run_fun(old, new_text, scope, all)
  end, {
    nargs = "+",
    complete = function(_, line)
      local parts = parse_args(line)
      if #parts == 2 then return { "%", "cwd" } end
      if #parts == 3 then return { "%", "cwd", "All" } end
      if #parts == 4 then return { "All" } end
      return {}
    end,
    desc = "Interactive replace: :Replace {old} {new} {scope?} {All?}",
  })
end

-- Export scope resolver for reuse by the core module.
M.resolve_scope = resolve_scope

return M
