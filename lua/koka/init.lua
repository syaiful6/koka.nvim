--@diagnostic disable: missing-fields

local M = {}

if not pcall(require, 'nvim-treesitter') then
  vim.notify('[koka.nvim] you must install nvim treesitter')

  return {
    setup = function() end,
    update = function() end,
  }
end

local parsers = require('nvim-treesitter.parsers')
local list = parsers.get_parser_configs and parsers.get_parser_configs() or parsers

local install_koka_treesitter = function()
  list.koka = {
    install_info = {
      url = 'https://github.com/mtoohey31/tree-sitter-koka',
      files = { 'src/parser.c', 'src/scanner.c' },
      branch = 'main',
    },
  }

  require('nvim-treesitter.install').ensure_installed('koka')
end

--- Setup Koka.nvim
M.setup = function()
  install_koka_treesitter()
end

--- Update treesitter or any tools we use
M.update = function()
  local update = require('nvim-treesitter.install').update {}
  update('koka')
end

return M
