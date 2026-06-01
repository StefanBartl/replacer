---@module 'replacer.types.pickers'

-- AUDIT: Ausformulieren

--------------------------------------------------------------------------------
-- common.lua
--------------------------------------------------------------------------------

-- Data Model
---@class RP_Match
---@field id integer
---@field path string
---@field lnum integer   -- 1-based line number
---@field col0 integer   -- 0-based byte column (ripgrep)
---@field old string                     # matched text (never nil)
---@field line string

--------------------------------------------------------------------------------
-- telscope.lua / fzf.lua
--------------------------------------------------------------------------------

---@class RP_ConfigPicker : RP_Config
---@field _old_len integer|nil  -- injected by core for literal highlighting

return {}
