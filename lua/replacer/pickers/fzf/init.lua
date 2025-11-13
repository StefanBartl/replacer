---@module 'replacer.pickers.fzf'

local M = {}

M.run = require("replacer.pickers.fzf.run").run
M.preview_lines = require("replacer.pickers.fzf.preview_lines").preview_lines

return M
