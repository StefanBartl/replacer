---@module 'plugin.replacer'
--- Plugin entry point - loads early (before lazy loading)
--- This file ensures health checks work even with lazy loading

-- Register health check command that works before lazy loading
vim.api.nvim_create_user_command("CheckhealthReplacer", function()
  -- Ensure module is loaded
  local ok = pcall(require, "replacer")
  if not ok then
    vim.notify(
      "[replacer] Plugin not loaded. Run :Replace first to trigger lazy loading.",
      vim.log.levels.WARN
    )
    return
  end

  vim.cmd("checkhealth replacer")
end, {
  desc = "Run replacer health check (loads plugin if needed)",
})

-- Alternative: Register as Lazy.nvim health provider
-- This makes :checkhealth replacer work automatically
if vim.fn.exists(":Lazy") == 2 then
  -- Lazy.nvim is installed
  -- Health checks will work after plugin loads
  vim.api.nvim_create_autocmd("User", {
    pattern = "LazyLoad",
    callback = function(event)
      if event.data == "replacer.nvim" or event.data == "replacer" then
        -- Plugin just loaded, health is now available
        vim.notify("[replacer] Health check now available: :checkhealth replacer", vim.log.levels.INFO)
      end
    end,
  })
end

-- For non-lazy configs, just do nothing (setup() will be called)
