---@module 'plugin.replacer'
--- Lazy-friendly plugin entry: main config lives in replacer.init

-- Runs when the plugin gets loaded (runtimepath: plugin/*)
-- Idempotent registration to avoid duplicates on reloads.

if not vim.g.__replacer_cmd_registered then
  local ok_core, core = pcall(require, "replacer")
  local ok_cmd,  cmd  = pcall(require, "replacer.command")
  if ok_core and ok_cmd then
    cmd.register(core.run)
    vim.g.__replacer_cmd_registered = true
  end
end

