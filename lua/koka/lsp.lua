---@mod koka.lsp
---@brief [[
---LSP integration for Koka
---@brief ]]

local config = require('koka.config.internal')
local project = require('koka.project')
local constant = require('koka.constant')

local M = {}

local function get_lsp_cmd(project_config)
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

---@class koka.lsp.StartConfig: koka.lsp.ClientConfig
---@field root_dir string | nil
---@field cmd string[]
---@field name string
---@field filetypes string[]
---@field handlers lsp.Handler[]
---@field on_init function
---@field on_attach function
---@field on_exit function

---Start LSP client for the current buffer
---
---@param bufnr? number The buffer number (optional), default to the current buffer
M.start = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local kk_config = vim.lsp.config[constant.lsp_client_name] or {}

  local lsp_start_config = vim.tbl_deep_extend('force', config.lsp, kk_config)

  project.get_resolved_config(bufname, function(project_config)
    if not project_config.cwd then
      vim.notify(
        [[
kokanvim:
No project root found.
        ]],
        vim.log.levels.INFO
      )
      project_config.cwd = vim.fs.dirname(bufname)
    end

    -- TODO: we need to normalize root_dir on Windows
    lsp_start_config.root_dir = project_config.cwd
    lsp_start_config.settings = type(lsp_start_config.settings) == 'function'
        and lsp_start_config.settings(project_config.cwd)
      or lsp_start_config.settings
    lsp_start_config.cmd = get_lsp_cmd(project_config)
    lsp_start_config.name = constant.lsp_client_name
    lsp_start_config.filetypes = { 'koka' }

    -- Check if client is already running
    local clients = vim.lsp.get_active_clients { name = constant.lsp_client_name }
    for _, client in ipairs(clients) do
      if client.config.root_dir == project_config.cwd then
        -- Client already running for this project
        vim.lsp.buf_attach_client(bufnr, client.id)
        return
      end
    end

    -- Start new LSP client
    local client_id = vim.lsp.start(lsp_start_config, { bufnr = bufnr })

    if client_id then
      vim.lsp.buf_attach_client(bufnr, client_id)

      -- Call on_attach if configured
      if lsp_start_config.on_attach then
        lsp_start_config.on_attach(client_id, bufnr)
      end
    else
      vim.notify('[koka.nvim] Failed to start Koka LSP server', vim.log.levels.ERROR)
    end
  end)
end

---Stop LSP client for the current buffer
---@param bufnr? number The buffer number (optional), default to the current buffer
M.stop = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_active_clients {
    bufnr = bufnr,
    name = constant.lsp_client_name,
  }

  for _, client in ipairs(clients) do
    vim.lsp.stop_client(client.id)
  end
end

---Restart LSP client for the current buffer
---@param bufnr? number The buffer number (optional), default to the current buffer
M.restart = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  M.stop(bufnr)

  -- Small delay to ensure client is fully stopped
  vim.defer_fn(function()
    M.start(bufnr)
  end, 100)
end

---Get LSP client status for the current buffer
---@param bufnr? number The buffer number (optional), default to the current buffer
---@return boolean is_running true if LSP client is running
M.get_status = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_active_clients {
    bufnr = bufnr,
    name = constant.lsp_client_name,
  }

  return #clients > 0
end

return M
