---@module 'replacer.init'
--- Public API for the replacer plugin: setup(), run().
--- Orchestrates: argument parsing (via command module), ripgrep search,
--- interactive picker (fzf-lua or telescope), and bottom-up application.

local Config = require("replacer.config")
local RG     = require("replacer.rg")
local Apply  = require("replacer.apply")
local Cmd    = require("replacer.command")

---@type Replacer
local M = {
  -- Provide stubs so LuaLS sees required fields at initialization time.
  options = Config.resolve(nil),
  setup   = function(_) end,                            -- replaced below
  run     = function(_, _, _, _) end,                   -- replaced below
}

--- Setup the plugin with user options and register :Replace.
---@param user RP_Config|nil
---@return nil
function M.setup(user)
  M.options = Config.resolve(user)
  Cmd.register(function(old, new_text, scope, all)
    M.run(old, new_text, scope, all)
  end)
end

--- Execute the replace flow for given arguments.
---@param old string
---@param new_text string
---@param scope RP_Scope
---@param all boolean
---@return nil
function M.run(old, new_text, scope, all)
  -- Resolve scope (cwd/file/dir)
  local resolve = require("replacer.command").resolve_scope
  local roots, _ = resolve(scope)
  if type(roots) ~= "table" or #roots == 0 then
    return
  end

  -- Collect matches via ripgrep
  local items = RG.collect(old, roots, M.options)  -- M.options: RP_Config
  if #items == 0 then
    vim.notify("[replacer] no matches found")
    return
  end

  -- Non-interactive "All" mode
  if all then
    if M.options.confirm_all then
      local fileset = {} ---@type table<string, true>
      for i = 1, #items do fileset[items[i].path] = true end
      local filecount = 0; for _ in pairs(fileset) do filecount = filecount + 1 end
      local msg = string.format(
        "Apply replacement to ALL %d spot(s) across %d file(s)?",
        #items, filecount
      )
      if vim.fn.confirm(msg, "&Yes\n&No", 2) ~= 1 then
        vim.notify("[replacer] cancelled")
        return
      end
    end
    local files, spots = Apply.apply(items, new_text, M.options.write_changes)
    vim.notify(string.format("[replacer] %d spot(s) in %d file(s)", spots, files))
    return
  end

  -- Interactive picker dispatch (default to fzf if engine unset/unknown)
  if M.options.engine == "telescope" then
    require("replacer.pickers.telescope").run(items, new_text, M.options, Apply.apply)
  else
    require("replacer.pickers.fzf").run(items, new_text, M.options, Apply.apply)
  end
end

return M
