---@mod koka.internal-types

---@brief [[

---WARNING: This is not part of the public API.
---Breaking changes to this module will not be reflected in the semantic versioning of this plugin.

--- Type definitions
---@brief ]]

local M = {}

---Evaluate a value that may be a function
---or an evaluated value
---@generic T
---@param value(fun():T)|T
---@return T
M.evaluate = function(value)
  if type(value) == 'function' then
    return value()
  end
  return value
end

return M
