---@mod koka.project
---@brief [[
---Project detection and configuration management for Koka
---@brief ]]
local constant = require('koka.constant')

local project = {}

---@class koka.project.Config
---@field cwd? string Current working directory for compiler / running the output
---@field target string target (c,c32,c64c,wasm,jsnode)
---@field include_dirs string[] compiler include directories
---@field compiler_args string[] extra arguments to pass

---@param path string The directory to search upward from
---@param callback? fun(project_dir: string?, project_config: koka.project.Config?) If `nil`, this function runs synchronously
---@return string? project_dir (if `callback ~= nil` and successful)
---@return koka.project.Config? project_config (if `callback ~= nil` and successful)
local function get_project_config(path, callback)
  -- First find the project directory by looking for koka.json, .koka.json, or package.kk
  local project_dir = vim.fs.dirname(vim.fs.find({ 'koka.json', '.koka.json', 'package.kk' }, {
    upward = true,
    path = path,
  })[1])

  if not project_dir then
    return callback and callback(nil, nil) or nil, nil
  end

  -- Try to find and parse configuration files
  local config_files = { 'koka.json', '.koka.json' }
  local project_config = nil

  for _, config_file in ipairs(config_files) do
    local config_path = vim.fs.joinpath(project_dir, config_file)
    local file = io.open(config_path, 'r')
    if file then
      local content = file:read('*all')
      file:close()

      local ok, config = pcall(vim.json.decode, content)
      if ok and config then
        project_config = config
        break
      else
        vim.notify(
          string.format('[koka.nvim] Error parsing config file %s: %s', config_path, config),
          vim.log.levels.ERROR
        )
      end
    end
  end

  return callback and callback(project_dir, project_config) or project_dir, project_config
end

---The default implementation used for `vim.g.koka.server.root_dir`
---@param file_name string
---@param callback? fun(root_dir: string | nil) If `nil`, this function runs synchronously
---@return string | nil root_dir (if `callback ~= nil` and successful)
local function default_get_root_dir(file_name, callback)
  local stat = vim.uv.fs_stat(file_name)
  if not stat then
    return callback and callback(nil) or nil
  end
  local path = stat.type == 'file' and vim.fs.dirname(file_name) or file_name
  if not path or not vim.uv.fs_stat(path) then
    return callback and callback(nil) or nil
  end

  ---@param project_dir? string
  ---@param project_config? koka.project.Config
  ---@return string | nil root_dir
  local function root_dir(project_dir, project_config)
    -- If project_config has explicit cwd, use that
    if project_config and project_config.cwd then
      return project_config.cwd
    end
    -- Otherwise use the project directory (where koka.json or package.kk was found)
    return project_dir
  end
  if callback then
    get_project_config(path, function(project_dir, project_config)
      callback(root_dir(project_dir, project_config))
    end)
  else
    local project_dir, project_config = get_project_config(path)
    return root_dir(project_dir, project_config)
  end
end

---Checks if there is an active Koka LSP client for file_name and returns its root directory if found.
---@param file_name string
---@return string | nil root_dir The root directory of the active client for file_name (if there is one)
local function get_mb_active_client_root(file_name)
  local clients = vim.lsp.get_active_clients { name = constant.lsp_client_name }
  for _, client in ipairs(clients) do
    if client.config.root_dir and vim.startswith(file_name, client.config.root_dir) then
      return client.config.root_dir
    end
  end
  return nil
end

---Attempts to find the root for an existing active client. If no existing
---client root is found, returns the result of evaluating `config.root_dir`.
---@param config table LSP client configuration
---@param file_name string
---@param callback? fun(root_dir: string?) If `nil`, this function runs synchronously
---@return string | nil root_dir
function project.get_config_root_dir(config, file_name, callback)
  local reuse_active = get_mb_active_client_root(file_name)
  if reuse_active then
    return callback and callback(reuse_active) or reuse_active
  end
  if type(config.root_dir) == 'function' then
    local root_dir = config.root_dir(file_name, default_get_root_dir)
    return callback and callback(root_dir) or root_dir
  elseif type(config.root_dir) == 'string' then
    local root_dir = config.root_dir
    ---@cast root_dir string
    return callback and callback(root_dir) or root_dir
  else
    return default_get_root_dir(file_name, callback)
  end
end

---Get project configuration for the given file or current buffer
---@param file_name? string The file path (defaults to current buffer)
---@param callback? fun(project_config: koka.project.Config?) If `nil`, this function runs synchronously
---@return koka.project.Config? project_config
function project.get_project_config(file_name, callback)
  file_name = file_name or vim.api.nvim_buf_get_name(0)
  local current_dir = vim.fs.dirname(file_name)

  if callback then
    get_project_config(current_dir, function(_, project_config)
      callback(project_config)
    end)
  else
    local _, project_config = get_project_config(current_dir)
    return project_config
  end
end

---Get resolved project configuration with defaults applied
---@param file_name? string The file path (defaults to current buffer)
---@param callback? fun(resolved_config: koka.project.Config) If `nil`, this function runs synchronously
---@return koka.project.Config resolved_config
function project.get_resolved_config(file_name, callback)
  file_name = file_name or vim.api.nvim_buf_get_name(0)
  local current_dir = vim.fs.dirname(file_name)

  local default_config = {
    target = 'c',
    cwd = nil, -- will be resolved
    include_dirs = {},
    compiler_args = {},
  }

  ---@param project_config? koka.project.Config
  ---@return koka.project.Config
  local function resolve_config(project_config)
    local resolved = vim.deepcopy(default_config)

    if project_config then
      -- Merge top-level fields
      for key, value in pairs(project_config) do
        resolved[key] = value
      end
    end
    return resolved
  end
  if callback then
    get_project_config(current_dir, function(project_dir, project_config)
      local resolved = resolve_config(project_config)
      -- Resolve cwd if not explicitly set
      if not resolved.cwd then
        resolved.cwd = project_dir or current_dir
      end
      callback(resolved)
    end)
  else
    local project_dir, project_config = get_project_config(current_dir)
    local resolved = resolve_config(project_config)
    -- Resolve cwd if not explicitly set
    if not resolved.cwd then
      resolved.cwd = project_dir or current_dir
    end
    return resolved
  end
end

return project
