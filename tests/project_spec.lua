local helpers = require('tests.helpers')

---@diagnostic disable: duplicate-set-field

describe('koka.project', function()
  local project

  before_each(function()
    helpers.reset_mocks()
    project = require('koka.project')
  end)

  describe('get_project_config', function()
    it('should return nil when no config file found', function()
      local file_path = helpers.get_file_path('no-config', 'standalone.kk')

      local config = project.get_project_config(file_path)
      assert.is_nil(config)
    end)

    it('should parse koka.json when found', function()
      local file_path = helpers.get_file_path('with-config', 'src/example.kk')
      local config = project.get_project_config(file_path)
      assert.is_not_nil(config)
      assert.equal('wasm', config.target)
      assert.same({ 'src', 'lib' }, config.include_dirs)
    end)

    it('should work with callback', function()
      local file_path = helpers.get_file_path('with-koka-json', 'modules/core.kk')
      local callback_called = false
      ---@type koka.project.Config|nil
      local received_config = nil

      project.get_project_config(file_path, function(config)
        callback_called = true
        received_config = config
      end)

      assert.is_true(callback_called)
      assert.is_not_nil(received_config)
      assert(received_config ~= nil)
      assert.equal('c', received_config.target)
    end)
  end)

  describe('get_resolved_config', function()
    it('should return default config when no project config found', function()
      local file_path = helpers.get_file_path('no-config', 'standalone.kk')

      local config = project.get_resolved_config(file_path)

      assert.is_not_nil(config)
      assert.equal('c', config.target)
      assert.same({}, config.include_dirs)
      assert.same({}, config.compiler_args)
      assert.is_not_nil(config.cwd)
    end)

    it('should merge project config with defaults', function()
      local file_path = helpers.get_file_path('with-config', 'src/example.kk')

      local config = project.get_resolved_config(file_path)

      assert.equal('wasm', config.target)
      assert.same({ 'src', 'lib' }, config.include_dirs)
      assert.same({ '--optimize', '--stack=1M' }, config.compiler_args)
    end)

    it('should resolve cwd to project directory', function()
      local file_path = helpers.get_file_path('simple-package', 'src/main.kk')

      local config = project.get_resolved_config(file_path)

      -- Check that cwd ends with the project path (handle relative vs absolute paths)
      assert.is_true(config.cwd:match('simple%-package$') ~= nil)
    end)

    it('should use explicit cwd from config', function()
      local file_path = helpers.get_file_path('with-koka-json', 'module/core.kk')
      local config = project.get_resolved_config(file_path)

      -- cwd should be resolved relative to project directory and normalized
      local expected_cwd = vim.fs.joinpath(helpers.get_project_path('with-koka-json'), 'build')
      assert.equal(vim.fs.normalize(expected_cwd), config.cwd)
    end)

    it('should work with callback', function()
      local file_path = helpers.get_file_path('with-koka-json', 'modules/core.kk')
      local callback_called = false
      ---@type koka.project.Config|nil
      local received_config = nil

      project.get_resolved_config(file_path, function(config)
        callback_called = true
        received_config = config
      end)

      assert.is_true(callback_called)
      assert.is_not_nil(received_config)
      assert(received_config ~= nil)
      assert.equal('c', received_config.target)
    end)
  end)

  describe('get_config_root_dir', function()
    it('should return existing client root if available', function()
      -- Mock active client
      vim.lsp.get_active_clients = function(opts)
        if opts.name == 'koka' then
          return { {
            config = {
              root_dir = '/existing/project',
            },
          } }
        end
        return {}
      end

      vim.lsp.get_clients = function(opts)
        if opts and opts.name == 'koka' then
          return { {
            config = {
              root_dir = '/existing/project',
            },
          } }
        end
        return {}
      end

      local root_dir = project.get_config_root_dir({}, '/existing/project/file.kk')

      assert.equal('/existing/project', root_dir)
    end)

    it("should use config.root_dir if it's a string", function()
      local config = { root_dir = '/custom/root' }

      local root_dir = project.get_config_root_dir(config, '/test/file.kk')

      assert.equal('/custom/root', root_dir)
    end)

    it("should call config.root_dir if it's a function", function()
      local config = {
        root_dir = function(_, _)
          return '/function/root'
        end,
      }

      local root_dir = project.get_config_root_dir(config, '/test/file.kk')

      assert.equal('/function/root', root_dir)
    end)

    it('should use default implementation when no config.root_dir', function()
      local file_path = helpers.get_file_path('simple-package', 'src/main.kk')

      local root_dir = project.get_config_root_dir({}, file_path)

      -- Check that root_dir ends with the project path
      assert.is_true(root_dir and root_dir:match('simple%-package$') ~= nil)
    end)

    it('should work with callback', function()
      local config = { root_dir = '/callback/root' }

      local callback_root = nil
      project.get_config_root_dir(config, '/test/file.kk', function(root)
        callback_root = root
      end)

      assert.equal('/callback/root', callback_root)
    end)
  end)
end)
