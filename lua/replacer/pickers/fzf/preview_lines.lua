---@module 'replacer.pickers.fzf.preview_lines'
local U = require("replacer.pickers.utils")

---@param it RP_Match
---@param new_text string
---@param cfg RP_Config
---@return string[] lines
local function preview_lines(it, new_text, cfg)
  local ok, fh = pcall(io.open, it.path, "r")
  if not ok or not fh then return { "[unreadable]" } end
  local lines = {}
  for s in fh:lines() do lines[#lines+1] = s end
  fh:close()

  local ctx = cfg.preview_context or 3
  local s = math.max(1, it.lnum - ctx)
  local e = math.min(#lines, it.lnum + ctx)
  local out = {}
  local marker = (cfg.ext_highlight_opts and cfg.ext_highlight_opts.preview_marker) or "▶ "
  for i = s, e do
    local mark = (i == it.lnum) and marker or (" " .. string.rep(" ", #marker - 1))
    out[#out+1] = string.format("%s%6d  %s", mark, i, tostring(lines[i] or ""))
  end

  if not cfg.ext_highlight_opts or not cfg.ext_highlight_opts.enabled then
    return out
  end

  local preview_line_idx = it.lnum - s + 1
  local raw_line = lines[it.lnum] or ""
  local start_byte = it.col0 or 0
  local match_text = it.old or ""
  local pre = raw_line:sub(1, start_byte)
  local match = raw_line:sub(start_byte + 1, start_byte + #match_text)
  local post = raw_line:sub(start_byte + #match_text + 1)

  if match == "" and match_text ~= "" then
    local sfind, efind = raw_line:find(match_text, 1, true)
    if sfind then
      pre = raw_line:sub(1, sfind - 1)
      match = raw_line:sub(sfind, efind)
      post = raw_line:sub(efind + 1)
    end
  end

  -- ANSI wrap using utils helper and ext config
  local wrap_old, wrap_new = U.ansi_snippets(cfg.ext_highlight_opts, match, (cfg.ext_highlight_opts.virt_prefix or " → ") .. tostring(new_text))
  local colored_line = pre .. wrap_old .. " " .. wrap_new .. post
  out[preview_line_idx] = string.format("%s%6d  %s", marker, it.lnum, colored_line)
  return out
end

return { preview_lines = preview_lines }
