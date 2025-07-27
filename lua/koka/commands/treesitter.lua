---@mod koka.commands.treesitter
---@brief [[
---TreeSitter parser management commands for Koka
---@brief ]]

local M = {}

---Check if nvim-treesitter is available
---@return boolean available
local function is_treesitter_available()
  return pcall(require, 'nvim-treesitter')
end

---Get parser configurations
---@return table parser_configs
local function get_parser_configs()
  if not is_treesitter_available() then
    return {}
  end

  local parsers = require('nvim-treesitter.parsers')
  return parsers.get_parser_configs and parsers.get_parser_configs() or parsers
end

---Install Koka TreeSitter parser
---@return boolean success
function M.install_parser()
  if not is_treesitter_available() then
    vim.notify('[koka.nvim] nvim-treesitter is required for TreeSitter support', vim.log.levels.ERROR)
    return false
  end

  local list = get_parser_configs()

  -- Configure Koka parser
  list.koka = {
    install_info = {
      url = 'https://github.com/koka-community/tree-sitter-koka',
      files = { 'src/parser.c', 'src/scanner.c' },
      branch = 'main',
    },
  }

  local install = require('nvim-treesitter.install')

  -- Install the parser using ensure_installed
  local ok, err = pcall(function()
    install.ensure_installed('koka')
  end)

  if ok then
    vim.notify('✓ Koka TreeSitter parser installed successfully', vim.log.levels.INFO)
    return true
  else
    vim.notify('✗ Failed to install Koka TreeSitter parser: ' .. tostring(err), vim.log.levels.ERROR)
    return false
  end
end

---Update Koka TreeSitter parser
---@return boolean success
function M.update_parser()
  if not is_treesitter_available() then
    vim.notify('[koka.nvim] nvim-treesitter is required for TreeSitter support', vim.log.levels.ERROR)
    return false
  end

  local list = get_parser_configs()

  -- Configure Koka parser
  list.koka = {
    install_info = {
      url = 'https://github.com/koka-community/tree-sitter-koka',
      files = { 'src/parser.c', 'src/scanner.c' },
      branch = 'main',
    },
  }

  local install = require('nvim-treesitter.install')

  -- Update by calling update function directly
  local ok, err = pcall(function()
    local update = install.update {}
    update('koka')
  end)

  if ok then
    vim.notify('✓ Koka TreeSitter parser updated successfully', vim.log.levels.INFO)
    return true
  else
    vim.notify('✗ Failed to update Koka TreeSitter parser: ' .. tostring(err), vim.log.levels.ERROR)
    return false
  end
end

---Check if Koka parser is installed
---@return boolean installed
function M.is_parser_installed()
  if not is_treesitter_available() then
    return false
  end

  -- Check if parser is available by trying to get parser info
  local parsers = require('nvim-treesitter.parsers')
  local ok, _ = pcall(parsers.get_parser, nil, 'koka')
  return ok
end

---Get Koka parser info
---@return table info
function M.get_parser_info()
  if not is_treesitter_available() then
    return {
      available = false,
      installed = false,
      reason = 'nvim-treesitter not available',
    }
  end

  local installed = M.is_parser_installed()
  local list = get_parser_configs()

  return {
    available = true,
    installed = installed,
    config = list.koka,
    url = list.koka and list.koka.install_info.url or 'https://github.com/koka-community/tree-sitter-koka',
  }
end

---Uninstall Koka TreeSitter parser
---@return boolean success
function M.uninstall_parser()
  if not is_treesitter_available() then
    vim.notify('[koka.nvim] nvim-treesitter is required for TreeSitter support', vim.log.levels.ERROR)
    return false
  end

  local install = require('nvim-treesitter.install')

  local ok, err = pcall(function()
    install.uninstall('koka')
  end)

  if ok then
    vim.notify('✓ Koka TreeSitter parser uninstalled successfully', vim.log.levels.INFO)
    return true
  else
    vim.notify('✗ Failed to uninstall Koka TreeSitter parser: ' .. tostring(err), vim.log.levels.ERROR)
    return false
  end
end

---Ensure Koka parser is installed (uses ensure_installed which handles checking)
---@return boolean success
function M.ensure_parser()
  if not is_treesitter_available() then
    vim.notify('[koka.nvim] nvim-treesitter is required for TreeSitter support', vim.log.levels.ERROR)
    return false
  end

  local list = get_parser_configs()

  -- Configure Koka parser
  list.koka = {
    install_info = {
      url = 'https://github.com/koka-community/tree-sitter-koka',
      files = { 'src/parser.c', 'src/scanner.c' },
      branch = 'main',
    },
  }

  local install = require('nvim-treesitter.install')

  -- Use ensure_installed which handles the check internally
  local ok, err = pcall(function()
    install.ensure_installed('koka')
  end)

  if ok then
    return true
  else
    vim.notify('✗ Failed to ensure Koka TreeSitter parser: ' .. tostring(err), vim.log.levels.ERROR)
    return false
  end
end

---Setup TreeSitter commands
function M.setup()
  -- KokaTSInstall command
  vim.api.nvim_create_user_command('KokaTSInstall', function()
    M.install_parser()
  end, {
    desc = 'Install Koka TreeSitter parser',
  })

  -- KokaTSUpdate command
  vim.api.nvim_create_user_command('KokaTSUpdate', function()
    M.update_parser()
  end, {
    desc = 'Update Koka TreeSitter parser',
  })

  -- KokaTSUninstall command
  vim.api.nvim_create_user_command('KokaTSUninstall', function()
    M.uninstall_parser()
  end, {
    desc = 'Uninstall Koka TreeSitter parser',
  })

  -- KokaTSStatus command
  vim.api.nvim_create_user_command('KokaTSStatus', function()
    local info = M.get_parser_info()

    if not info.available then
      vim.notify('TreeSitter not available: ' .. info.reason, vim.log.levels.WARN)
      return
    end

    local status = info.installed and 'installed' or 'not installed'
    local message = string.format('Koka TreeSitter parser: %s\nRepository: %s', status, info.url)

    if info.installed then
      vim.notify('✓ ' .. message, vim.log.levels.INFO)
    else
      vim.notify('✗ ' .. message, vim.log.levels.WARN)
    end
  end, {
    desc = 'Check Koka TreeSitter parser status',
  })
end

return M
