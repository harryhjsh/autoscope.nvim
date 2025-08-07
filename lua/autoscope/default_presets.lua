---@class WorkspacePackage
---@field name string
---@field path string Absolute path

---@class WorkspaceTool
---@field detect fun(): boolean Function to detect if this workspace tool is used in the current project
---@field cmd table Command array to execute for listing workspace packages
---@field parse fun(output: string): WorkspacePackage[] Function to parse the command output into a list of workspace packages

---@type table<string, WorkspaceTool>
return {
  pnpm = {
    detect = function()
      return vim.fn.filereadable("pnpm-workspace.yaml") == 1 or vim.fn.filereadable("pnpm-workspace.yml") == 1
    end,
    cmd = { "pnpm", "ls", "--recursive", "--depth=-1", "--json" },
    parse = function(output)
      local ok, data = pcall(vim.json.decode, output)
      if not ok or type(data) ~= "table" then
        return {}
      end
      local packages = {}
      for _, pkg in ipairs(data) do
        if pkg.path and pkg.name then
          local abs_path = vim.fn.fnamemodify(pkg.path, ":p:h")
          table.insert(packages, {
            name = pkg.name,
            path = abs_path,
          })
        end
      end
      return packages
    end,
  },
  yarn = {
    cmd = {},
    detect = function() end,
    parse = function() end,
  },
  npm = {
    cmd = { "npm", "query", ".workspace", "--json" },
    detect = function()
      if vim.fn.filereadable("package.json") == 0 then
        return false
      end
      local ok, content = pcall(function()
        local lines = vim.fn.readfile("package.json")
        return vim.json.decode(table.concat(lines, "\n"))
      end)
      return ok and type(content) == "table" and content.workspaces ~= nil
    end,
    parse = function(output)
      local ok, data = pcall(vim.json.decode, output)
      if not ok or type(data) ~= "table" then
        return {}
      end
      local packages = {}
      for _, pkg in ipairs(data) do
        if pkg.name and (pkg.realpath or pkg.path) then
          local path = pkg.realpath or pkg.path
          local abs_path = vim.fn.fnamemodify(path, ":p:h")
          table.insert(packages, {
            name = pkg.name,
            path = abs_path,
          })
        end
      end
      return packages
    end,
  },
  cargo = {
    cmd = {},
    detect = function() end,
    parse = function() end,
  },
  moon = {
    cmd = {},
    detect = function() end,
    parse = function() end,
  },
  turbo = {
    cmd = {},
    detect = function() end,
    parse = function() end,
  },
  nx = {
    cmd = {},
    detect = function() end,
    parse = function() end,
  },
}
