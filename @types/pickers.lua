---@module '@types.pickers'

---@meta

---@class FzfAttachOpts
---@field current_source string[] list of formatted source lines (visible\tID...)
---@field current_idmap table<string, RP_Match> map from "ID%d" -> RP_Match
---@field items RP_Match[] original items list (for filtering/remain computation)
---@field new_text string replacement text
---@field cfg RP_Config replacer config
---@field apply_func fun(items: RP_Match[], new_text: string, write_changes: boolean): (integer, integer)
---@field reopen_fn fun(remaining: RP_Match[]) function to reopen picker with remaining items
