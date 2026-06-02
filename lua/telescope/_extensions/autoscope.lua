local autoscope = require("autoscope")
local builtin = require("telescope.builtin")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local exports = {}

---@param dirs string[]
---@return string[]
local function rg_exclude_glob_args(dirs)
  local args = {}
  for _, dir in ipairs(dirs) do
    table.insert(args, "--glob")
    table.insert(args, "!" .. dir .. "/**")
  end
  return args
end

---@param dirs string[]
---@return string[]
local function fd_exclude_args(dirs)
  local args = {}
  for _, dir in ipairs(dirs) do
    table.insert(args, "--exclude")
    table.insert(args, dir)
  end
  return args
end

---@param opts table
---@param extra string[]
local function merge_additional_args(opts, extra)
  if #extra == 0 then
    return
  end
  local prev = opts.additional_args
  if type(prev) == "function" then
    opts.additional_args = function(...)
      local existing = prev(...) or {}
      return vim.list_extend(existing, vim.deepcopy(extra))
    end
  elseif type(prev) == "table" then
    opts.additional_args = vim.list_extend(prev, vim.deepcopy(extra))
  else
    opts.additional_args = vim.deepcopy(extra)
  end
end

---@param opts table
---@param excluded_dirs string[]
local function apply_find_files_excludes(opts, excluded_dirs)
  if #excluded_dirs == 0 or opts.find_command ~= nil then
    return
  end

  local cmd = nil
  if vim.fn.executable("rg") == 1 then
    cmd = { "rg", "--files", "--color", "never" }
    vim.list_extend(cmd, rg_exclude_glob_args(excluded_dirs))
  elseif vim.fn.executable("fd") == 1 then
    cmd = { "fd", "--type", "f", "--strip-cwd-prefix" }
    vim.list_extend(cmd, fd_exclude_args(excluded_dirs))
  elseif vim.fn.executable("fdfind") == 1 then
    cmd = { "fdfind", "--type", "f", "--strip-cwd-prefix" }
    vim.list_extend(cmd, fd_exclude_args(excluded_dirs))
  end

  if cmd then
    opts.find_command = cmd
  end
end

---@param opts table
---@param excluded_dirs string[]
local function apply_git_files_excludes(opts, excluded_dirs)
  if #excluded_dirs == 0 or opts.git_command ~= nil then
    return
  end

  local cmd = { "git", "ls-files", "--exclude-standard", "--cached", "--others", "--", "." }
  for _, dir in ipairs(excluded_dirs) do
    table.insert(cmd, ":(exclude)" .. dir .. "/**")
  end
  opts.git_command = cmd
end

---@param opts table
---@param pkg WorkspacePackage
---@return string[]
local function get_excluded_dirs_for_pkg(opts, pkg)
  return autoscope.get_excluded_package_dirs(pkg)
end

exports.find_files = function(opts)
  opts = opts or {}
  local pkg = opts.pkg or autoscope.get_package_dir()
  if not pkg then
    if autoscope.config.fallback_to_builtin then
      builtin.find_files(opts)
    end
    return
  end
  opts = vim.tbl_deep_extend("force", {
    cwd = pkg.path,
    prompt_title = "Find Files in " .. pkg.name,
  }, opts)
  apply_find_files_excludes(opts, get_excluded_dirs_for_pkg(opts, pkg))
  builtin.find_files(opts)
end

exports.git_files = function(opts)
  opts = opts or {}
  local pkg = opts.pkg or autoscope.get_package_dir()
  if not pkg then
    if autoscope.config.fallback_to_builtin then
      builtin.git_files(opts)
    end
    return
  end
  opts = vim.tbl_deep_extend("force", {
    cwd = pkg.path,
    use_git_root = false,
    prompt_title = "Git Files in " .. pkg.name,
  }, opts)
  apply_git_files_excludes(opts, get_excluded_dirs_for_pkg(opts, pkg))
  builtin.git_files(opts)
end

exports.grep_string = function(opts)
  opts = opts or {}
  local pkg = opts.pkg or autoscope.get_package_dir()
  if not pkg then
    if autoscope.config.fallback_to_builtin then
      builtin.grep_string(opts)
    end
    return
  end
  local orig = opts.prompt_title or "Find Word (??) in "
  opts = vim.tbl_deep_extend("force", {
    cwd = pkg.path,
    prompt_title = orig .. pkg.name,
  }, opts)
  merge_additional_args(opts, rg_exclude_glob_args(get_excluded_dirs_for_pkg(opts, pkg)))
  builtin.grep_string(opts)
end

exports.live_grep = function(opts)
  opts = opts or {}
  local pkg = opts.pkg or autoscope.get_package_dir()
  if not pkg then
    if autoscope.config.fallback_to_builtin then
      builtin.live_grep(opts)
    end
    return
  end
  opts = vim.tbl_deep_extend("force", {
    cwd = pkg.path,
    prompt_title = "Live Grep in " .. pkg.name,
  }, opts)
  merge_additional_args(opts, rg_exclude_glob_args(get_excluded_dirs_for_pkg(opts, pkg)))
  builtin.live_grep(opts)
end

exports.refresh_packages = autoscope.refresh

exports.list_packages = function(opts)
  opts = opts or {}
  pickers
    .new(opts, {
      prompt_title = "Find Workspace Packages",
      finder = finders.new_table({
        results = autoscope.get_packages(),
        entry_maker = function(pkg)
          return {
            value = pkg,
            display = pkg.name,
            ordinal = pkg.name,
          }
        end,
      }),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)

          if selection then
            exports.find_files({ pkg = selection.value })
          end
        end)
        return true
      end,
      sorter = conf.generic_sorter(opts),
      previewer = require("autoscope.previewer.package_header")
    })
    :find()
end

return require("telescope").register_extension({
  setup = autoscope.setup,
  exports = exports,
})
