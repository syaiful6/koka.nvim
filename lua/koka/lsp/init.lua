---@mod koka.lsp
---@brief [[
---LSP integration for Koka
---@brief ]]

local config = require('koka.config.internal')
local project = require('koka.project')
local lsp_helpers = require('koka.lsp.helpers')

local M = {}

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
  local kk_config = vim.lsp.config[lsp_helpers.koka_client_name] or {}
  ---@type koka.lsp.StartConfig
  local lsp_start_config = vim.tbl_deep_extend('force', config.lsp, kk_config) --[[@as koka.lsp.StartConfig]]

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

    -- Normalize paths for consistent comparison
    local normalized_cwd = vim.fs.normalize(project_config.cwd)
    lsp_start_config.root_dir = normalized_cwd
    lsp_start_config.settings = type(lsp_start_config.settings) == 'function'
        and lsp_start_config.settings(normalized_cwd)
      or lsp_start_config.settings
    lsp_start_config.cmd = lsp_helpers.get_lsp_cmd(project_config)
    lsp_start_config.name = lsp_helpers.koka_client_name
    lsp_start_config.filetypes = { 'koka' }

    -- Check if client is already running
    local clients = lsp_helpers.get_active_lsp_clients()
    for _, client in ipairs(clients) do
      local client_root_dir = vim.fs.normalize(client.config.root_dir or '')
      if client_root_dir == normalized_cwd then
        -- Client already running for this project
        vim.lsp.buf_attach_client(bufnr, client.id)
        return
      end
    end

    -- Start new LSP client
    local client_id = vim.lsp.start(lsp_start_config, { bufnr = bufnr })
    if not client_id then
      vim.notify(
        [[
[koka.nvim] Failed to start Koka LSP server.
        ]],
        vim.log.levels.ERROR
      )
      return
    end
  end)
end

---Stop LSP client for the current buffer
---@param bufnr? number The buffer number (optional), default to the current buffer
M.stop = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local clients = lsp_helpers.get_active_lsp_clients(bufnr)

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
  local clients = lsp_helpers.get_active_lsp_clients(bufnr)
  return #clients > 0
end

return M
