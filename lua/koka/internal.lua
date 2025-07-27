---@type koka.Config
local KokaConfig = require('koka.config.internal')

---@class koka.internal.Api
local M = {}

local function start_or_attach()
  local Types = require('koka.types.internal')
  if Types.evaluate(KokaConfig.lsp.auto_attach) then
    require('koka.lsp').start()
  end
end

local function init()
  if vim.g.kokanvim_loaded then
    return
  end
  vim.g.kokanvim_loaded = true

  -- Setup TreeSitter commands and ensure parser is installed
  local ts_commands = require('koka.commands.treesitter')
  ts_commands.setup()
  ts_commands.ensure_parser()

  -- Setup other commands
  require('koka.commands.codelens').setup()
  require('koka.commands').setup()
end

M.ftplugin = function()
  init()
  start_or_attach()
  ---TODO: implement nvim-dap adapater
end

return M
