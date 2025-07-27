---@mod koka.debugger
---@brief [[
---Provide support for debugging and execution via Koka LSP
---@brief ]]

---@class koka.debugger.LaunchArguments
---@field program string An absolute path to the "program" to debug
---@field compiler_args? string[] Additional arguments
---@field program_args? string[] Additional arguments
---@field trace? boolean Enable logging
---@field function_name? string A single function to run (must have no effects and returns a type that is showable)

local M = {}

---Execute a program or function using Koka LSP
---@param client vim.lsp.Client The LSP client
---@param project_config koka.project.Config The project config
---@param args koka.debugger.LaunchArguments The execution arguments
---@param callback? function Callback function to handle the result
function M.execute(client, project_config, args, callback)
  local target = project_config.target or 'c'
  local additional_args = '--buildtag=nvim --target=' .. target

  if args.compiler_args then
    additional_args = additional_args .. ' ' .. table.concat(args.compiler_args, ' ')
  end

  local command_name, command_args
  if args.function_name then
    command_name = 'koka/compileFunction'
    command_args = { args.program, args.function_name, additional_args }
  else
    command_name = 'koka/compile'
    command_args = { args.program, additional_args }
  end

  -- Send LSP command request
  ---@diagnostic disable-next-line: param-type-mismatch
  client.request('workspace/executeCommand', {
    command = command_name,
    arguments = command_args,
    ---@diagnostic disable-next-line: param-type-mismatch
  }, function(err, result)
    if err then
      vim.notify('Error executing Koka command: ' .. tostring(err.message or err), vim.log.levels.ERROR)
      if callback then
        callback(nil, err)
      end
      return
    end

    if not result then
      vim.notify('Error generating code, see language server output for specifics', vim.log.levels.ERROR)
      if callback then
        callback(nil, 'No result from LSP')
      end
      return
    end

    local output_path = result
    local full_path = vim.fs.joinpath(project_config.cwd, output_path)

    -- Check if the generated file exists
    if vim.fn.filereadable(full_path) == 0 then
      vim.notify('Error finding generated code at ' .. output_path, vim.log.levels.ERROR)
      if callback then
        callback(nil, 'Generated file not found')
      end
      return
    end

    -- Execute the generated code based on target
    M._run_generated_code(target, full_path, args.program_args or {}, project_config.cwd, callback)
  end)
end

---Run the generated code based on target platform
---@param target string The compilation target
---@param executable_path string Path to the generated executable
---@param program_args string[] Arguments to pass to the program
---@param cwd string Working directory
---@param callback? function Callback function
function M._run_generated_code(target, executable_path, program_args, cwd, callback)
  local cmd, cmd_args

  if target == 'c' or target == 'c32' or target == 'c64c' then
    cmd = executable_path
    cmd_args = program_args
  elseif target == 'jsnode' then
    cmd = 'node'
    cmd_args = vim.list_extend({ executable_path }, program_args)
  else
    vim.notify(
      string.format('Running code for target %s is not yet supported. Output is at %s', target, executable_path),
      vim.log.levels.WARN
    )
    if callback then
      callback(executable_path, nil)
    end
    return
  end

  -- Create a new terminal tab for execution
  vim.cmd('tabnew')
  local term_cmd = cmd .. ' ' .. table.concat(cmd_args, ' ')
  vim.fn.termopen(term_cmd, {
    cwd = cwd,
    on_exit = function(_, exit_code)
      if exit_code == 0 then
        vim.notify('✓ Execution completed successfully', vim.log.levels.INFO)
      else
        vim.notify(string.format('✗ Execution failed with exit code %d', exit_code), vim.log.levels.ERROR)
      end
      if callback then
        callback(executable_path, exit_code)
      end
    end,
  })

  vim.cmd('startinsert')
end

---Compile and run a specific function
---@param client vim.lsp.Client The LSP client
---@param project_config koka.project.Config The project config
---@param program_path string Path to the Koka program
---@param function_name string Name of the function to run
---@param callback? function Callback function
function M.run_function(client, project_config, program_path, function_name, callback)
  M.execute(client, project_config, {
    program = program_path,
    function_name = function_name,
  }, callback)
end

---Compile and run the main function of a program
---@param client vim.lsp.Client The LSP client
---@param project_config koka.project.Config The project config
---@param program_path string Path to the Koka program
---@param callback? function Callback function
function M.run_main(client, project_config, program_path, callback)
  M.execute(client, project_config, {
    program = program_path,
  }, callback)
end

--- Launch the debugger (legacy interface)
---
--- @param client vim.lsp.Client The LSP client we want to send this
--- @param project_config koka.project.Config The project config this program need to use
--- @param args koka.debugger.LaunchArguments The debugger configs to use
function M.launch(client, project_config, args)
  M.execute(client, project_config, args)
end

return M
