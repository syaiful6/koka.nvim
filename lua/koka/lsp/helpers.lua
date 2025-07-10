---@mod koka.lsp.helpers
---
---@brief [[
---
---WARNING: This is not part of the public API.
---Breking changes to this module will not be reflected in the semantic versioning
---of this plugin.
---@brief ]]

---@class koka.lsp.Helpers
local M = {}

M.koka_client_name = 'koka'

---@param bufnr? number the buffer to get clients for
---@param filter? vim.lsp.get_clients.Filter
---@return vim.lsp.Client[] kk_clients The koka clients
M.get_active_lsp_clients = function(bufnr, filter)
  local client_filter = vim.tbl_deep_extend('force', filter or {}, {
    name = M.koka_client_name,
  })
  if bufnr then
    client_filter.bufnr = bufnr
  end
  return vim.lsp.get_clients(client_filter)
end

--- Get Koka LSP command
---
---@param project_config koka.project.Config
---@return table
M.get_lsp_cmd = function(project_config)
  local cmd = { 'koka', '--language-server', '--buildtag=nvim' }

  -- Add include directories
  if project_config.include_dirs then
    for _, include_dir in ipairs(project_config.include_dirs) do
      table.insert(cmd, '--include=' .. include_dir)
    end
  end

  -- Add additional compiler arguments
  if project_config.compiler_args then
    for _, arg in ipairs(project_config.compiler_args) do
      table.insert(cmd, arg)
    end
  end

  table.insert(cmd, '--lsstdio')

  return cmd
end

return M
