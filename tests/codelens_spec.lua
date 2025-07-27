local helpers = require('tests.helpers')

---@diagnostic disable: duplicate-set-field

describe('koka.commands.codelens', function()
  local codelens

  before_each(function()
    helpers.reset_mocks()
    codelens = require('koka.commands.codelens')
  end)

  describe('find_runnables', function()
    it('should detect main function', function()
      -- Create a test buffer with main function
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        'fun main() {',
        '  println("Hello, world!")',
        '}',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      local runnables = codelens.get_codelenses(bufnr)

      assert.equal(1, #runnables)
      assert.equal(0, runnables[1].range.start.line)
      assert.equal('koka.run', runnables[1].command.command)
      assert.same({ 'run', vim.api.nvim_buf_get_name(bufnr), 'main' }, runnables[1].command.arguments)
    end)

    it('should detect test functions', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        'fun testBasic() {',
        '  assert(true)',
        '}',
        '',
        'fun testAdvanced() {',
        '  assert(1 + 1 == 2)',
        '}',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      local runnables = codelens.get_codelenses(bufnr)

      assert.equal(2, #runnables)
      assert.equal('testBasic', runnables[1].command.arguments[3])
      assert.equal('testAdvanced', runnables[2].command.arguments[3])
    end)

    it('should detect example functions', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        'fun exampleUsage() {',
        '  println("Example")',
        '}',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      local runnables = codelens.get_codelenses(bufnr)

      assert.equal(1, #runnables)
      assert.equal('example', runnables[1].command.arguments[1])
      assert.equal('exampleUsage', runnables[1].command.arguments[3])
    end)

    it('should handle pub functions without module declaration', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        'pub fun main() {',
        '  println("Public main")',
        '}',
        '',
        'fun testPrivate() {',
        '  assert(true)',
        '}',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      local runnables = codelens.get_codelenses(bufnr)

      assert.equal(2, #runnables) -- Both pub and non-pub should be detected
      assert.equal('main', runnables[1].command.arguments[3])
      assert.equal('testPrivate', runnables[2].command.arguments[3])
    end)

    it('should require pub functions when module is declared', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        'module test',
        '',
        'pub fun main() {',
        '  println("Public main")',
        '}',
        '',
        'fun testPrivate() {',
        '  assert(true)',
        '}',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      local runnables = codelens.get_codelenses(bufnr)

      assert.equal(1, #runnables) -- Only pub function should be detected
      assert.equal('main', runnables[1].command.arguments[3])
    end)

    it('should ignore non-runnable functions', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        'fun helper() {',
        '  return 42',
        '}',
        '',
        'fun calculate(x: int) {',
        '  x + 1',
        '}',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      local runnables = codelens.get_codelenses(bufnr)

      assert.equal(0, #runnables)
    end)
  end)

  describe('handle_run_command', function()
    it('should construct correct koka command', function()
      local executed_cmd = nil
      local executed_cwd = nil

      -- Mock termopen
      vim.fn.termopen = function(cmd, opts)
        executed_cmd = cmd
        executed_cwd = opts.cwd
        return 1
      end

      -- Mock vim.cmd for tabnew and startinsert
      local tabnew_called = false
      local startinsert_called = false
      local original_cmd = vim.cmd
      vim.cmd = function(cmd)
        if cmd == 'tabnew' then
          tabnew_called = true
        elseif cmd == 'startinsert' then
          startinsert_called = true
        else
          original_cmd(cmd)
        end
      end

      -- Mock project configuration
      package.loaded['koka.project'] = {
        get_resolved_config = function(_, callback)
          callback {
            target = 'wasm',
            cwd = '/test/project',
            include_dirs = { 'lib', 'src' },
            compiler_args = { '--optimize' },
          }
        end,
      }

      codelens.handle_run_command('run', '/test/project/main.kk', 'main')

      assert.is_true(tabnew_called)
      assert.is_true(startinsert_called)
      assert.equal('/test/project', executed_cwd)
      assert.is_not_nil(executed_cmd:match('koka'))
      assert.is_not_nil(executed_cmd:match('--target=wasm'))
      assert.is_not_nil(executed_cmd:match('--include=lib'))
      assert.is_not_nil(executed_cmd:match('--include=src'))
      assert.is_not_nil(executed_cmd:match('--optimize'))
      assert.is_not_nil(executed_cmd:match('-e'))
      assert.is_not_nil(executed_cmd:match('/test/project/main.kk'))

      -- Restore original vim.cmd
      vim.cmd = original_cmd
    end)
  end)

  describe('run_at_cursor', function()
    it('should run function at cursor position', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        'fun helper() {',
        '  return 42',
        '}',
        '',
        'fun main() {',
        '  println("Hello")',
        '}',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      -- Mock current buffer and cursor
      vim.api.nvim_get_current_buf = function()
        return bufnr
      end
      vim.api.nvim_win_get_cursor = function(_)
        return { 5, 0 } -- Line 5 (1-indexed) where main function is
      end

      local run_called = false
      local run_args = nil
      codelens.handle_run_command = function(action_type, file_path, func_name)
        run_called = true
        run_args = { action_type, file_path, func_name }
      end

      codelens.run_at_cursor()

      assert.is_true(run_called)
      assert.equal('run', run_args[1])
      assert.equal('main', run_args[3])
    end)

    it('should warn when no runnable function at cursor', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {
        'fun helper() {',
        '  return 42',
        '}',
      }
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      vim.api.nvim_get_current_buf = function()
        return bufnr
      end
      vim.api.nvim_win_get_cursor = function(_)
        return { 1, 0 } -- Line 1 where helper function is (not runnable)
      end

      local warned = false
      vim.notify = function(_, level)
        if level == vim.log.levels.WARN then
          warned = true
        end
      end

      codelens.run_at_cursor()

      assert.is_true(warned)
    end)
  end)
end)
