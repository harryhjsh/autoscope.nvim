local autoscope = require("autoscope")
local builtin = require("telescope.builtin")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local exports = {}

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
  builtin.find_files(opts)
end

exports.git_files = function(opts)
  opts = opts or {}
  local pkg = autoscope.get_package_dir()
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
  builtin.git_files(opts)
end

exports.grep_string = function(opts)
  opts = opts or {}
  local pkg = autoscope.get_package_dir()
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
  builtin.grep_string(opts)
end

exports.live_grep = function(opts)
  opts = opts or {}
  local pkg = autoscope.get_package_dir()
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
