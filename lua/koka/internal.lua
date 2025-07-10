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
  --- TODO:: Attach commands
end

M.ftplugin = function()
  init()
  start_or_attach()
  ---TODO: implement nvim-dap adapater
end

return M
