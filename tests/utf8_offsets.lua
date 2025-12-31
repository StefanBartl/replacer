---@module 'test.utf8_offsets'
--- Test suite for UTF-8 byte offset handling in replacer.
--- Run via: :lua require('test.utf8_offsets').run_all()

local M = {}

--- Test helper: create temp buffer with content
---@param lines string[]
---@return integer bufnr
---@diagnostic disable-next-line: unused-local, unused-function
local function create_test_buffer(lines)
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	return bufnr
end

--- Test 1: ASCII only (baseline)
function M.test_ascii()
	local line = "hello world hello"
	local pattern = "hello"

	-- Using string.find (byte-based)
	local s1, e1 = line:find(pattern, 1, true)
	assert(s1 == 1, "First hello at byte 1")

	local s2, _ = line:find(pattern, e1 + 1, true)
	assert(s2 == 13, "Second hello at byte 13")

	print("✓ ASCII test passed")
	return true
end

--- Test 2: UTF-8 multi-byte characters
function M.test_utf8_offsets()
	-- String with German umlauts (2-byte UTF-8)
	local line = "Müller test Müller" -- Ü = C3 9C (2 bytes)
	local pattern = "Müller"

	-- Character positions: M=1, ü=2 (but 2 bytes!), l=3, l=4, e=5, r=6
	-- Byte positions: M=1, ü=2-3, l=4, l=5, e=6, r=7

	-- First occurrence at char 0, byte 0
	local char_idx = 0
	local byte_idx = vim.str_byteindex(line, "utf-8", char_idx)
	assert(byte_idx == 0, string.format("Expected byte 0, got %d", byte_idx))

	-- Test substring extraction
	local s, e = line:find(pattern, 1, true)
	assert(s == 1, string.format("Expected byte 1, got %d", s))
	assert(e == 7, string.format("Expected byte 7, got %d", e)) -- M(1) + ü(2) + l(1) + l(1) + e(1) + r(1) = 7

	print("✓ UTF-8 offset test passed")
	return true
end

--- Test 3: Validate replacer match structure
function M.test_match_validation()
	local line = "test Müller test"
	local pattern = "Müller"

	-- Simulate RP_Match
	---@diagnostic disable-next-line: discard-returns
	local s, _ = line:find(pattern, 1, true)
	local match = {
		col0 = s - 1, -- 0-based byte offset
		old = pattern,
		line = line,
	}

	-- Validate extraction (replicate apply.lua logic)
	local start0 = match.col0
	local end0 = start0 + #match.old - 1
	local seg = line:sub(start0 + 1, end0 + 1)

	assert(seg == pattern, string.format("Expected '%s', got '%s'", pattern, seg))
	print("✓ Match validation test passed")
	return true
end

--- Test 4: Emoji (4-byte UTF-8)
function M.test_emoji_offsets()
	local line = "hello 😀 world" -- 😀 = F0 9F 98 80 (4 bytes)
	local pattern = "world"

	-- Find pattern after emoji
	---@diagnostic disable-next-line: discard-returns
	local s, _ = line:find(pattern, 1, true)
	assert(s == 11, string.format("Expected byte 11, got %d", s))
	-- h(1) e(1) l(1) l(1) o(1) space(1) emoji(4) space(1) = 11

	print("✓ Emoji offset test passed")
	return true
end

--- Test 5: Ripgrep JSON submatch simulation
function M.test_rg_submatch()
	local line = "Müller test Müller"
	local pattern = "Müller"

	-- Simulate ripgrep submatch (may be char or byte based)
	-- For first occurrence:
	local char_start = 0
	local char_end = 6 -- "Müller" is 6 characters

	-- Convert to bytes
	local byte_start = vim.str_byteindex(line, "utf-8", char_start)
	local byte_end = vim.str_byteindex(line, "utf-8", char_end)

	-- Extract using byte offsets (Lua 1-based)
	local seg = line:sub(byte_start + 1, byte_end)
	assert(seg == pattern, string.format("Expected '%s', got '%s'", pattern, seg))

	print("✓ Ripgrep submatch simulation passed")
	return true
end

--- Test 6: Line normalization
function M.test_line_normalization()
	local raw_line = "test line\n"
	local normalized = raw_line:gsub("\r?\n$", "")

	assert(normalized == "test line", "Failed to remove newline")

	local raw_crlf = "test line\r\n"
	local normalized_crlf = raw_crlf:gsub("\r?\n$", "")
	assert(normalized_crlf == "test line", "Failed to remove CRLF")

	print("✓ Line normalization test passed")
	return true
end

--- Run all tests
function M.run_all()
	local tests = {
		{ "ASCII baseline", M.test_ascii },
		{ "UTF-8 offsets", M.test_utf8_offsets },
		{ "Match validation", M.test_match_validation },
		{ "Emoji offsets", M.test_emoji_offsets },
		{ "Ripgrep submatch", M.test_rg_submatch },
		{ "Line normalization", M.test_line_normalization },
	}

	print("\n=== Replacer UTF-8 Offset Tests ===\n")

	local passed = 0
	local failed = 0

	for _, test in ipairs(tests) do
		local name, fn = test[1], test[2]
		local ok, err = pcall(fn)
		if ok then
			passed = passed + 1
		else
			failed = failed + 1
			print(string.format("✗ %s FAILED: %s", name, err))
		end
	end

	print(string.format("\n=== Results: %d passed, %d failed ===\n", passed, failed))
	return failed == 0
end

return M
