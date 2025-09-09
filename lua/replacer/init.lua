---@module 'replace_picker'
--- Interactive project-wide replace using fzf-lua + ripgrep.
--- Command: :Replace {old} {new} {scope?}
---   {old}   : literal text to search (no regex by default)
---   {new}   : replacement text (can be empty string "")
---   {scope} : "%" | "cwd" | <dir-or-file path>; default = "cwd"
---
--- Safety/UX:
---   - Collects matches via `rg --json` (literal, smart-case).
---   - Displays matches in an fzf-lua picker with context preview.
---   - Applies replacements only to selected occurrences.
---   - Per-file replacements are ordered bottom-up to avoid shifting offsets.
---   - Skips a spot if the buffer content changed in the meantime (warns).
---
--- Dependencies:
---   - ripgrep (rg) available in PATH
---   - ibhagwan/fzf-lua
---
--- Platform: Linux/macOS.
--- Version: 0.2.0

---@enum RP_LogLevel
local RP_LogLevel = { INFO = vim.log.levels.INFO, WARN = vim.log.levels.WARN, ERROR = vim.log.levels.ERROR }

local M = {}

---@type RP_Config
local CFG = {
	hidden = true,
	git_ignore = true,
	exclude_git_dir = true,
	preview_context = 3,
	literal = true,
	smart_case = true,
	fzf = {},
}

---@param msg string
---@param lv RP_LogLevel|nil
local function log(msg, lv) vim.notify("[replace] " .. msg, lv or RP_LogLevel.INFO) end

-- Parse args with simple quote support: '...' and "..."
---@nodiscard
---@param s string
---@return string[]
local function parse_args(s)
	local out ---@type string[]
	out = {}
	local i, n = 1, #s
	while i <= n do
		while i <= n and s:sub(i, i):match("%s") do i = i + 1 end
		if i > n then break end
		local c = s:sub(i, i)
		if c == "'" or c == '"' then
			local q = c; i = i + 1
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
			local j = i
			while j <= n and not s:sub(j, j):match("%s") do j = j + 1 end
			out[#out + 1] = s:sub(i, j - 1)
			i = j
		end
	end
	return out
end

---@param scope RP_Scope
---@return string[] roots, boolean single_file
local function resolve_scope(scope)
	if scope == "%" or scope == "buf" then
		local f = vim.api.nvim_buf_get_name(0)
		if f == "" then
			log("Current buffer has no file path", RP_LogLevel.ERROR); return {}, false
		end
		return { f }, true
	end
	if scope == nil or scope == "" or scope == "cwd" or scope == "." then
		return { vim.uv.cwd() }, false
	end
	local p = vim.fn.fnamemodify(scope, ":p")
	return { p }, vim.fn.isdirectory(p) == 0
end

---@nodiscard
---@param old string
---@param roots string[]
---@return RP_Match[]
local function rg_collect(old, roots)
	if vim.fn.executable("rg") ~= 1 then
		log("ripgrep (rg) is required", RP_LogLevel.ERROR); return {}
	end
	local args ---@type string[]
	args = { "rg", "--json", "-n", "--column" }
	if CFG.smart_case then args[#args + 1] = "-S" end
	if CFG.literal then
		args[#args + 1] = "--fixed-strings"
	end
	if CFG.hidden then args[#args + 1] = "--hidden" end
	if CFG.git_ignore == false then args[#args + 1] = "--no-ignore" end
	if CFG.exclude_git_dir then
		args[#args + 1] = "--glob"; args[#args + 1] = "!.git"
	end
	args[#args + 1] = old
	for _, r in ipairs(roots) do args[#args + 1] = r end

	local res
	if vim.system then
		res = vim.system(args, { text = true }):wait()
		if not res or (res.code ~= 0 and res.code ~= 1) then
			log("rg failed: " .. (res and (res.stderr or res.stdout or "") or ""), RP_LogLevel.ERROR)
			return {}
		end
	else
		-- Fallback (synchronous); discouraged on older NVIM.
		local cmd = table.concat(vim.tbl_map(vim.fn.shellescape, args), " ")
		local out = vim.fn.system(cmd)
		res = { code = vim.v.shell_error, stdout = out, stderr = "" }
		if res.code ~= 0 and res.code ~= 1 then
			log("rg failed (sync): " .. (res.stdout or ""), RP_LogLevel.ERROR)
			return {}
		end
	end

	local matches ---@type RP_Match[]
	matches = {}
	local id = 0
	for line in string.gmatch((res.stdout or ""), "([^\n]+)\n?") do
		local okj, ev = pcall(vim.json.decode, line)
		if okj and ev and ev.type == "match" and ev.data then
			local d = ev.data
			local path = (d.path and d.path.text) or ""
			local lnum = d.line_number or 0
			local text = (d.lines and d.lines.text) or ""
			local sm = d.submatches and d.submatches[1]
			if path ~= "" and lnum > 0 and sm and sm.start ~= nil and sm["end"] ~= nil then
				id = id + 1
				matches[#matches + 1] = {
					id = id,
					path = path,
					lnum = lnum,
					col0 = sm.start, -- 0-based byte offset
					old = old,
					line = text:gsub("\r?\n$", ""),
				}
			end
		end
	end
	return matches
end

---@nodiscard
---@param it RP_Match
---@return string[]
local function preview_lines(it)
	local ok, fh = pcall(io.open, it.path, "r")
	if not ok or not fh then return { "[unreadable]" } end
	local lines ---@type string[]
	lines = {}
	for s in fh:lines() do lines[#lines + 1] = s end
	fh:close()
	local ctx = CFG.preview_context
	local s = math.max(1, it.lnum - ctx)
	local e = math.min(#lines, it.lnum + ctx)
	local out ---@type string[]
	out = {}
	for i = s, e do
		local mark = (i == it.lnum) and "▶ " or "  "
		out[#out + 1] = string.format("%s%6d  %s", mark, i, tostring(lines[i] or ""))
	end
	return out
end

---@nodiscard
---@param items RP_Match[]
---@return string[] display, table<string, RP_Match> idmap
local function build_fzf_source(items)
	local disp ---@type string[]
	disp = {}
	local map = {} ---@type table<string, RP_Match>
	for _, it in ipairs(items) do
		local rel = vim.fn.fnamemodify(it.path, ":.")
		local visible = string.format("%s:%d:%d — %s", rel, it.lnum, it.col0 + 1, it.line)
		local hidden = string.format("ID%d", it.id)
		disp[#disp + 1] = visible .. "\t" .. hidden
		map[hidden] = it
	end
	return disp, map
end

---@param items RP_Match[]
---@param new_text string
---@return integer files, integer spots
local function apply_replacements(items, new_text)
	local by_path ---@type table<string, RP_Match[]>
	by_path = {}
	for _, it in ipairs(items) do
		local t = by_path[it.path]; if not t then
			t = {}; by_path[it.path] = t
		end
		t[#t + 1] = it
	end

	local files, spots = 0, 0
	for path, list in pairs(by_path) do
		table.sort(list, function(a, b)
			if a.lnum ~= b.lnum then return a.lnum > b.lnum end
			return a.col0 > b.col0
		end)
		local bufnr = vim.fn.bufadd(path)
		vim.fn.bufload(bufnr)
		for _, it in ipairs(list) do
			local row = it.lnum - 1
			local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
			local s, e = it.col0, it.col0 + #it.old
			local seg = line:sub(s + 1, e)
			if seg == it.old then
				vim.api.nvim_buf_set_text(bufnr, row, s, row, e, { new_text })
				spots = spots + 1
			else
				log(string.format("Skip changed spot: %s:%d:%d", path, it.lnum, it.col0 + 1), RP_LogLevel.WARN)
			end
		end
		if vim.bo[bufnr].modified then
			files = files + 1
			vim.api.nvim_buf_call(bufnr, function() vim.cmd("silent noautocmd write") end)
		end
	end
	return files, spots
end

---@param old string
---@param new_text string
---@param scope RP_Scope
local function run_once(old, new_text, scope)
	local roots, _ = resolve_scope(scope)

	if type(roots) ~= "table" then
		vim.notify("[replace] resolve_scope(): expected table for roots", vim.log.levels.ERROR)
		return
	end
	if #roots == 0 then return end

	local items = rg_collect(old, roots)
	if #items == 0 then
		log("No matches found", RP_LogLevel.INFO); return
	end
	local source, idmap = build_fzf_source(items)

	local ok_fzf, fzf = pcall(require, "fzf-lua")
	if not ok_fzf then
		log("fzf-lua not found", RP_LogLevel.ERROR); return
	end

	local opts = vim.tbl_deep_extend("force", {
		prompt = string.format("Replace '%s' → '%s' (select spots)> ", old, new_text),
		fzf_opts = {
			["--multi"] = "",
			-- keine --bind-Spielereien nötig, fzf-lua mappt actions-Keys via --expect
			["--with-nth"] = "1",
			["--delimiter"] = "\t",
			["--no-mouse"] = "",
		},

		previewer = "builtin",
		fn_previewer = function(item)
			local line = type(item) == "table" and item[1] or item
			if type(line) ~= "string" then return { "[no selection]" } end
			local id = line:match("\t(ID%d+)$")
			local it = id and idmap[id] or nil
			return it and preview_lines(it) or { "[unknown id]" }
		end,

		actions = {
			-- Enter: ersetze genau die ausgewählten Spots (ohne globale Bestätigung)
			["default"] = function(selected)
				if not selected or #selected == 0 then return end
				---@type RP_Match[]
				local chosen = {}
				for _, line in ipairs(selected) do
					local s = type(line) == "table" and line[1] or line
					local id = type(s) == "string" and s:match("\t(ID%d+)$") or nil
					local it = id and idmap[id] or nil
					if it then chosen[#chosen + 1] = it end
				end
				if #chosen == 0 then return end
				local files, spots = apply_replacements(chosen, new_text)
				log(string.format("Replaced %d spot(s) in %d file(s)", spots, files), RP_LogLevel.INFO)
			end,

			-- Ctrl-A: „alles ersetzen“ mit Bestätigung, unabhängig von aktueller Auswahl
			["ctrl-a"] = function(_)
				-- alle Items vorbereiten
				---@type RP_Match[]
				local all = {}
				for _, line in ipairs(source) do
					local s = type(line) == "table" and line[1] or line
					local id = type(s) == "string" and s:match("\t(ID%d+)$") or nil
					local it = id and idmap[id] or nil
					if it then all[#all + 1] = it end
				end
				if #all == 0 then return end

				-- Anzahl Dateien für die Bestätigung berechnen
				local fileset = {} ---@type table<string, true>
				for _, it in ipairs(all) do fileset[it.path] = true end
				local filecount = 0; for _ in pairs(fileset) do filecount = filecount + 1 end

				local msg = string.format("Apply replacement to ALL %d spot(s) across %d file(s)?", #all, filecount)
				local ok = vim.fn.confirm(msg, "&Yes\n&No", 2)
				if ok ~= 1 then
					log("Cancelled", RP_LogLevel.INFO)
					return
				end

				local files, spots = apply_replacements(all, new_text)
				log(string.format("Replaced %d spot(s) in %d file(s)", spots, files), RP_LogLevel.INFO)
			end,
		},
	}, CFG.fzf or {})

	fzf.fzf_exec(source, opts)
end

---@param user? RP_Config
function M.setup(user)
	CFG = vim.tbl_deep_extend("force", CFG, user or {})

	vim.api.nvim_create_user_command("Replace", function(opts)
		local args = parse_args(opts.args or "")
		if #args < 2 then
			log("Usage: :Replace {old} {new} {scope?}", RP_LogLevel.ERROR)
			return
		end
		local old, new_text, scope = args[1], args[2], args[3] or "cwd"
		run_once(old, new_text, scope)
	end, {
		nargs = "+",
		complete = function(_, line)
			-- simple completion for scope keyword on 3rd arg
			local parts = parse_args(line)
			if #parts == 2 then return { "%", "cwd" } end
			if #parts == 3 then return { "%", "cwd" } end
			return {}
		end,
		desc = "Interactive replace: :Replace {old} {new} {scope?}",
	})
end

return M
