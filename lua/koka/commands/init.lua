---@mod koka.commands
---@brief [[
---User commands for Koka development
---@brief ]]

local M = {}

---Setup Koka user commands
function M.setup()
  local codelens = require('koka.commands.codelens')

  -- Command to run function at cursor
  vim.api.nvim_create_user_command('KokaRun', function()
    codelens.run_at_cursor()
  end, {
    desc = 'Run Koka function at cursor',
  })

  -- Command to build current file/project
  vim.api.nvim_create_user_command('KokaBuild', function(opts)
    local args = opts.fargs
    local file_path = #args > 0 and args[1] or vim.api.nvim_buf_get_name(0)
    M.build_file(file_path)
  end, {
    nargs = '?',
    complete = 'file',
    desc = 'Build Koka file or project',
  })

  -- Command to test current project
  vim.api.nvim_create_user_command('KokaTest', function()
    M.run_tests()
  end, {
    desc = 'Run Koka tests',
  })

  -- Command to show project configuration
  vim.api.nvim_create_user_command('KokaShowConfig', function()
    M.show_config()
  end, {
    desc = 'Show current Koka project configuration',
  })

  -- Code lens refresh command
  vim.api.nvim_create_user_command('KokaRefreshCodeLens', function()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.lsp.codelens.refresh { bufnr = bufnr }
    -- Also refresh our custom code lenses
    codelens.display_custom_codelenses(bufnr)
    vim.notify('Code lenses refreshed', vim.log.levels.INFO)
  end, {
    desc = 'Refresh Koka code lenses',
  })
end

---Build a Koka file
---@param file_path string
function M.build_file(file_path)
  local project = require('koka.project')

  project.get_resolved_config(file_path, function(config)
    local cmd = { 'koka' }

    -- Add target
    if config.target and config.target ~= 'c' then
      table.insert(cmd, '--target=' .. config.target)
    end

    -- Add include directories
    if config.include_dirs then
      for _, include_dir in ipairs(config.include_dirs) do
        table.insert(cmd, '--include=' .. include_dir)
      end
    end

    -- Add compiler arguments
    if config.compiler_args then
      for _, arg in ipairs(config.compiler_args) do
        table.insert(cmd, arg)
      end
    end

    -- Add compile flag
    table.insert(cmd, '-c')
    table.insert(cmd, file_path)

    -- Change to project directory
    local cwd = config.cwd or vim.fs.dirname(file_path)

    -- Create terminal command
    local term_cmd = table.concat(cmd, ' ')
    -- local title = string.format('Building: %s', vim.fs.basename(file_path))

    -- Run in terminal
    vim.cmd('tabnew')
    vim.fn.termopen(term_cmd, {
      cwd = cwd,
      on_exit = function(_, exit_code)
        if exit_code == 0 then
          vim.notify('✓ Build completed successfully', vim.log.levels.INFO)
        else
          vim.notify(string.format('✗ Build failed with exit code %d', exit_code), vim.log.levels.ERROR)
        end
      end,
    })
    vim.cmd('startinsert')
  end)
end

---Run tests in the current project
function M.run_tests()
  local bufnr = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(bufnr)
  local codelens = require('koka.commands.codelens')

  -- Find test functions in current buffer and run them
  local runnables = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for _, line in ipairs(lines) do
    local func_name = line:match('^%s*pub%s*fun%s+([%w%-]+)%s*%(') or line:match('^%s*fun%s+([%w%-]+)%s*%(')
    if func_name and func_name:match('^test') then
      table.insert(runnables, {
        name = func_name,
        type = 'test',
      })
    end
  end

  if #runnables == 0 then
    vim.notify('No test functions found in current buffer', vim.log.levels.WARN)
    return
  end

  -- Run each test function
  for _, runnable in ipairs(runnables) do
    vim.notify(string.format('Running test: %s', runnable.name), vim.log.levels.INFO)
    codelens.handle_run_command(runnable.type, file_path, runnable.name)
  end
end

---Show current project configuration
function M.show_config()
  local file_path = vim.api.nvim_buf_get_name(0)
  local project = require('koka.project')

  project.get_resolved_config(file_path, function(config)
    local lines = {
      'Koka Project Configuration:',
      '',
      string.format('Target: %s', config.target or 'c'),
      string.format('Working Directory: %s', config.cwd or 'not set'),
    }

    if config.include_dirs and #config.include_dirs > 0 then
      table.insert(lines, 'Include Directories:')
      for _, dir in ipairs(config.include_dirs) do
        table.insert(lines, string.format('  - %s', dir))
      end
    end

    if config.compiler_args and #config.compiler_args > 0 then
      table.insert(lines, 'Compiler Arguments:')
      for _, arg in ipairs(config.compiler_args) do
        table.insert(lines, string.format('  - %s', arg))
      end
    end

    -- Create a floating window to display the configuration
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    local width = 50
    local height = #lines + 2
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    vim.api.nvim_open_win(buf, true, {
      relative = 'editor',
      width = width,
      height = height,
      row = row,
      col = col,
      style = 'minimal',
      border = 'rounded',
      title = 'Koka Configuration',
      title_pos = 'center',
    })

    -- Close on any key press
    vim.keymap.set('n', '<Esc>', '<cmd>close<cr>', { buffer = buf })
    vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = buf })
  end)
end

return M
