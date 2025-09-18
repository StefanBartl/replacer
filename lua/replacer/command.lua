---@module 'replacer.command'
--- Parse user command arguments, resolve scope (cwd/buffer/path),
--- and register the :Replace user command.
--- Exports: `register()` and `resolve_scope()` for reuse by the core.

local uv = vim.uv or vim.loop

--------------------------------------------------------------------------------
-- Argument parsing
--------------------------------------------------------------------------------

---@nodiscard
---@param s string
---@return string[]
local function parse_args(s)
	-- Robust shell-like split with quote handling ("..." or '...')
	local out ---@type string[]
	out = {}
	local i, n = 1, #s
	while i <= n do
		-- skip whitespace
		while i <= n and s:sub(i, i):match("%s") do
			i = i + 1
		end
		if i > n then
			break
		end

		local c = s:sub(i, i)
		if c == "'" or c == '"' then
			-- quoted segment with simple \" / \' escaping
			local q = c
			i = i + 1
			local buf ---@type string[]
			buf = {}
			while i <= n do
				local ch = s:sub(i, i)
				if ch == "\\" and i < n then
					buf[#buf + 1] = s:sub(i + 1, i + 1)
					i = i + 2
				elseif ch == q then
					i = i + 1
					break
				else
					buf[#buf + 1] = ch
					i = i + 1
				end
			end
			out[#out + 1] = table.concat(buf)
		else
			-- unquoted token
			local j = i
			while j <= n and not s:sub(j, j):match("%s") do
				j = j + 1
			end
			out[#out + 1] = s:sub(i, j - 1)
			i = j
		end
	end
	return out
end

--------------------------------------------------------------------------------
-- Scope resolution
--------------------------------------------------------------------------------

---@param scope RP_Scope
---@return string[] roots, boolean single_file
local function resolve_scope(scope)
	-- "%" / "buf" → current file (only if buffer is file-backed)
	if scope == "%" or scope == "buf" then
		local f = vim.api.nvim_buf_get_name(0)
		if f == "" then
			vim.notify("[replacer] current buffer has no file path", vim.log.levels.ERROR)
			return {}, false
		end
		return { f }, true
	end

	-- nil/""/"cwd"/"." → current working directory
	if scope == nil or scope == "" or scope == "cwd" or scope == "." then
		local cwd = uv.cwd()
		return { cwd }, false
	end

	-- explicit path (file or directory)
	local p = vim.fn.fnamemodify(scope, ":p")
	local is_dir = vim.fn.isdirectory(p) ~= 0
	return { p }, not is_dir
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

---@class ReplacerCommand
local M = {}

--- Register the :Replace user command.
---@param run_fun fun(old: string, new_text: string, scope: RP_Scope, all: boolean): nil
---@return nil
function M.register(run_fun)
	-- in M.register:
	vim.api.nvim_create_user_command("Replace", function(opts)
		local args = parse_args(opts.args or "")
		if #args < 2 then
			vim.notify("Usage: :Replace[!] {old} {new} {scope?} [--all|-a|All]", vim.log.levels.ERROR)
			return
		end

		local old, new_text = args[1], args[2]
		local scope = args[3] or "cwd" ---@type RP_Scope

		-- FLAGS
		local flag_all = opts.bang == true
		for i = 4, #args do
			local a = args[i]
			if type(a) == "string" then
				local al = a:lower()
				if al == "--all" or al == "-a" or al == "all" then
					flag_all = true
				end
			end
		end

		-- Guard: empty 'old' is dangerous (rg would match everything)
		if old == "" then
			vim.notify("[replacer] 'old' must not be empty", vim.log.levels.ERROR)
			return
		end

		run_fun(old, new_text, scope, flag_all)
	end, {
		nargs = "+",
		bang = true, -- <— allow :Replace!
		complete = function(_, line)
			local parts = parse_args(line)
			if #parts == 2 then
				return { "%", "cwd", ".", "--all", "-a" }
			end
			if #parts == 3 then
				return { "%", "cwd", ".", "--all", "-a" }
			end
			if #parts >= 4 then
				return { "--all", "-a" }
			end
			return {}
		end,
		desc = "Interactive replace: :Replace[!] {old} {new} {scope?} [--all|-a]",
	})
end

-- Export scope resolver for reuse by the core module.
M.resolve_scope = resolve_scope

return M
