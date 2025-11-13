---@module 'replacer.pickers.telescope'
local M = {}

M.run = require("replacer.pickers.telescope.run").run
-- attach_mappings and ensure_highlight_groups can be exposed if needed
M.attach_mappings = require("replacer.pickers.telescope.attach_mappings").attach_mappings
M.ensure_highlight_groups = require("replacer.pickers.telescope.ensure_highlight_groups").ensure

return M
