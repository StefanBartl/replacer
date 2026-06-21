# replacer.nvim — developer tasks
# Usage: make test | make lint | make fmt | make fmt-check | make check

.PHONY: test lint fmt fmt-check check

# Run the headless test suites.
test:
	nvim -l tests/feature_smoke.lua
	nvim -l tests/async_utf8.lua

# Static analysis.
lint:
	luacheck lua/

# Format in place.
fmt:
	stylua lua/

# Verify formatting without writing.
fmt-check:
	stylua --check lua/

# Everything CI runs.
check: fmt-check lint test
