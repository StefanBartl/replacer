---@module 'replacer.pickers.utils'
--- Shared helper functions for pickers (telescope & fzf).
---@class Utils
local U = {}

--- Convert 0-based byte index into display char column (0-based).
--- Uses vim.fn.strdisplaywidth for safer width handling (tabs, unicode).
---@param line_text string
---@param byte_idx0 number
---@return number
function U.byte_to_display_col(line_text, byte_idx0)
  if not line_text then return 0 end
  local prefix = line_text:sub(1, byte_idx0)
  local ok, w = pcall(vim.fn.strdisplaywidth, prefix)
  if ok and type(w) == "number" then return w end
  return #prefix
end

--- Create or return preview namespace
---@return number ns
function U.get_ns()
  return vim.api.nvim_create_namespace("replacer_preview_ns")
end

--- Safely set highlight groups according to highlight config.
--- This acts as small API that telescope's ensure_highlight_groups will call.
---@param cfg RP_HighlightConfig
function U.setup_highlight_groups(cfg)
  if not cfg or not cfg.enabled then return end
  local ok, _ = pcall(function()
    -- base old
    vim.api.nvim_set_hl(0, "ReplacerOld", {
      bg = cfg.old_bg,
      fg = cfg.old_fg,
      underline = cfg.underline or false,
      bold = true,
    })
    -- optional strikethrough group
    if cfg.strikethrough then
      vim.api.nvim_set_hl(0, "ReplacerOldStrikethrough", {
        bg = cfg.old_bg,
        fg = cfg.old_fg,
        strikethrough = true,
      })
    end
    -- new text virtual
    vim.api.nvim_set_hl(0, "ReplacerNew", { fg = cfg.new_fg, bold = true })
  end)
  return ok
end

--- Build ANSI-wrapped old/new snippet for fzf preview lines, using cfg fallbacks.
---@param cfg RP_HighlightConfig
---@param old_text string
---@param new_text string
---@return string colored_old, string colored_new_hint
function U.ansi_snippets(cfg, old_text, new_text)
  cfg = cfg or {}
  local old_bg = cfg.ansi_old_bg or "41"
  local new_fg = cfg.ansi_new_fg or "32"
  local wrap_old = ("\27[%sm%s\27[0m"):format(old_bg .. ";30", old_text) -- combine bg + black fg
  local wrap_new = ("\27[%sm%s\27[0m"):format(new_fg, new_text)
  return wrap_old, wrap_new
end

return U
