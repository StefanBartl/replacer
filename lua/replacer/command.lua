---@module 'replacer.command'
--- This module implements a shell-like argument tokenizer that preserves quoted
--- tokens (single or double quotes) and supports backslash escaping inside quotes.
--- It registers both :Replace and :Replacer user commands and accepts the
--- following variants (examples):
---
---   :Replace DAS DAS %
---   :Replace "DAS" "DAS" %
---   :Replace DAS "DAS mit leerzeichen" cwd
---   :Replace "DAS mit \"quote\"" "NEU" All
---
--- The scope token may be:
---   - % or buf         -> current buffer (file-backed)
---   - cwd or . or ""   -> current working directory (default)
---   - an explicit path  -> treated as file or directory
---   - All (case-insensitive) as final token to mean "replace all without confirm"
---
--- The command uses nargs="*" and parses the raw args string itself to avoid
--- Neovim pre-splitting/expansion issues. If Neovim expands '%' to an absolute
--- path before the handler sees it, the scope resolver detects that and treats
--- it as buffer scope when it matches the current buffer path.
---
--- Exported:
---   M.register(run_fun)  -- register commands; run_fun(old, new, scope, all)
---   M.resolve_scope(scope) -- resolve scope -> roots, single_file
local uv = vim.uv or vim.loop

--------------------------------------------------------------------------------
-- Tokenizer
--------------------------------------------------------------------------------

-- Extend tokenizer so backslash escapes are honored even outside of quotes.
-- This allows inputs like: :Replace \"test\" ok %

---@param s string
---@return string[] tokens
local function parse_args(s)
  local out = {} ---@type string[]
  if not s or s == "" then return out end

  local i, n = 1, #s
  while i <= n do
    -- skip whitespace
    while i <= n and s:sub(i,i):match("%s") do i = i + 1 end
    if i > n then break end

    local c = s:sub(i,i)
    if c == '"' or c == "'" then
      -- quoted token (existing behavior)
      local q = c
      i = i + 1
      local buf = {} ---@type string[]
      while i <= n do
        local ch = s:sub(i,i)
        if ch == "\\" and i < n then
          -- escape next char inside quotes
          buf[#buf+1] = s:sub(i+1,i+1)
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
      -- unquoted token, but honor backslash escapes here as well
      local j = i
      local buf = {} ---@type string[]
      while j <= n and not s:sub(j,j):match("%s") do
        local ch = s:sub(j,j)
        if ch == "\\" and j < n then
          -- consume backslash and take next char verbatim
          buf[#buf+1] = s:sub(j+1,j+1)
          j = j + 2
        else
          buf[#buf+1] = ch
          j = j + 1
        end
      end
      out[#out+1] = table.concat(buf)
      i = j
    end
  end

  return out
end

--------------------------------------------------------------------------------
-- Scope resolver
--------------------------------------------------------------------------------

---@param scope RP_Scope
---@return string[] roots, boolean single_file
local function resolve_scope(scope)
  -- normalize
  scope = scope or ""
  local scope_lc = scope:lower()

  -- if token is literal "%" or "buf", use current buffer file
  if scope_lc == "%" or scope_lc == "buf" then
    local f = vim.api.nvim_buf_get_name(0)
    if f == "" then
      vim.notify("[replacer] current buffer has no file path", vim.log.levels.ERROR)
      return {}, false
    end
    return { f }, true
  end

  -- If Neovim expanded '%' into the current file path before we saw it,
  -- detect that and treat as buffer scope.
  local cur = vim.api.nvim_buf_get_name(0)
  if cur ~= "" and scope ~= "" then
    local provided = vim.fn.fnamemodify(scope, ":p")
    local curp = vim.fn.fnamemodify(cur, ":p")
    if provided == curp then
      return { cur }, true
    end
  end

  -- Handle default/current-working-directory cases
  if scope == "" or scope_lc == "cwd" or scope_lc == "." then
    local ok, cwd = pcall(function() return uv.cwd() end)
    if not ok or not cwd then
      vim.notify("[replacer] failed to determine cwd", vim.log.levels.WARN)
      return {}, false
    end
    return { cwd }, false
  end

  -- explicit path: if directory -> multiple roots, if file -> single file
  local p = vim.fn.fnamemodify(scope, ":p")
  local is_dir = vim.fn.isdirectory(p) ~= 0
  return { p }, not is_dir
end

--------------------------------------------------------------------------------
-- Command registration
--------------------------------------------------------------------------------

---@class ReplacerCommand
local M = {}

--- Register :Replace and :Replacer user commands.
--- run_fun(old, new_text, scope, all)
---@param run_fun fun(old: string, new_text: string, scope: RP_Scope, all: boolean): nil
---@return nil
function M.register(run_fun)
  local function handler(opts)
    -- parse raw args string so quotes/spaces are preserved
    local args = parse_args(opts.args or "")
    if #args < 2 then
      vim.notify("Usage: :Replace {old} {new} {scope?} {All?}", vim.log.levels.ERROR)
      return
    end

    local old = args[1]
    local new_text = args[2]
    local scope = args[3] or ""
    local maybe_all = args[4] or ""
    local all = (type(maybe_all) == "string") and (maybe_all:lower() == "all") or false

    run_fun(old, new_text, scope, all)
  end

  local cmd_opts = {
    nargs = "*", -- receive raw args string; we parse ourselves
    complete = function(_, line)
      -- provide simple completion depending on how many tokens user typed
      local parts = parse_args(line)
      if #parts == 0 then
        return { "%", "cwd", ".", "All" }
      elseif #parts == 1 then
        return { "%", "cwd", ".", "All" }
      elseif #parts == 2 then
        return { "%", "cwd", ".", "All" }
      elseif #parts == 3 then
        return { "All" }
      end
      return {}
    end,
    desc = "Interactive replace: :Replace {old} {new} {scope?} {All?}",
  }

  -- Register both names for convenience
  vim.api.nvim_create_user_command("Replace", handler, cmd_opts)
  vim.api.nvim_create_user_command("Replacer", handler, cmd_opts)
end

M.resolve_scope = resolve_scope

return M
