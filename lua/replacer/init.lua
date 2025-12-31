---@module 'replacer.init'
--- Public API for the replacer plugin: setup(), run().
--- Orchestrates: argument parsing (via command module), ripgrep search,
--- interactive picker (fzf-lua or telescope), and bottom-up application.

local Config = require("replacer.config")
local RG     = require("replacer.rg")
local Apply  = require("replacer.apply")
local Cmd    = require("replacer.command")
local Debug  = require("replacer.debug")

---@type Replacer
local M = {
  options = Config.resolve(nil),
  setup   = function(_) end,
  run     = function(_, _, _, _) end,
}

--- Setup the plugin with user options and register commands.
---@param user RP_Config|nil
---@return nil
function M.setup(user)
  M.options = Config.resolve(user)

  -- Register main replace command
  Cmd.register(function(old, new_text, scope, all)
    M.run(old, new_text, scope, all)
  end)

  -- Register debug command
  Debug.register_command()
end

--- Execute the replace flow for given arguments.
---@param old string
---@param new_text string
---@param scope RP_Scope
---@param all boolean
---@return nil
function M.run(old, new_text, scope, all)
  -- Check debug mode
  local debug = M.options.ext_highlight_opts
    and M.options.ext_highlight_opts.debug
    or false

  if debug then
    vim.notify(
      string.format(
        "[replacer] Running: old='%s' new='%s' scope='%s' all=%s",
        old, new_text, scope, tostring(all)
      ),
      vim.log.levels.DEBUG
    )
  end

  -- Resolve scope (cwd/file/dir)
  local resolve = require("replacer.command").resolve_scope
  local roots, _ = resolve(scope)
  if type(roots) ~= "table" or #roots == 0 then
    return
  end

  -- Collect matches via ripgrep
  local items = RG.collect(old, roots, M.options)
  if #items == 0 then
    vim.notify("[replacer] no matches found")
    return
  end

  if debug then
    vim.notify(
      string.format("[replacer] Found %d match(es)", #items),
      vim.log.levels.DEBUG
    )
  end

  -- Non-interactive "All" mode
  if all then
    if M.options.confirm_all then
      local fileset = {} ---@type table<string, true>
      for i = 1, #items do fileset[items[i].path] = true end
      local filecount = 0
      for _ in pairs(fileset) do filecount = filecount + 1 end

      local msg = string.format(
        "Apply replacement to ALL %d spot(s) across %d file(s)?",
        #items, filecount
      )
      if vim.fn.confirm(msg, "&Yes\n&No", 2) ~= 1 then
        vim.notify("[replacer] cancelled")
        return
      end
    end

    local files, spots = Apply.apply(items, new_text, M.options.write_changes, debug)
    vim.notify(string.format("[replacer] %d spot(s) in %d file(s)", spots, files))
    return
  end

  -- Interactive picker dispatch
  local apply_func = function(selected_items, replacement, write)
    return Apply.apply(selected_items, replacement, write, debug)
  end

  if M.options.engine == "telescope" then
    require("replacer.pickers.telescope").run(items, new_text, M.options, apply_func)
  else
    require("replacer.pickers.fzf").run(items, new_text, M.options, apply_func)
  end
end

return M
