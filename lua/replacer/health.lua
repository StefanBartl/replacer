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
    health.error(
      "ripgrep (rg) not found in PATH",
      {
        "Install ripgrep: https://github.com/BurntSushi/ripgrep#installation",
        "On macOS: brew install ripgrep",
        "On Ubuntu: apt install ripgrep",
        "On Windows: choco install ripgrep"
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

  local ok, replacer = pcall(require, "replacer")
  if not ok then
    health.error("replacer module not loaded", { "Check plugin installation" })
    return
  end

  if not replacer.options then
    health.warn("Plugin not configured", { "Run require('replacer').setup({})" })
    return
  end

  local cfg = replacer.options

  -- Check engine
  if cfg.engine == "telescope" or cfg.engine == "fzf" then
    health.ok(string.format("Engine: %s", cfg.engine))

    -- Verify picker is available
    local picker_ok = false
    if cfg.engine == "telescope" then
      picker_ok = pcall(require, "telescope")
    else
      picker_ok = pcall(require, "fzf-lua")
    end

    if not picker_ok then
      health.error(
        string.format("Configured engine '%s' not available", cfg.engine),
        { "Install the picker or change 'engine' in config" }
      )
    end
  else
    health.warn(
      string.format("Unknown engine: %s (expected 'telescope' or 'fzf')", cfg.engine or "nil"),
      { "Plugin will default to telescope if available" }
    )
  end

  -- Check write_changes
  health.info(string.format("write_changes: %s", tostring(cfg.write_changes)))

  -- Check confirm_all
  health.info(string.format("confirm_all: %s", tostring(cfg.confirm_all)))

  -- Check literal mode
  health.info(string.format("literal mode: %s", tostring(cfg.literal)))

  -- Check debug mode
  if cfg.ext_highlight_opts and cfg.ext_highlight_opts.debug then
    health.warn("Debug mode is enabled", { "Disable for production: ext_highlight_opts.debug = false" })
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
  health.info("Run :ReplaceDebug test to verify UTF-8 offset handling")
  health.info("See :help replacer for documentation")
end

return M
