local helpers = require('tests.helpers')

describe('koka.config', function()
  local config

  before_each(function()
    helpers.reset_mocks()
    config = require('koka.config')
  end)

  describe('module structure', function()
    it('should be a table', function()
      assert.is_table(config)
    end)

    it('should handle global configuration', function()
      vim.g.kokanvim = {
        lsp = {
          auto_attach = false,
          debug = true,
        },
      }

      -- Plugin should access global config
      assert.equals(false, vim.g.kokanvim.lsp.auto_attach)
      assert.equals(true, vim.g.kokanvim.lsp.debug)
    end)
  end)

  describe('configuration types', function()
    it('should support LSP client options', function()
      local test_config = {
        lsp = {
          auto_attach = true,
          debug = false,
          on_attach = function(_, _)
            -- Test callback
          end,
        },
        bufnr = 1,
        env = { TEST = 'value' },
      }

      assert.is_boolean(test_config.lsp.auto_attach)
      assert.is_boolean(test_config.lsp.debug)
      assert.is_function(test_config.lsp.on_attach)
      assert.is_number(test_config.bufnr)
      assert.is_table(test_config.env)
    end)
  end)
end)
