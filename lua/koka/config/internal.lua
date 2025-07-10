---@mod koka.config.internal
---
---@brief [[
---
---WARNING: This is not part of the public API.
---
---@brief ]]

---@class koka.Config koka.nvim plugin configuration.
local KokaDefaultConfig = {
  ---@class koka.lsp.ClientConfig koka language client options
  lsp = {
    ---@type boolean | (fun():boolean) Whether to automatically attach the LSP client.
    auto_attach = true,
    ---@type (fun(client:number,bufnr:number))
    on_attach = function(_, _) end,
    settings = {},
  },
}

local kokanvim = vim.g.kokanvim or {}
---@type koka.Opts
local opts = type(kokanvim) == 'function' and kokanvim() or kokanvim

---@type koka.Config
local KokaConfig = vim.tbl_deep_extend('force', {}, KokaDefaultConfig, opts)
---TODO: check the config

return KokaConfig
