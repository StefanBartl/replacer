-- luacheck configuration for replacer.nvim
-- Run:  luacheck lua/

std = "luajit"
cache = true
codes = true

-- Neovim injects `vim` as a global at runtime.
read_globals = {
  "vim",
}

-- Keep lines reasonable but not draconian (annotations can be long).
max_line_length = 140

-- Common, intentional patterns in plugin code:
ignore = {
  "212", -- unused argument (callbacks frequently ignore some args)
  "213", -- unused loop variable
  "631", -- line too long (handled by max_line_length where it matters)
}

exclude_files = {
  "tests/**", -- ad-hoc test scripts have their own conventions
}
