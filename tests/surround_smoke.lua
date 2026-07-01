-- Headless smoke test for the :Surround convenience layer.
-- Run:  nvim -l tests/surround_smoke.lua
-- Covers delimiter resolution, the shared tokenizer/flag helpers, the real
-- :Surround user command, and an end-to-end wrap across buffer/dir scopes.

vim.opt.runtimepath:append(vim.fn.getcwd())

local replacer = require("replacer")
local command  = require("replacer.command")
local surround = require("replacer.surround")

local pass, fail = 0, 0
local function check(name, cond, extra)
  if cond then
    pass = pass + 1
    print("PASS  " .. name)
  else
    fail = fail + 1
    print("FAIL  " .. name .. (extra and ("  -> " .. tostring(extra)) or ""))
  end
end

--------------------------------------------------------------------------------
-- 1) Delimiter resolution (literal chars, aliases, bracket pairs)
--------------------------------------------------------------------------------
local function delim(tok) return surround.resolve_delim(tok) end
do
  local l, r = delim("`");    check("delim: backtick literal", l == "`" and r == "`")
  l, r = delim("b");          check("delim: alias b -> backtick", l == "`" and r == "`")
  l, r = delim("q");          check("delim: alias q -> dquote", l == '"' and r == '"')
  l, r = delim("s");          check("delim: alias s -> squote", l == "'" and r == "'")
  l, r = delim("**");         check("delim: ** symmetric", l == "**" and r == "**")
  l, r = delim("bold");       check("delim: alias bold -> **", l == "**" and r == "**")
  l, r = delim("(");          check("delim: bare ( -> ( )", l == "(" and r == ")")
  l, r = delim("paren");      check("delim: alias paren -> ( )", l == "(" and r == ")")
  l, r = delim("@@");         check("delim: unknown -> symmetric literal", l == "@@" and r == "@@")
end

--------------------------------------------------------------------------------
-- 2) Shared command helpers are exported and behave
--------------------------------------------------------------------------------
do
  local toks = command.tokenize('"foo bar" b cwd --all')
  check("tokenize: quote-aware split", #toks == 4 and toks[1] == "foo bar" and toks[2] == "b")

  local req = { old = "", new = "", scope = "", all = false, dry = false, export = nil,
    line_range = nil, overrides = {}, filters = { file_types = {}, globs = {}, exclude = {} } }
  local pos = command.apply_tokens(toks, req)
  check("apply_tokens: positionals + flag applied", pos and #pos == 3 and req.all == true, pos and #pos)

  local _, err = command.apply_tokens(command.tokenize("x --bogus"), {
    old = "", new = "", scope = "", all = false, dry = false, overrides = {},
    filters = { file_types = {}, globs = {}, exclude = {} } })
  check("apply_tokens: unknown flag -> error", err and err:match("unknown option"), err)
end

--------------------------------------------------------------------------------
-- 3) Real :Surround user command (bang = --all, alias delimiter, file scope)
--------------------------------------------------------------------------------
replacer.setup({ search_engine = "vimgrep", confirm_all = false, write_changes = true })
vim.g.__replacer_cmd_registered = nil
vim.cmd("source " .. vim.fn.getcwd() .. "/plugin/replacer.lua")
check("register: :Surround exists", vim.fn.exists(":Surround") == 2)
check("register: :Wrap exists", vim.fn.exists(":Wrap") == 2)

local tmp = vim.fn.tempname(); vim.fn.mkdir(tmp, "p")
do
  local fa = tmp .. "/c.txt"
  local fh = assert(io.open(fa, "w")); fh:write("alpha beta alpha\nalpha\n"); fh:close()
  vim.cmd(string.format("Surround! alpha b %s", fa))
  vim.wait(300)
  local c = assert(io.open(fa, "r")):read("*a")
  check("cmd: word -> `word` (3x)", select(2, c:gsub("`alpha`", "")) == 3, c)
  check("cmd: no bare word remains", not c:match("[^`]alpha[^`]") and not c:match("^alpha[^`]"), c)
end

--------------------------------------------------------------------------------
-- 4) Directory-scope wrap with a multi-char delimiter (markdown bold)
--------------------------------------------------------------------------------
do
  local fb = tmp .. "/b.md"
  local fh = assert(io.open(fb, "w")); fh:write("TODO and TODO\n"); fh:close()
  vim.cmd(string.format("Surround! TODO bold %s", tmp))
  vim.wait(300)
  local c = assert(io.open(fb, "r")):read("*a")
  check("cmd: dir scope TODO -> **TODO** (2x)", select(2, c:gsub("%*%*TODO%*%*", "")) == 2, c)
end

--------------------------------------------------------------------------------
print(string.format("\n=== %d passed, %d failed ===", pass, fail))
if fail > 0 then vim.cmd("cquit 1") end
