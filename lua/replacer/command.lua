---@module 'replacer.command'
--- Parse user command arguments, resolve scope (cwd/buffer/path),
--- and register the :Replace user command.
--- Exports: `register()` and `resolve_scope()` for reuse by the core.
--- Notes:
---  - We reuse the existing `parse_args` (shell-like splitter with quotes).
---  - A thin flags layer is built on top of `parse_args` to support:
---      --regex/-R, --literal/-L, --confirm, --no-confirm, and (compat) --all/-a/All.

local uv = vim.uv or vim.loop
local cfg_mod = require("replacer.config") -- for default_scope, confirm policy overrides (if core supports)

--------------------------------------------------------------------------------
-- Argument parsing (kept)
--------------------------------------------------------------------------------

---@nodiscard
---@param s string
---@return string[]
local function parse_args(s)
  -- ... (unchanged; your robust implementation)
  local out ---@type string[]
  out = {}
  local i, n = 1, #s
  while i <= n do
    while i <= n and s:sub(i, i):match("%s") do i = i + 1 end
    if i > n then break end
    local c = s:sub(i, i)
    if c == "'" or c == '"' then
      local q = c; i = i + 1
      local buf ---@type string[]; buf = {}
      while i <= n do
        local ch = s:sub(i, i)
        if ch == "\\" and i < n then
          buf[#buf + 1] = s:sub(i + 1, i + 1)
          i = i + 2
        elseif ch == q then
          i = i + 1
          break
        else
          buf[#buf + 1] = ch
          i = i + 1
        end
      end
      out[#out + 1] = table.concat(buf)
    else
      local j = i
      while j <= n and not s:sub(j, j):match("%s") do j = j + 1 end
      out[#out + 1] = s:sub(i, j - 1)
      i = j
    end
  end
  return out
end

--------------------------------------------------------------------------------
-- Scope resolution (kept)
--------------------------------------------------------------------------------

---@param scope RP_Scope
---@return string[] roots, boolean single_file
local function resolve_scope(scope)
  if scope == "%" or scope == "buf" then
    local f = vim.api.nvim_buf_get_name(0)
    if f == "" then
      vim.notify("[replacer] current buffer has no file path", vim.log.levels.ERROR)
      return {}, false
    end
    return { f }, true
  end

  if scope == nil or scope == "" or scope == "cwd" or scope == "." then
    local cwd = uv.cwd()
    return { cwd }, false
  end

  local p = vim.fn.fnamemodify(scope, ":p")
  local is_dir = vim.fn.isdirectory(p) ~= 0
  return { p }, not is_dir
end

--------------------------------------------------------------------------------
-- Flags layer on top of parse_args
--------------------------------------------------------------------------------

---@class RP_CliFlags
---@field regex boolean|nil
---@field literal boolean|nil
---@field confirm boolean|nil
---@field noconfirm boolean|nil
---@field all boolean|nil      -- compat: --all/-a/All

---@param parts string[]
---@return string old, string new_text, string|nil scope, RP_CliFlags flags
local function split_positionals_and_flags(parts)
  local pos = {} ---@type string[]
  local flags = { } ---@type RP_CliFlags

  for _, p in ipairs(parts) do
    if p == "--regex" or p == "-R" then
      flags.regex, flags.literal = true, false
    elseif p == "--literal" or p == "-L" then
      flags.literal, flags.regex = true, false
    elseif p == "--confirm" then
      flags.confirm = true
    elseif p == "--no-confirm" then
      flags.noconfirm = true
    elseif p == "--all" or p == "-a" or p:lower() == "all" then
      flags.all = true -- compatibility with old invocations
    else
      pos[#pos + 1] = p
    end
  end

  local old = pos[1] or ""
  local new_text = pos[2] or ""
  local scope = pos[3] -- optional
  return old, new_text, scope, flags
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

---@class ReplacerCommand
local M = {}

--- Register the :Replace user command.
--- `run_fun` signature stays backward compatible:
---   run_fun(old, new_text, scope, all)
--- If your core later supports per-run overrides, you can extend it to:
---   run_fun(old, new_text, scope, all, overrides)
---@param run_fun fun(old: string, new_text: string, scope: RP_Scope, all: boolean): nil
---@return nil
function M.register(run_fun)
  vim.api.nvim_create_user_command("Replace", function(opts)
    local parts = parse_args(opts.args or "")
    if #parts < 2 then
      vim.notify("Usage: :Replace[!] {old} {new} {scope?} [--regex|-R|--literal|-L] [--confirm|--no-confirm] [--all|-a|All]", vim.log.levels.ERROR)
      return
    end

    local old, new_text, scope_arg, flags = split_positionals_and_flags(parts)

    -- Guard: empty 'old' is dangerous (matches everything)
    if old == "" then
      vim.notify("[replacer] 'old' must not be empty", vim.log.levels.ERROR)
      return
    end

    -- Default scope from config when omitted
    local cfg = cfg_mod.get()
    local scope = scope_arg
    if scope == nil or scope == "" then
      scope = cfg.default_scope or "%"
    end

    -- Optional soft guard for wide scopes (when picker is used)
    if cfg.confirm_wide_scope and scope ~= "%" and not opts.bang then
      local msg = string.format("Scope '%s' (not current file). Continue to open picker?", scope)
      if vim.fn.confirm(msg, "&Yes\n&No", 2) ~= 1 then
        vim.notify("[replacer] cancelled")
        return
      end
    end

    -- Determine "ALL" mode:
    --  - New style: Bang means non-interactive ALL in scope
    --  - Compat:    --all/-a/All still toggles ALL
    local flag_all = opts.bang or flags.all or false

    -- (Optional) Per-run overrides of config (if your core supports it):
    --   - regex/literal mode
    --   - confirm_all for ALL ops
    -- If your core doesn't yet take overrides, you can ignore these here,
    -- or set them into a temporary config scope.
    -- Example (if later extended): local overrides = { }
    -- if flags.regex   ~= nil then overrides.literal = not flags.regex end
    -- if flags.literal ~= nil then overrides.literal = flags.literal end
    -- if flags.confirm == true then overrides.confirm_all = true end
    -- if flags.noconfirm == true then overrides.confirm_all = false end
    --
    -- For now we keep the old `run_fun` signature:
    run_fun(old, new_text, scope, flag_all)
  end, {
    nargs = "+",
    bang = true, -- allow :Replace!
    complete = function(_, line)
      local parts = parse_args(line)
      if #parts == 2 then
        return { "%", "cwd", "." }
      elseif #parts == 3 then
        return { "%", "cwd", "." }
      else
        return { "--literal", "-L", "--regex", "-R", "--confirm", "--no-confirm", "--all", "-a" }
      end
    end,
    desc = "Find & replace. Use :Replace! for non-interactive ALL in scope. Flags: --literal/-L, --regex/-R, --confirm/--no-confirm",
  })
end

-- Export scope resolver for reuse by the core module.
M.resolve_scope = resolve_scope

return M
