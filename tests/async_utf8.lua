-- Headless test for the async ripgrep path and UTF-8 (multi-byte) correctness.
-- Run:  nvim -l tests/async_utf8.lua

vim.opt.runtimepath:append(vim.fn.getcwd())

local replacer = require("replacer")
local rg = require("replacer.rg")
local apply = require("replacer.apply")

local pass, fail = 0, 0
local function check(name, cond, extra)
  if cond then pass = pass + 1; print("PASS  " .. name)
  else fail = fail + 1; print("FAIL  " .. name .. (extra and ("  -> " .. tostring(extra)) or "")) end
end

local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")

--------------------------------------------------------------------------------
-- Async ripgrep collection (skipped gracefully if rg is not installed)
--------------------------------------------------------------------------------
if vim.fn.executable("rg") == 1 then
  local f = tmp .. "/async.txt"
  local fh = assert(io.open(f, "w")); fh:write("foo foo\nbar foo\n"); fh:close()

  local done, got = false, nil
  rg.collect_async("foo", { tmp }, {
    literal = true, search_engine = "ripgrep", hidden = true,
    file_types = {}, globs = {}, exclude = {},
  }, function(items, err)
    got = { items = items, err = err }
    done = true
  end)
  vim.wait(5000, function() return done end, 20)
  check("async: callback fired", done == true)
  check("async: no error", got and got.err == nil, got and got.err and got.err.message)
  check("async: found 3 occurrences", got and got.items and #got.items == 3, got and got.items and #got.items)
else
  print("SKIP  async ripgrep tests (rg not installed)")
end

--------------------------------------------------------------------------------
-- UTF-8 multi-byte correctness (umlauts + emoji)
--------------------------------------------------------------------------------
do
  -- "ü" = 2 bytes, "😀" = 4 bytes; ensure byte offsets stay aligned.
  local line = "Grüße Müller 😀 Müller"
  local cfg = { literal = true, search_engine = "vimgrep", hidden = true,
    file_types = {}, globs = {}, exclude = {} }

  local f = tmp .. "/utf8.txt"
  local fh = assert(io.open(f, "w")); fh:write(line .. "\n"); fh:close()

  local items = rg.collect("Müller", { f }, cfg)
  check("utf8: two 'Müller' matches found", #items == 2, #items)

  local new_lines, spots, skipped = apply.compute_file_edits({ line }, items, "Mueller")
  check("utf8: both replaced (spots==2, skipped==0)", spots == 2 and skipped == 0,
    string.format("spots=%d skipped=%d", spots, skipped))
  check("utf8: result correct + emoji intact",
    new_lines[1] == "Grüße Mueller 😀 Mueller", new_lines[1])

  -- End-to-end apply through the real path.
  replacer.setup({ search_engine = "vimgrep", confirm_all = false, write_changes = true })
  replacer.run({
    old = "Müller", new = "Mueller", scope = f, all = true, dry = false, export = nil,
    line_range = nil, overrides = {}, filters = { file_types = {}, globs = {}, exclude = {} },
  })
  local content = (io.open(f):read("*a"))
  check("utf8: file written, umlaut+emoji preserved",
    content:match("Mueller") and content:match("😀") and not content:match("Müller"),
    content)
end

print(string.format("\n=== %d passed, %d failed ===", pass, fail))
if fail > 0 then vim.cmd("cquit 1") end
