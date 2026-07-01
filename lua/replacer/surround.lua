---@module 'replacer.surround'
--- Convenience layer over the replace engine: wrap every occurrence of a
--- pattern with a delimiter (backticks, quotes, markdown emphasis, brackets …).
---
--- `:Surround {pattern}` is exactly a literal `:Replace` where the replacement
--- is `<left><pattern><right>`, so it inherits the full pipeline for free:
--- scope resolution (%/cwd/./<path>), ripgrep matching, dry-run preview,
--- interactive picker, non-interactive --all, and confirmation prompts.
---
--- Grammar:
---   :[range]Surround[!] {pattern} [delim] [scope] [--flags...]
---
---   {pattern}  literal text to search for (regex is not supported here — the
---              replacement is a fixed string, so each spot must be identical)
---   [delim]    the wrapper: a literal char/string ( ` " ' * ** _ ), a named
---              alias (see ALIASES), or a bracket pair (( ) [ ] { } < >).
---              When omitted, you are prompted for it.
---   [scope]    %|buf · cwd|. · <file|dir>   (default: config.default_scope)
---
--- Flags are identical to :Replace (--all, --dry, --hidden, --type=, …). The
--- bang form (:Surround!) is shorthand for --all. Regex mode is force-disabled.
---
--- Examples:
---   :Surround word `            → `word`   in the current buffer
---   :Surround word b            → `word`   ("b" is an alias for backtick)
---   :Surround "foo bar" ** cwd  → **foo bar**  across the working directory
---   :Surround TODO ( .          → (TODO)  project-wide, all files
---   :Surround! name q %         → "name"  everywhere in the buffer, no picker

local command = require("replacer.command")

local M = {}

--------------------------------------------------------------------------------
-- Delimiter resolution
--------------------------------------------------------------------------------

--- Named delimiters. A value is either a symmetric string (used on both sides)
--- or a { left, right } pair for asymmetric wrappers (brackets).
---@type table<string, string|string[]>
local ALIASES = {
  -- backtick
  b = "`", bt = "`", backtick = "`", tick = "`", code = "`",
  -- double quote
  q = '"', dq = '"', quote = '"', quotes = '"',
  -- single quote
  s = "'", sq = "'", single = "'", apos = "'",
  -- markdown emphasis
  star = "*", asterisk = "*",
  bold = "**", strong = "**",
  italic = "_", underscore = "_", us = "_",
  -- brackets / braces (asymmetric)
  paren = { "(", ")" }, parens = { "(", ")" }, round = { "(", ")" },
  bracket = { "[", "]" }, brackets = { "[", "]" }, square = { "[", "]" },
  brace = { "{", "}" }, braces = { "{", "}" }, curly = { "{", "}" },
  angle = { "<", ">" }, angles = { "<", ">" },
}

--- Bare bracket openers → their matching close, so ":Surround x (" works.
---@type table<string, string>
local BRACKET_CLOSE = { ["("] = ")", ["["] = "]", ["{"] = "}", ["<"] = ">" }

--- Resolve a delimiter token into the left/right strings placed around a match.
---@param tok string
---@return string left, string right
local function resolve_delim(tok)
  local alias = ALIASES[tok:lower()]
  if type(alias) == "table" then
    return alias[1], alias[2]
  elseif type(alias) == "string" then
    return alias, alias
  end
  -- A lone opening bracket implies its matching close; otherwise symmetric.
  local close = BRACKET_CLOSE[tok]
  if close then return tok, close end
  return tok, tok
end

--------------------------------------------------------------------------------
-- Request construction
--------------------------------------------------------------------------------

local USAGE =
  "Usage: :[range]Surround[!] {pattern} [delim] [scope] [--flags]   (delim aliases: b ` , q \", s ', star, bold, paren …)"

--- Build the RP_Request for wrapping `pattern` with the resolved delimiter,
--- carrying over scope/flags and range. Search is forced to literal mode.
---@param pattern string
---@param delim string
---@param scope string
---@param req RP_Request        # already carries flags applied by apply_tokens
---@param line_range integer[]|nil
---@return RP_Request
local function build_request(pattern, delim, scope, req, line_range)
  local left, right = resolve_delim(delim)
  req.old        = pattern
  req.new        = left .. pattern .. right
  req.scope      = scope or ""
  req.line_range = line_range
  -- Regex would need per-match capture expansion, which the applier does not do;
  -- force literal so `new` is a valid fixed replacement for every spot.
  req.overrides.literal = true
  return req
end

--------------------------------------------------------------------------------
-- Command handler
--------------------------------------------------------------------------------

--- Parse args, resolve the delimiter (prompting when absent), then run.
---@param run_fun fun(request: RP_Request): nil
---@param opts table              # nvim user-command opts
local function handle(run_fun, opts)
  local raw = (type(opts.args) == "string") and opts.args or ""
  local tokens = command.tokenize(raw)

  ---@type RP_Request
  local req = {
    old = "", new = "", scope = "",
    all = opts.bang and true or false,
    dry = false, export = nil, line_range = nil,
    overrides = {},
    filters = { file_types = {}, globs = {}, exclude = {} },
  }

  local positionals, err = command.apply_tokens(tokens, req)
  if not positionals then
    vim.schedule(function() vim.notify(err, vim.log.levels.ERROR) end)
    return
  end

  if #positionals < 1 then
    vim.schedule(function()
      vim.notify("Surround: missing {pattern}.\n" .. USAGE, vim.log.levels.ERROR)
    end)
    return
  end
  if #positionals > 3 then
    vim.schedule(function()
      vim.notify(string.format(
        "Surround: too many arguments — got %d; expected {pattern} [delim] [scope]. " ..
        "Quote values with spaces, e.g. :Surround \"foo bar\" `.\n%s",
        #positionals, USAGE), vim.log.levels.ERROR)
    end)
    return
  end

  local pattern = positionals[1]
  local delim   = positionals[2]
  local scope   = positionals[3] or ""

  -- Range (e.g. :'<,'>Surround) restricts to the current buffer line span.
  local line_range
  if type(opts.range) == "number" and opts.range > 0 then
    local l1, l2 = opts.line1 or 1, opts.line2 or (opts.line1 or 1)
    if l2 < l1 then l1, l2 = l2, l1 end
    line_range = { l1, l2 }
    if scope == "" then scope = "%" end
  end

  local function finish(d)
    if not d or d == "" then
      vim.notify("Surround: cancelled (no delimiter)", vim.log.levels.INFO)
      return
    end
    run_fun(build_request(pattern, d, scope, req, line_range))
  end

  if delim == nil then
    -- Prompt asynchronously; :Surround word  → ask what to wrap with.
    vim.ui.input({ prompt = "Surround with: " }, function(input)
      finish(input and vim.trim(input) or nil)
    end)
  else
    finish(delim)
  end
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

local COMPLETIONS = {
  -- delimiters / aliases
  "`", '"', "'", "*", "**", "_", "(", "[", "{", "<",
  "b", "q", "s", "star", "bold", "italic", "paren", "bracket", "brace", "angle",
  -- scopes
  "%", "cwd", ".",
  -- flags (mirror :Replace)
  "--literal", "--smart-case", "--hidden", "--no-ignore",
  "--type=", "--glob=", "--exclude=", "--engine=", "--context=",
  "--dry", "--export=", "--all",
}

--- Register :Surround (and :Wrap alias). `run_fun` is replacer.run.
---@param run_fun fun(request: RP_Request): nil
---@return nil
function M.register(run_fun)
  local cmd_opts = {
    nargs = "*",
    bang = true,
    range = true,
    complete = function(arglead, _, _)
      if arglead == "" then return COMPLETIONS end
      local out = {}
      for _, c in ipairs(COMPLETIONS) do
        if c:sub(1, #arglead) == arglead then out[#out + 1] = c end
      end
      return out
    end,
    desc = "Wrap every match of a pattern: :[range]Surround[!] {pattern} [delim] [scope] [--flags]",
  }

  vim.api.nvim_create_user_command("Surround", function(o) handle(run_fun, o) end, cmd_opts)
  vim.api.nvim_create_user_command("Wrap", function(o) handle(run_fun, o) end, cmd_opts)
end

-- Exposed for tests.
M.resolve_delim = resolve_delim

return M
