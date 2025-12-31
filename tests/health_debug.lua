---@module 'tests.health_debug'
--- Debug script to diagnose health check issues
--- Run: :lua require('test.health_debug').diagnose()

local M = {}

function M.diagnose()
  print("\n=== Replacer Health Check Diagnosis ===\n")

  -- 1. Check Neovim version
  print("1. Neovim Version:")
  local ver = vim.version()
  print(string.format("   %d.%d.%d", ver.major, ver.minor, ver.patch))

  -- 2. Check if replacer is installed
  print("\n2. Replacer Plugin:")
  local ok, replacer = pcall(require, "replacer")
  if ok then
    print("   ✓ replacer module loadable")
    if replacer.options then
      print("   ✓ replacer.options exists")
    else
      print("   ✗ replacer.options is nil (setup() not called?)")
    end
  else
    print("   ✗ replacer module NOT loadable")
    print("   Error: " .. tostring(replacer))
    return
  end

  -- 3. Check health module location
  print("\n3. Health Module:")
  local health_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h") .. "/lua/replacer/health.lua"
  print("   Expected path: " .. health_path)

  local health_ok, health = pcall(require, "replacer.health")
  if health_ok then
    print("   ✓ replacer.health module loadable")

    if type(health) == "table" and type(health.check) == "function" then
      print("   ✓ health.check function exists")
    else
      print("   ✗ health.check function NOT found")
      print("   Module content: " .. vim.inspect(health))
    end
  else
    print("   ✗ replacer.health module NOT loadable")
    print("   Error: " .. tostring(health))
  end

  -- 4. Check vim.health API
  print("\n4. Health API:")
  if vim.health then
    print("   ✓ vim.health available (Neovim 0.10+)")
  else
    local compat_ok = pcall(require, "health")
    if compat_ok then
      print("   ✓ require('health') available (Neovim 0.9)")
    else
      print("   ✗ No health API found")
    end
  end

  -- 5. Try to run health check manually
  print("\n5. Manual Health Check:")
  if health_ok and health.check then
    print("   Running health.check()...")
    local check_ok, err = pcall(health.check)
    if check_ok then
      print("   ✓ health.check() executed successfully")
    else
      print("   ✗ health.check() failed")
      print("   Error: " .. tostring(err))
    end
  else
    print("   ✗ Cannot run (module not loaded)")
  end

  -- 6. Check runtimepath
  print("\n6. Runtime Path:")
  local rtp = vim.o.runtimepath
  local replacer_in_rtp = false
  for path in rtp:gmatch("[^,]+") do
    if path:match("replacer") then
      print("   ✓ Found: " .. path)
      replacer_in_rtp = true
    end
  end
  if not replacer_in_rtp then
    print("   ✗ No replacer path in runtimepath")
  end

  -- 7. Summary
  print("\n=== Summary ===")
  if health_ok and health.check then
    print("✓ Health module is properly set up")
    print("\nTry running:")
    print("  :checkhealth replacer")
    print("\nIf still not working, restart Neovim:")
    print("  :q")
    print("  nvim")
    print("  :checkhealth replacer")
  else
    print("✗ Health module has issues")
    print("\nPossible fixes:")
    print("1. Ensure file exists at: lua/replacer/health.lua")
    print("2. Ensure it exports M.check() function")
    print("3. Restart Neovim completely")
    print("4. If using Lazy.nvim: :Lazy reload replacer.nvim")
  end
  print("")
end

return M
