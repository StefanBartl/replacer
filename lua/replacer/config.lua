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
	ext_highlight_opts = {
		enabled = true,
		strikethrough = true,
		underline = false,
		old_bg = "#FF7A29",
		old_fg = "#1e1e1e",
		new_fg = "#9EE493",
		virt_prefix = " → ",
		hl_priority = vim and vim.hl and vim.hl.priorities and vim.hl.priorities.user or 50,
		-- ANSI fallback for fzf preview (numbers without \27[ and m)
		ansi_old_bg = "41", -- red background
		ansi_new_fg = "32", -- green text
		preview_marker = "▶ ", -- marker used in preview lines
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
