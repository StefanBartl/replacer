---@module 'replacer'
--- Core orchestration: collect matches, run picker (or non-interactive),
--- apply replacements, and notify results.
--- Public API:
---   - setup(opts): initialize/override configuration
---   - run(old, new_text, scope, non_interactive_all, overrides?): execute a replace workflow
---
--- Notes:
---   - `setup` delegates to `replacer.config.setup`.
---   - `run` merges per-run overrides via `replacer.config.resolve` (no global mutation).

local M = {}

local cfg_mod = require("replacer.config")
local rg = require("replacer.rg") -- collector (ripgrep wrapper)
local apply = require("replacer.apply") -- applier
local picker_fz = require("replacer.pickers.fzf")
local picker_te = require("replacer.pickers.telescope")
local common = require("replacer.pickers.common")
local cmd_mod = require("replacer.command")

--------------------------------------------------------------------------------
-- Types (LuaLS)
--------------------------------------------------------------------------------

---@class RP_RunOverrides
---@field literal boolean|nil
---@field confirm_all boolean|nil

--- Initialize/override configuration (delegates to replacer.config).
--- @param opts RP_Config|table|nil
--- @return nil
function M.setup(opts)
	cfg_mod.setup(opts)
end

--- Public entry point.
--- @param old string
--- @param new_text string
--- @param scope string
--- @param non_interactive_all boolean  -- true: apply all, no picker
--- @param overrides RP_RunOverrides|nil -- per-run overrides (literal/confirm_all)
--- @return nil
function M.run(old, new_text, scope, non_interactive_all, overrides)
	-- Build effective config for this run without mutating global state.
	local cfg = cfg_mod.resolve(overrides or {})

	-- 1) collect matches (respects: literal, smart_case, hidden, exclude_git_dir, scope)
	local roots, _ = cmd_mod.resolve_scope(scope)
	if not roots or #roots == 0 then
		-- resolve_scope already notified the user in edge-cases (e.g., unnamed buffer)
		return
	end

	-- 2) applier
	---@cast roots string[]
	local items = rg.collect(old, roots, cfg)
	if #items == 0 then
		vim.notify("[replacer] no matches", vim.log.levels.INFO)
		return
	end

	local function apply_func(chosen, replacement, write_changes)
		return apply.apply_matches(chosen, replacement, write_changes)
	end

	-- 3) non-interactive ALL (e.g., :Replace!)
	if non_interactive_all then
		if cfg.confirm_all then
			local fileset = {}
			for _, it in ipairs(items) do
				fileset[it.path] = true
			end
			local filecount = 0
			for _ in pairs(fileset) do
				filecount = filecount + 1
			end
			local msg = string.format("Apply ALL %d spot(s) across %d file(s)?", #items, filecount)
			if vim.fn.confirm(msg, "&Yes\n&No", 2) ~= 1 then
				vim.notify("[replacer] cancelled")
				return
			end
		end
		local files, spots = apply_func(items, new_text, cfg.write_changes)
		common.notify_result(files, spots)
		return
	end

	-- 4) interactive picker
	local engine = (cfg.engine or "fzf")
	if engine == "fzf" then
		picker_fz.run(items, new_text, cfg, apply_func)
	else
		picker_te.run(items, new_text, cfg, apply_func)
	end
end

return M
