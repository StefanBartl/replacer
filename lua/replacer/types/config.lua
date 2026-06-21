---@module 'replacer.types.config'
--------------------------------------------------------------------------------
-- Types (LuaLS)
--------------------------------------------------------------------------------

---@class RP_PickerFzf
---@field winopts table|nil

---@class RP_PickerTelescope
---@field layout_config table|nil

---@class RP_Config
---@field engine?               "fzf"|"telescope"|"auto"  -- picker UI; "auto" -> fzf-lua if present, else telescope
---@field search_engine?        "ripgrep"|"vimgrep"|"auto" -- match collector; "auto" -> ripgrep if present, else vimgrep
---@field write_changes?        boolean
---@field confirm_all?          boolean
---@field confirm_wide_scope?   boolean
---@field preview_context?      integer
---@field hidden?               boolean
---@field exclude_git_dir?      boolean
---@field literal?              boolean     -- default search mode (flags may override per-run)
---@field _old_len? 	           number
---@field smart_case?           boolean
---@field default_scope?        string      -- "%", "cwd", ".", or explicit path
---@field file_types?           string[]    -- ripgrep --type values (e.g. { "lua" })
---@field globs?                string[]     -- include glob patterns (e.g. { "*.lua" })
---@field exclude?              string[]     -- exclude path/glob patterns (e.g. { "node_modules" })
---@field fzf?                  RP_PickerFzf|nil
---@field telescope?            RP_PickerTelescope|nil
---@field git_ignore?           boolean

---@class ReplacerConfigModule
---@field setup fun(opts:RP_Config|table|nil): nil
---@field get fun(): RP_Config
---@field resolve fun(partial:table|nil): RP_Config

return {}
