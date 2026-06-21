---@module 'replacer.health'
--- Health check module for :checkhealth replacer
local M = {}

--- Check if command exists in PATH
---@param cmd string
---@return boolean
local function cmd_exists(cmd)
  return vim.fn.executable(cmd) == 1
end

--- Get version string from command
---@param cmd string
---@param args string[]
---@return string|nil
local function get_version(cmd, args)
  if not cmd_exists(cmd) then return nil end

  local ok, result
  if vim.system then
    local obj = vim.system(vim.list_extend({ cmd }, args), { text = true }):wait()
    ok = obj.code == 0
    result = obj.stdout or ""
  else
    local full_cmd = table.concat(vim.tbl_map(vim.fn.shellescape, vim.list_extend({ cmd }, args)), " ")
    result = vim.fn.system(full_cmd)
    ok = vim.v.shell_error == 0
  end

  if not ok then return nil end

  -- Extract version number (first line, first number-like sequence)
  local first_line = result:match("^([^\n]+)")
  if not first_line then return nil end

  local version = first_line:match("(%d+%.%d+[%.%d]*)")
  return version
end

--- Check Neovim version
---@param health table vim.health module
local function check_neovim(health)
  health.start("Neovim")

  local required = { 0, 9, 0 }
  local current = vim.version()

  if vim.version.cmp(current, required) >= 0 then
    health.ok(string.format("Version %s.%s.%s (required: 0.9.0+)", current.major, current.minor, current.patch))
  else
    health.error(
      string.format("Version %s.%s.%s is too old", current.major, current.minor, current.patch),
      { "Upgrade to Neovim 0.9.0 or newer" }
    )
  end
end

--- Check ripgrep
---@param health table vim.health module
local function check_ripgrep(health)
  health.start("ripgrep")

  if not cmd_exists("rg") then
    health.warn(
      "ripgrep (rg) not found in PATH — using the native vimgrep backend",
      {
        "ripgrep is faster and honors .gitignore/--type; vimgrep works without it.",
        "Install ripgrep: https://github.com/BurntSushi/ripgrep#installation",
        "On macOS: brew install ripgrep · Ubuntu: apt install ripgrep · Windows: choco install ripgrep",
      }
    )
    return
  end

  local version = get_version("rg", { "--version" })
  if version then
    health.ok(string.format("Found ripgrep %s", version))

    -- Check version >= 11.0 (for --json support)
    local major = tonumber(version:match("^(%d+)"))
    if major and major < 11 then
      health.warn(
        string.format("Version %s is old (recommended: 11.0+)", version),
        { "Consider upgrading for better JSON support" }
      )
    end
  else
    health.ok("Found ripgrep (version unknown)")
  end

  -- Test JSON output
  local test_ok = false
  local test_result = ""

  pcall(function()
    if vim.system then
      local obj = vim.system({ "rg", "--json", "-e", "test" }, { text = true, stdin = "test" }):wait()
      test_ok = obj.code == 0 or obj.code == 1  -- 0 = match, 1 = no match (both OK)
      test_result = obj.stdout or ""
    else
      -- Fallback for older Neovim
      local handle = io.popen('echo test | rg --json -e test 2>&1')
      if handle then
        test_result = handle:read("*a")
        handle:close()
        test_ok = test_result:match('"type"') ~= nil
      end
    end
  end)

  if test_ok and test_result:match('"type"') then
    health.ok("JSON output working")
  else
    health.warn("JSON output test inconclusive", { "Plugin may still work" })
  end
end

--- Check picker availability
---@param health table vim.health module
local function check_pickers(health)
  health.start("Pickers")

  local telescope_ok = pcall(require, "telescope")
  local fzf_ok = pcall(require, "fzf-lua")

  if telescope_ok then
    health.ok("telescope.nvim is installed")

    -- Check plenary.nvim (telescope dependency)
    local plenary_ok = pcall(require, "plenary")
    if plenary_ok then
      health.ok("plenary.nvim is installed")
    else
      health.error(
        "plenary.nvim not found (required by telescope)",
        { "Install: https://github.com/nvim-lua/plenary.nvim" }
      )
    end
  end

  if fzf_ok then
    health.ok("fzf-lua is installed")
  end

  if not telescope_ok and not fzf_ok then
    health.error(
      "No picker found",
      {
        "Install telescope.nvim: https://github.com/nvim-telescope/telescope.nvim",
        "OR install fzf-lua: https://github.com/ibhagwan/fzf-lua"
      }
    )
  end
end

--- Check plugin configuration
---@param health table vim.health module
local function check_config(health)
  health.start("Configuration")

  local ok, cfg_mod = pcall(require, "replacer.config")
  if not ok then
    health.error("replacer.config not loaded", { "Check plugin installation" })
    return
  end

  local cfg = cfg_mod.get()

  -- Picker engine ("auto" resolves to fzf-lua, else telescope)
  if cfg.engine == "auto" then
    local resolved = pcall(require, "fzf-lua") and "fzf-lua"
      or (pcall(require, "telescope") and "telescope")
      or "none"
    health.ok(string.format("Picker engine: auto (resolves to %s)", resolved))
    if resolved == "none" then
      health.error("No picker available for engine='auto'",
        { "Install fzf-lua or telescope.nvim" })
    end
  elseif cfg.engine == "telescope" or cfg.engine == "fzf" then
    health.ok(string.format("Picker engine: %s", cfg.engine))
    local picker_ok = (cfg.engine == "telescope") and pcall(require, "telescope")
      or pcall(require, "fzf-lua")
    if not picker_ok then
      health.error(
        string.format("Configured engine '%s' not available", cfg.engine),
        { "Install the picker or change 'engine' in config" }
      )
    end
  else
    health.warn(string.format("Unknown engine: %s", tostring(cfg.engine)),
      { "Expected 'auto', 'fzf', or 'telescope'" })
  end

  -- Search backend ("auto" prefers ripgrep, falls back to vimgrep)
  health.info(string.format("Search backend: %s", tostring(cfg.search_engine)))

  health.info(string.format("write_changes: %s", tostring(cfg.write_changes)))
  health.info(string.format("confirm_all: %s", tostring(cfg.confirm_all)))
  health.info(string.format("literal mode: %s", tostring(cfg.literal)))

  local filters = {}
  if #(cfg.file_types or {}) > 0 then filters[#filters + 1] = "types=" .. table.concat(cfg.file_types, ",") end
  if #(cfg.globs or {}) > 0 then filters[#filters + 1] = "globs=" .. table.concat(cfg.globs, ",") end
  if #(cfg.exclude or {}) > 0 then filters[#filters + 1] = "exclude=" .. table.concat(cfg.exclude, ",") end
  if #filters > 0 then
    health.info("Default filters: " .. table.concat(filters, "  "))
  end
end

--- Check UTF-8 support
---@param health table vim.health module
local function check_utf8(health)
  health.start("UTF-8 Support")

  -- Check vim.str_byteindex availability (Neovim >= 0.9)
  if vim.str_byteindex then
    health.ok("vim.str_byteindex available")

    -- Test UTF-8 conversion
    local test_line = "Müller test"  -- ü = 2 bytes
    local ok, result = pcall(vim.str_byteindex, test_line, 2, true)
    if ok and result == 2 then
      health.ok("UTF-8 byte index conversion working")
    else
      health.warn("UTF-8 conversion test inconclusive")
    end
  else
    health.error(
      "vim.str_byteindex not available",
      { "Upgrade to Neovim 0.9.0 or newer for UTF-8 support" }
    )
  end
end

--- Main health check entry point
--- This function is called by :checkhealth replacer
function M.check()
  -- Get health module (compatible with Neovim 0.9 and 0.10+)
  local health = vim.health or require("health")

  check_neovim(health)
  check_ripgrep(health)
  check_pickers(health)
  check_config(health)
  check_utf8(health)

  -- Summary
  health.start("Summary")
  health.info("Usage: :[range]Replace[!] {old} {new} [scope] [--flags]")
  health.info("See :help replacer for documentation")
end

return M
