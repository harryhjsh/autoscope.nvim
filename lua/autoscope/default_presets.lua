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
    -- Supports Yarn Classic (v1) with `yarn workspaces info`
    -- Yarn Classic outputs JSON wrapped in plain text, e.g.: { "pkg-name": { "location": "packages/pkg", ... } }
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
    cmd = { "yarn", "workspaces", "info" },
    parse = function(output)
      -- Yarn Classic outputs JSON wrapped in text, need to extract it
      -- The output looks like: "yarn workspaces v1.22.22\n{...json...}\nDone in 0.05s."
      local json_str = output:match("{.*}")
      if not json_str then
        return {}
      end
      local ok, data = pcall(vim.json.decode, json_str)
      if not ok or type(data) ~= "table" then
        return {}
      end
      local packages = {}
      -- Data is an object with workspace names as keys
      for name, info in pairs(data) do
        if info.location then
          local abs_path = vim.fn.fnamemodify(info.location, ":p:h")
          table.insert(packages, {
            name = name,
            path = abs_path,
          })
        end
      end
      return packages
    end,
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
    -- moonrepo - Build orchestrator and monorepo management tool
    detect = function()
      -- Check for .moon/workspace.yml or .moon/workspace.pkl (Pkl config support)
      return vim.fn.isdirectory(".moon") == 1
        and (vim.fn.filereadable(".moon/workspace.yml") == 1 or vim.fn.filereadable(".moon/workspace.pkl") == 1)
    end,
    cmd = { "moon", "query", "projects", "--json" },
    parse = function(output)
      -- moon outputs JSON array of projects
      -- Each project has fields like: id, source, type, language, etc.
      local ok, data = pcall(vim.json.decode, output)
      if not ok or type(data) ~= "table" then
        return {}
      end
      local packages = {}
      -- Handle both array format and object format
      local projects = data.projects or data
      for _, project in ipairs(projects) do
        -- Use 'id' for name and 'source' for path
        if project.id and project.source then
          local abs_path = vim.fn.fnamemodify(project.source, ":p:h")
          table.insert(packages, {
            name = project.id,
            path = abs_path,
          })
        end
      end
      return packages
    end,
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
