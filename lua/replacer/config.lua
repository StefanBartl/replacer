---@module 'replacer.config'
--- Central configuration resolution and accessors.

---@class ReplacerConfigModule
---@field options RP_Config
local M = {}

---@type RP_Config
local DEFAULTS = {
  engine = "fzf",
  hidden = true,
  git_ignore = true,
  exclude_git_dir = true,
  preview_context = 3,
  literal = true,
  smart_case = true,
  write_changes = true,
  confirm_all = true,
  fzf = {},
  telescope = {},
}

--- Merge user options with defaults (deep).
---@param user RP_Config|nil
---@return RP_Config
function M.resolve(user)
  ---@type RP_Config
  local opts = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULTS), user or {})
  return opts
end

return M

