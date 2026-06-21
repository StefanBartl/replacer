---@module 'replacer.error'
--- Lightweight structured errors and a safe-call wrapper.
---
--- Goals (per project guideline §1/§7):
---   - never swallow failures silently — wrap them in a typed value,
---   - give callers a uniform shape to branch on: { ok, result, err }.
---
--- Errors are plain tables (no metatables) so they serialize cleanly and can be
--- inspected/compared by `type`.

local M = {}

--- Construct a structured error.
---@param typ string      # stable discriminator, e.g. "WriteError"
---@param message string  # human-readable description
---@param cause any|nil   # optional underlying error/value
---@return RP_Error
function M.new(typ, message, cause)
  return { type = typ, message = message, cause = cause }
end

-- Common constructors -------------------------------------------------------

---@param message string
---@return RP_Error
function M.invalid_scope(message) return M.new("InvalidScopeError", message) end

---@param message string
---@param cause any|nil
---@return RP_Error
function M.write_error(message, cause) return M.new("WriteError", message, cause) end

---@param message string
---@param cause any|nil
---@return RP_Error
function M.search_error(message, cause) return M.new("SearchError", message, cause) end

--- Call `fn(...)` under pcall and return a uniform result envelope.
---@generic T
---@param fn fun(...): T
---@param ... any
---@return { ok: boolean, result: any, err: RP_Error|nil }
function M.safe_call(fn, ...)
  local ok, res = pcall(fn, ...)
  if ok then
    return { ok = true, result = res, err = nil }
  end
  return { ok = false, result = nil, err = M.new("RuntimeError", tostring(res), res) }
end

--- Render an error for user-facing notification.
---@param err RP_Error
---@return string
function M.format(err)
  if type(err) ~= "table" then return tostring(err) end
  return string.format("[%s] %s", err.type or "Error", err.message or "")
end

return M
