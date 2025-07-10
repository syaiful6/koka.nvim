---@mod koka.config plugin configuration
---
---@brief [[
---
---koka is a filetype plugin, and does not need
---a `setup` function to work.
---
---To configure koka.nvim, set the variable `vim.g.koka`
---which is a `koka.Opts` table, in your configuration
---
---Example:
--->
------@type koka.Opts
---vim.g.koka = {
---   ---@type koka.lsp.ClientOpts
---   lsp = {
---     on_attach = function(client, bufnr)
---        -- Set keybindings, etc. here.
---     end
---  }
---}
---@brief ]]

local M = {}

---@type koka.Opts | fun():koka.Opts | nil
vim.g.kokanvim = vim.g.kokanvim

---@class koka.Opts
---
---@field lsp? koka.lsp.ClientOpts
---The buffer from which the executor was invoked
---@field bufnr? integer
---@field env? table<string, string>

---@class koka.lsp.ClientOpts
---
---Whether to automatically attach the LSP client.
---Defaults to true.
---@field auto_attach? (fun(): boolean) | boolean
---
---Whether to enable koka language server debug logging
---@field debug? boolean
---
---@field on_attach? fun(client:number,bufnr:number)

return M
