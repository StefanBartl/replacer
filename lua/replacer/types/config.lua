---@module 'replacer.types.config'
--------------------------------------------------------------------------------
-- Types (LuaLS)
--------------------------------------------------------------------------------

---@class RP_PickerFzf
---@field winopts table|nil

---@class RP_PickerTelescope
---@field layout_config table|nil

---@class RP_Config
---@field engine               "fzf"|"telescope"
---@field write_changes        boolean
---@field confirm_all          boolean
---@field confirm_wide_scope   boolean
---@field preview_context      integer
---@field hidden               boolean
---@field exclude_git_dir      boolean
---@field literal              boolean     -- default search mode (flags may override per-run)
---@field _old_len?	           number
---@field smart_case           boolean
---@field default_scope        string      -- "%", "cwd", ".", or explicit path
---@field fzf                  RP_PickerFzf|nil
---@field telescope            RP_PickerTelescope|nil

---@class ReplacerConfigModule
---@field setup fun(opts:RP_Config|table|nil): nil
---@field get fun(): RP_Config
---@field resolve fun(partial:table|nil): RP_Config

