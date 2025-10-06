local helpers = require('tests.helpers')

---@diagnostic disable: duplicate-set-field

describe('koka.lsp', function()
  local lsp

  before_each(function()
    helpers.reset_mocks()

    -- Mock required modules
    package.loaded['koka.config.internal'] = {
      lsp = {
        auto_attach = true,
        on_attach = function() end,
        settings = {},
      },
    }

    vim.lsp.config = vim.lsp.config or {}
    vim.lsp.config.koka = {}
    vim.g.kokanvim = {}

    lsp = require('koka.lsp')
  end)

  describe('module structure', function()
    it('should export expected functions', function()
      assert.is_function(lsp.start)
      assert.is_function(lsp.stop)
      assert.is_function(lsp.restart)
      assert.is_function(lsp.get_status)
    end)
  end)

  describe('start', function()
    it('should start LSP client with project configuration', function()
      ---@type koka.lsp.StartConfig|nil
      local started_config = nil
      vim.lsp.start = function(config, _)
        started_config = config
        return 1 -- Mock client id
      end

      -- Mock buffer to return real project file path
      local project_file = helpers.get_file_path('with-config', 'src/example.kk')
      vim.api.nvim_buf_get_name = function(_)
        return project_file
      end

      lsp.start(0)

      assert.is_not_nil(started_config)
      assert(started_config ~= nil)
      assert.equal('koka', started_config.name)
      assert.same({ 'koka' }, started_config.filetypes)
      -- Check that root_dir ends with the expected project path
      assert.is_true(started_config.root_dir:match('with%-config$') ~= nil)
    end)

    it('should reuse existing client for same project', function()
      local lsp_helper = require('koka.lsp.helpers')

      local start_called = false
      vim.lsp.start = function(_, _)
        start_called = true
        return 1
      end

      -- Mock existing client
      vim.lsp.get_clients = function(opts)
        if opts and opts.name == lsp_helper.koka_client_name and not opts.bufnr then
          -- Called without bufnr (gets all clients)
          return {
            {
              config = { root_dir = helpers.get_project_path('with-config') },
              id = 1,
            },
          }
        end
        return {}
      end

      -- Mock buf_attach_client
      vim.lsp.buf_attach_client = function(_, _)
        -- Mock implementation
      end

      -- Mock project module - make it synchronous for testing
      package.loaded['koka.project'] = {
        get_resolved_config = function(_, callback)
          callback {
            target = 'c',
            cwd = helpers.get_project_path('with-config'),
          }
        end,
      }

      local project_file = helpers.get_file_path('with-config', 'src/example.kk')
      vim.api.nvim_buf_get_name = function(_)
        return project_file
      end

      lsp.start(0)

      assert.is_false(start_called)
    end)

    it('should handle missing project root', function()
      ---@type koka.lsp.StartConfig|nil
      local started_config = nil
      vim.lsp.start = function(config, _)
        started_config = config
        return 1
      end

      package.loaded['koka.project'] = {
        get_resolved_config = function(_, callback)
          callback {
            target = 'c',
            cwd = nil, -- No project root found
          }
        end,
      }

      lsp.start(0)

      assert.is_not_nil(started_config)
      assert(started_config ~= nil)
      -- Should fall back to buffer directory
      assert.is_string(started_config.root_dir)
    end)

    it('should call on_attach if configured', function()
      local on_attach_called = false
      local on_attach_client_id = nil
      local on_attach_bufnr = nil

      vim.lsp.start = function(config, _)
        if type(config.on_attach) == 'function' then
          local client = {
            name = 'koka',
            id = 1,
          } --- [[ @as vim.lsp.Client ]]
          config.on_attach(client, 0) -- Mock client and bufnr
        end
        return 1
      end

      -- Mock no existing clients
      vim.lsp.get_clients = function(_)
        return {}
      end

      -- Mock buf_attach_client
      vim.lsp.buf_attach_client = function(_, _)
        -- Mock implementation
      end

      -- Mock project module - make it synchronous for testing
      package.loaded['koka.project'] = {
        get_resolved_config = function(_, callback)
          callback {
            target = 'c',
            cwd = helpers.get_project_path('with-config'),
          }
        end,
      }

      -- Mock config with on_attach BEFORE requiring lsp module
      package.loaded['koka.config.internal'] = {
        lsp = {
          auto_attach = true,
          on_attach = function(client, bufnr)
            on_attach_called = true
            on_attach_client_id = client.id
            on_attach_bufnr = bufnr
          end,
          settings = {},
        },
      }

      -- Reset and re-require lsp module after setting up config
      package.loaded['koka.lsp'] = nil
      package.loaded['koka.lsp.init'] = nil
      local test_lsp = require('koka.lsp')

      local project_file = helpers.get_file_path('with-config', 'src/example.kk')
      vim.api.nvim_buf_get_name = function(_)
        return project_file
      end

      test_lsp.start(0)

      assert.is_true(on_attach_called)
      assert.equal(1, on_attach_client_id)
      assert.equal(0, on_attach_bufnr)
    end)
  end)

  describe('stop', function()
    it('should stop active clients for buffer', function()
      local stopped_clients = {}

      vim.lsp.get_active_clients = function(opts)
        if opts and opts.name == 'koka' and opts.bufnr == 0 then
          return {
            { id = 1 },
            { id = 2 },
          }
        end
        return {}
      end

      vim.lsp.get_clients = function(opts)
        if opts and opts.name == 'koka' and opts.bufnr == 0 then
          return {
            { id = 1 },
            { id = 2 },
          }
        end
        return {}
      end

      vim.lsp.stop_client = function(client_id)
        table.insert(stopped_clients, client_id)
      end

      lsp.stop(0)

      assert.same({ 1, 2 }, stopped_clients)
    end)

    it('should handle no active clients', function()
      vim.lsp.get_active_clients = function(_)
        return {}
      end

      vim.lsp.get_clients = function(_)
        return {}
      end

      local stop_called = false
      vim.lsp.stop_client = function(_)
        stop_called = true
      end

      lsp.stop(0)

      assert.is_false(stop_called)
    end)
  end)

  describe('restart', function()
    it('should stop then start client', function()
      local stopped = false
      local started = false

      -- Mock stop
      vim.lsp.get_active_clients = function(_)
        if not stopped then
          return { { id = 1 } }
        end
        return {}
      end

      vim.lsp.get_clients = function(_)
        if not stopped then
          return { { id = 1 } }
        end
        return {}
      end

      vim.lsp.stop_client = function(_)
        stopped = true
      end

      -- Mock start
      vim.lsp.start = function(_, _)
        started = true
        return 1
      end

      package.loaded['koka.project'] = {
        get_resolved_config = function(_, callback)
          callback {
            target = 'c',
            cwd = '/test/project',
          }
        end,
      }

      lsp.restart(0)

      -- The restart function calls stop immediately, then start after a delay
      assert.is_true(stopped)

      -- Wait for the deferred start call (100ms delay in restart function)
      vim.wait(150, function()
        return started
      end)

      assert.is_true(started)
    end)
  end)

  describe('get_status', function()
    it('should return true when client is active', function()
      vim.lsp.get_active_clients = function(opts)
        if opts and opts.name == 'koka' and opts.bufnr == 0 then
          return { { id = 1 } }
        end
        return {}
      end

      vim.lsp.get_clients = function(opts)
        if opts and opts.name == 'koka' and opts.bufnr == 0 then
          return { { id = 1 } }
        end
        return {}
      end

      local status = lsp.get_status(0)

      assert.is_true(status)
    end)

    it('should return false when no client is active', function()
      vim.lsp.get_active_clients = function(_)
        return {}
      end

      vim.lsp.get_clients = function(_)
        return {}
      end

      local status = lsp.get_status(0)

      assert.is_false(status)
    end)

    it('should use current buffer when none specified', function()
      vim.api.nvim_get_current_buf = function()
        return 42
      end

      local checked_bufnr = nil
      vim.lsp.get_active_clients = function(opts)
        checked_bufnr = opts and opts.bufnr
        return {}
      end

      vim.lsp.get_clients = function(opts)
        checked_bufnr = opts and opts.bufnr
        return {}
      end

      lsp.get_status()

      assert.equal(42, checked_bufnr)
    end)
  end)
end)
