---@module 'replacer.config'
--- Central configuration resolution and accessors.

---@class ReplacerConfigModule
---@field options RP_Config
local M = {}

---@type RP_Config
local DEFAULTS = {
	engine = "telescope",
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
	ext_highlight = true,
	ext_highlight_strikethrough = true,
	ext_highlight_opts = {
		enabled = true, -- master switch
		debug = false, -- enable debug notifications
		preview_marker = "▶ ", -- string shown at line start in preview
		old_bg = "#FF7A29", -- background for old match (used by U.setup_highlight_groups)
		old_fg = "#1e1e1e", -- foreground for old match
		new_fg = "#9EE493", -- virt-text color for new text
		strikethrough = true, -- add strikethrough group
		virt_prefix = " ▶ ", -- prefix for virt-text
		hl_priority = vim and vim.hl and vim.hl.priorities and vim.hl.priorities.user or 50,
		ansi_fallback = false, -- if true, also return ANSI-wrapped line for fzf native terminal fallback
	},
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
