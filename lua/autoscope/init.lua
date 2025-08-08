local defaults = require("autoscope.default_presets")

---@class AutoscopeConfig
---@field presets table<string, WorkspaceTool>: extend builtin presets (default: {})
---@field priorities string[]: match order for presets -- presets absent from this array won't attempt to match (default: {"pnpm", "yarn", "npm"})
---@field silent boolean: todo (default: false)
---@field debug boolean: todo (default: false)
---@field root_dir? string: the directory to find a workspace in (default: cwd)
---@field skip_root_dir? boolean: don't match root_dir as a package directory (regardless of parse output) (default: true)
---@field fallback_to_builtin? boolean: use matching unwrapped picker if no package directory found (default: true)

---@class AutoscopeState
---@field packages WorkspacePackage[]
---@field used_preset? string
---@field initialised boolean

---@class AutoscopeModule
---@field config AutoscopeConfig
---@field _state AutoscopeState
---@field setup fun(opts?: table)
---@field get_package_dir fun(path?: string): WorkspacePackage?
---@field get_packages fun(cwd?: string): WorkspacePackage[]

local M = {}

---@type AutoscopeConfig
M.config = {
  presets = defaults,
  priorities = { "pnpm", "yarn", "npm" },
  silent = false,
  debug = false,
  skip_root_dir = true,
  fallback_to_builtin = true,
}

---@type AutoscopeState
M._state = {
  packages = {},
  initialised = false,
}

---@param name string
---@param cwd string
---@return WorkspacePackage[]?
local function do_preset(name, cwd)
  local p = M.config.presets[name]
  local yes = p.detect()
  if not yes then
    return
  end
  local ok, res = pcall(vim.system, p.cmd, { text = true, cwd = cwd })
  if not ok then
    return
  end
  local data = res:wait().stdout
  if not data then
    return
  end
  return p.parse(data)
end

---@param cwd string
local function get_packages(cwd)
  if M._state.initialised then
    return M._state.packages
  end
  for _, name in ipairs(M.config.priorities) do
    local packages = do_preset(name, cwd)
    if packages then
      M._state.initialised = true
      M._state.packages = packages
      M._state.used_preset = name
      break
    end
  end
  if not M._state.initialised then
    -- didn't find anything to use
  end
end

---@param opts? table
M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts)
  M.config.root_dir = M.config.root_dir or vim.fn.getcwd()
  get_packages(M.config.root_dir)
end

---@param path? string
---@return WorkspacePackage?
M.get_package_dir = function(path)
  path = path or vim.fn.expand("%:p:h")
  local packages = M._state.packages

  local match = nil
  local match_len = 0
  for _, pkg in ipairs(packages) do
    local root = vim.fn.fnamemodify(pkg.path, ":p:h")
    if root == M.config.root_dir and M.config.skip_root_dir then
      goto continue
    end

    local inside = vim.startswith(path, root)
    local len = root:len()
    if inside and len > match_len then
      match = pkg
      match_len = len
    end

    ::continue::
  end

  return match
end

---@param cwd? string
---@return WorkspacePackage[]
M.get_packages = function(cwd)
  get_packages(cwd or M.config.root_dir or vim.fn.getcwd())
  return M._state.packages
end

M.refresh = function()
  M._state.initialised = false
  get_packages(M.config.root_dir)
end

return M
