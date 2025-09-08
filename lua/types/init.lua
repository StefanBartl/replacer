---@module 'types'

---@alias RP_Scope "%"|"cwd"|string

---@class RP_Config
---@field hidden boolean
---@field git_ignore boolean
---@field exclude_git_dir boolean
---@field preview_context integer
---@field fzf? table
---@field literal boolean      -- if false, use regex mode
---@field smart_case boolean   -- -S for rg if true

---@class RP_Match
---@field id integer
---@field path string
---@field lnum integer         -- 1-based
---@field col0 integer         -- 0-based byte column start
---@field old string
---@field line string          -- full line for preview


