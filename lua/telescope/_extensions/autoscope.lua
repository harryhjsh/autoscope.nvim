local autoscope = require("autoscope")

local exports = {}

exports.find_files = function(opts)
  opts = opts or {}
  local pkg = autoscope.get_package_dir()
  if not pkg then
    if autoscope.config.fallback_to_builtin then
      require("telescope.builtin").find_files(opts)
    end
    return
  end
  opts = vim.tbl_deep_extend("force", {
    cwd = pkg.path,
    prompt_title = "Find Files in " .. pkg.name,
  }, opts)
  require("telescope.builtin").find_files(opts)
end

exports.git_files = function(opts)
  opts = opts or {}
  local pkg = autoscope.get_package_dir()
  if not pkg then
    if autoscope.config.fallback_to_builtin then
      require("telescope.builtin").git_files(opts)
    end
    return
  end
  opts = vim.tbl_deep_extend("force", {
    cwd = pkg.path,
    use_git_root = false,
    prompt_title = "Git Files in " .. pkg.name,
  }, opts)
  require("telescope.builtin").git_files(opts)
end

exports.grep_string = function(opts)
  opts = opts or {}
  local pkg = autoscope.get_package_dir()
  if not pkg then
    if autoscope.config.fallback_to_builtin then
      require("telescope.builtin").grep_string(opts)
    end
    return
  end
  local orig = opts.prompt_title or "Find Word (??) in "
  opts = vim.tbl_deep_extend("force", {
    cwd = pkg.path,
    prompt_title = orig .. pkg.name,
  }, opts)
  require("telescope.builtin").grep_string(opts)
end

exports.live_grep = function(opts)
  opts = opts or {}
  local pkg = autoscope.get_package_dir()
  if not pkg then
    if autoscope.config.fallback_to_builtin then
      require("telescope.builtin").live_grep(opts)
    end
    return
  end
  opts = vim.tbl_deep_extend("force", {
    cwd = pkg.path,
    prompt_title = "Live Grep in " .. pkg.name,
  }, opts)
  require("telescope.builtin").live_grep(opts)
end

exports.list_packages = function()
  -- TODO new picker
end

exports.refresh_packages = autoscope.refresh

return require("telescope").register_extension({
  setup = autoscope.setup,
  exports = exports,
})
