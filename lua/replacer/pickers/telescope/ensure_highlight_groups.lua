---@module 'replacer.pickers.telescope.ensure_highlight_groups'
--- Ensure highlight groups for telescope preview, delegating to utils.
local U = require("replacer.pickers.utils")

---@param cfg RP_HighlightConfig
local function ensure(cfg)
  if not cfg or not cfg.enabled then return end
  U.setup_highlight_groups(cfg)
end

return { ensure = ensure }
