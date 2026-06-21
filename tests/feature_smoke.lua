-- Headless smoke test for the replacer feature set.
-- Run:  nvim -l tests/feature_smoke.lua
-- Exercises engine-agnostic paths (no fzf-lua/telescope required):
--   request parsing, error messages, range, native (vimgrep) search,
--   multi-occurrence-per-line, pure edit computation, dry-run, export, real apply.

vim.opt.runtimepath:append(vim.fn.getcwd())

local ok_mod, replacer = pcall(require, "replacer")
assert(ok_mod, "failed to require replacer: " .. tostring(replacer))
local command = require("replacer.command")
local rg = require("replacer.rg")
local apply = require("replacer.apply")
local export = require("replacer.export")

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
-- 1) Request parsing & error messages
--------------------------------------------------------------------------------
do
  local ok, req = command.parse_request("foo bar")
  check("parse: basic positional", ok and req.old == "foo" and req.new == "bar" and req.scope == "")

  local ok2, _, err2 = command.parse_request("foo")
  check("parse: missing arg -> error", (not ok2) and err2:match("missing"), err2)

  local ok3, _, err3 = command.parse_request("a b c d")
  check("parse: too many -> error", (not ok3) and err3:match("too many"), err3)

  local ok4, _, err4 = command.parse_request("foo bar --bogus")
  check("parse: unknown flag -> error", (not ok4) and err4:match("unknown option"), err4)

  local ok5, req5 = command.parse_request(
    'foo bar % --regex --type=lua --glob=*.x --exclude=node --dry --export=plan.json')
  check("parse: flags collected", ok5
    and req5.overrides.literal == false
    and req5.dry == true
    and req5.export == "plan.json"
    and req5.filters.file_types[1] == "lua"
    and req5.filters.globs[1] == "*.x"
    and req5.filters.exclude[1] == "node",
    req5 and vim.inspect(req5.filters))

  local ok6, req6 = command.parse_request("foo bar --type lua")
  check("parse: space-separated value flag", ok6 and req6.filters.file_types[1] == "lua")

  local ok7, req7 = command.parse_request("foo bar", { range = 2, line1 = 5, line2 = 2 })
  check("parse: range normalizes + forces buffer scope",
    ok7 and req7.line_range[1] == 2 and req7.line_range[2] == 5 and req7.scope == "%")

  local ok8, req8 = command.parse_request("foo bar baz", { bang = true })
  check("parse: bang -> all", ok8 and req8.all == true and req8.scope == "baz")
end

--------------------------------------------------------------------------------
-- 2) Native (vimgrep) search + multiple occurrences per line
--------------------------------------------------------------------------------
local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
local file_a = tmp .. "/a.txt"
do
  local fh = assert(io.open(file_a, "w"))
  fh:write("foo and foo and foo\nbar foo baz\nno match here\n")
  fh:close()
end

local cfg = { literal = true, search_engine = "vimgrep", hidden = true,
  file_types = {}, globs = {}, exclude = {} }
do
  local items = rg.collect("foo", { tmp }, cfg)
  check("search: 4 occurrences (3 on line1 + 1 on line2)", #items == 4, #items)
  local line1 = 0
  for _, it in ipairs(items) do if it.lnum == 1 then line1 = line1 + 1 end end
  check("search: line 1 yields 3 separate entries", line1 == 3, line1)
end

--------------------------------------------------------------------------------
-- 3) Pure edit computation
--------------------------------------------------------------------------------
do
  local items = rg.collect("foo", { file_a }, cfg)
  local by = {}
  for _, it in ipairs(items) do by[#by + 1] = it end
  local new_lines, spots, skipped = apply.compute_file_edits(
    { "foo and foo and foo", "bar foo baz", "no match here" }, by, "X")
  check("compute: spots == 4", spots == 4, spots)
  check("compute: no skips", skipped == 0, skipped)
  check("compute: line1 rewritten", new_lines[1] == "X and X and X", new_lines[1])
  check("compute: line2 rewritten", new_lines[2] == "bar X baz", new_lines[2])
end

--------------------------------------------------------------------------------
-- 4) Dry-run plan + patch + JSON export
--------------------------------------------------------------------------------
do
  local items = rg.collect("foo", { file_a }, cfg)
  local results, totals = export.build_results(items, "X")
  check("plan: totals.spots == 4", totals.spots == 4, totals.spots)
  check("plan: totals.files == 1", totals.files == 1, totals.files)

  local patch = export.build_patch(results)
  check("patch: has unified headers", patch:match("%-%-%- a/") and patch:match("%+%+%+ b/"), patch)
  check("patch: contains an added line", patch:match("\n%+"), patch)

  local json = export.build_json(results, "X")
  local ok, decoded = pcall(vim.json.decode, json)
  check("json: decodes", ok and decoded.total_spots == 4, ok and decoded.total_spots)

  local jpath = tmp .. "/plan.json"
  local okw = export.write_export(jpath, results, "X")
  check("export: json file written", okw and vim.fn.filereadable(jpath) == 1)

  local ppath = tmp .. "/plan.patch"
  local okp = export.write_export(ppath, results, "X")
  check("export: patch file written", okp and vim.fn.filereadable(ppath) == 1)
end

--------------------------------------------------------------------------------
-- 5) Real apply via M.run (non-interactive ALL), files actually changed
--------------------------------------------------------------------------------
do
  replacer.setup({ search_engine = "vimgrep", confirm_all = false, write_changes = true })
  local request = {
    old = "foo", new = "XXX", scope = file_a, all = true, dry = false, export = nil,
    line_range = nil, overrides = {}, filters = { file_types = {}, globs = {}, exclude = {} },
  }
  replacer.run(request)

  -- read file back
  local fh = assert(io.open(file_a, "r"))
  local content = fh:read("*a"); fh:close()
  check("apply: all 'foo' replaced with 'XXX'", not content:match("foo") and content:match("XXX"), content)
end

--------------------------------------------------------------------------------
print(string.format("\n=== %d passed, %d failed ===", pass, fail))
if fail > 0 then vim.cmd("cquit 1") end
