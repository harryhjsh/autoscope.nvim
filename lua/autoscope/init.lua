local defaults = require("autoscope.default_presets")

---@class AutoscopeConfig
---@field presets table<string, WorkspaceTool>: extend builtin presets (default: {})
---@field priorities string[]: match order for presets -- presets absent from this array won't attempt to match (default: {"pnpm", "yarn", "npm", "gitmodules"})
---@field silent boolean: todo (default: false)
---@field debug boolean: todo (default: false)
---@field root_dir? string: the directory to find a workspace in (default: cwd)
---@field skip_root_dir? boolean: don't match root_dir as a package directory (regardless of parse output) (default: true)
---@field skip_root_dir_by_preset? table<string, boolean>: override skip_root_dir for specific preset names
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
---@field get_excluded_package_dirs fun(pkg?: WorkspacePackage): string[]

local M = {}

---@param path string
---@return string
local function normalize_abs(path)
  local abs = vim.fn.fnamemodify(path, ":p:h")
  return abs:gsub("[\\/]+$", "")
end

---@return boolean
local function get_effective_skip_root_dir()
  local used_preset = M._state.used_preset
  local skip_root_dir = M.config.skip_root_dir
  if used_preset and type(M.config.skip_root_dir_by_preset) == "table" then
    local override = M.config.skip_root_dir_by_preset[used_preset]
    if type(override) == "boolean" then
      skip_root_dir = override
    end
  end
  return skip_root_dir
end

---@param pkg WorkspacePackage
---@return boolean
local function is_root_package(pkg)
  if not pkg then
    return false
  end
  if pkg.name == "(root)" then
    return true
  end
  if not M.config.root_dir then
    return false
  end
  return normalize_abs(pkg.path) == normalize_abs(M.config.root_dir)
end

---@type AutoscopeConfig
M.config = {
  presets = defaults,
  priorities = { "pnpm", "yarn", "npm", "gitmodules" },
  silent = false,
  debug = false,
  skip_root_dir = true,
  skip_root_dir_by_preset = {
    gitmodules = false,
  },
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
  return p.parse(data, cwd)
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
  local skip_root_dir = get_effective_skip_root_dir()

  local match = nil
  local match_len = 0
  for _, pkg in ipairs(packages) do
    local root = vim.fn.fnamemodify(pkg.path, ":p:h")
    if root == M.config.root_dir and skip_root_dir then
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

---@param pkg? WorkspacePackage
---@return string[]
M.get_excluded_package_dirs = function(pkg)
  if not pkg or get_effective_skip_root_dir() or not is_root_package(pkg) then
    return {}
  end
  if not M.config.root_dir then
    return {}
  end

  local root = normalize_abs(M.config.root_dir)
  local root_prefix_slash = root .. "/"
  local root_prefix_backslash = root .. "\\"
  local seen = {}
  local out = {}

  for _, other in ipairs(M._state.packages) do
    if not is_root_package(other) then
      local other_path = normalize_abs(other.path)
      local rel = nil
      if vim.startswith(other_path, root_prefix_slash) then
        rel = other_path:sub(#root_prefix_slash + 1)
      elseif vim.startswith(other_path, root_prefix_backslash) then
        rel = other_path:sub(#root_prefix_backslash + 1)
      end

      if rel and rel ~= "" then
        rel = rel:gsub("\\", "/"):gsub("^%./", ""):gsub("^/+", ""):gsub("/+$", "")
        if rel ~= "" and not seen[rel] then
          seen[rel] = true
          table.insert(out, rel)
        end
      end
    end
  end

  return out
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
