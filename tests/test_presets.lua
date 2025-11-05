#!/usr/bin/env lua

-- Simple test framework
local tests_run = 0
local tests_passed = 0
local tests_failed = 0

local function assert_equal(actual, expected, message)
  if actual == expected then
    return true
  else
    error(string.format("%s\nExpected: %s\nActual: %s", message or "Assertion failed", tostring(expected), tostring(actual)))
  end
end

local function assert_true(value, message)
  if value then
    return true
  else
    error(message or "Expected true, got false")
  end
end

local function test(name, fn)
  tests_run = tests_run + 1
  io.write(string.format("Running test: %s ... ", name))
  local ok, err = pcall(fn)
  if ok then
    tests_passed = tests_passed + 1
    print("✓ PASS")
  else
    tests_failed = tests_failed + 1
    print("✗ FAIL")
    print("  Error: " .. tostring(err))
  end
end

-- Mock vim functions for testing
local function create_vim_mock()
  return {
    fn = {
      filereadable = function(path)
        local f = io.open(path, "r")
        if f then
          f:close()
          return 1
        end
        return 0
      end,
      isdirectory = function(path)
        -- Try to open as directory by checking if we can list it
        local ok = os.execute("test -d " .. path .. " 2>/dev/null")
        return ok and 1 or 0
      end,
      readfile = function(path)
        local f = io.open(path, "r")
        if not f then return {} end
        local lines = {}
        for line in f:lines() do
          table.insert(lines, line)
        end
        f:close()
        return lines
      end,
      fnamemodify = function(path, mods)
        -- Simple implementation for :p:h (absolute parent directory)
        if mods == ":p:h" then
          -- If path is relative, make it absolute
          if not path:match("^/") then
            local cwd = os.getenv("PWD") or "."
            path = cwd .. "/" .. path
          end
          -- Remove trailing slash
          path = path:gsub("/$", "")
          -- Get parent directory
          return path:match("(.*/)")  or "/"
        end
        return path
      end,
      getcwd = function()
        return os.getenv("PWD") or "."
      end,
    },
    json = {
      decode = function(str)
        -- Use a simple JSON decoder (requires lua-cjson or similar)
        -- For now, we'll use a simple implementation
        local json = require("dkjson") or require("cjson")
        return json.decode(str)
      end,
    },
    system = function(cmd, opts)
      local command = table.concat(cmd, " ")
      if opts and opts.cwd then
        command = string.format("cd %s && %s", opts.cwd, command)
      end
      local handle = io.popen(command)
      local result = handle:read("*a")
      handle:close()
      return {
        stdout = result,
        code = 0,
      }
    end,
    startswith = function(str, prefix)
      return str:sub(1, #prefix) == prefix
    end,
    tbl_deep_extend = function(behavior, ...)
      local result = {}
      local function deep_extend(dst, src)
        for k, v in pairs(src) do
          if type(v) == "table" and type(dst[k]) == "table" then
            dst[k] = deep_extend(dst[k], v)
          else
            dst[k] = v
          end
        end
        return dst
      end
      for _, tbl in ipairs({...}) do
        result = deep_extend(result, tbl)
      end
      return result
    end,
  }
end

-- Try to load JSON library
local json_ok, json = pcall(require, "dkjson")
if not json_ok then
  json_ok, json = pcall(require, "cjson")
end
if not json_ok then
  print("Warning: No JSON library found. Implementing basic JSON parser.")
  json = {
    decode = function(str)
      -- Very basic JSON decoder - only works for simple cases
      -- This is a fallback - production code should use proper JSON library
      return load("return " .. str:gsub("null", "nil"):gsub("true", "true"):gsub("false", "false"))()
    end
  }
end

_G.vim = create_vim_mock()
_G.vim.json = json

-- Load the presets module
local test_dir = debug.getinfo(1).source:match("@?(.*/)") or "./"
local project_root = test_dir:gsub("tests/$", "")
package.path = project_root .. "lua/?.lua;" .. project_root .. "lua/?/init.lua;" .. package.path

local presets = require("autoscope.default_presets")

-- Test fixtures
local fixtures_dir = project_root .. "tests/fixtures/"

-- Tests
test("pnpm preset detects workspace", function()
  local old_cwd = vim.fn.getcwd()
  os.execute("cd " .. fixtures_dir .. "pnpm-workspace")
  _G.PWD = fixtures_dir .. "pnpm-workspace"

  assert_true(presets.pnpm.detect(), "pnpm workspace should be detected")
end)

test("pnpm preset lists packages", function()
  local result = vim.system(presets.pnpm.cmd, {
    text = true,
    cwd = fixtures_dir .. "pnpm-workspace"
  })

  local packages = presets.pnpm.parse(result.stdout)

  assert_true(#packages == 5, string.format("Expected 5 packages, got %d", #packages))

  -- Check that we have the expected packages
  local names = {}
  for _, pkg in ipairs(packages) do
    names[pkg.name] = true
  end

  assert_true(names["@test/lib-a"], "Should have @test/lib-a")
  assert_true(names["@test/lib-b"], "Should have @test/lib-b")
  assert_true(names["@test/lib-c"], "Should have @test/lib-c")
  assert_true(names["@test/app-1"], "Should have @test/app-1")
  assert_true(names["@test/app-2"], "Should have @test/app-2")
end)

test("npm preset detects workspace", function()
  os.execute("cd " .. fixtures_dir .. "npm-workspace")

  -- Temporarily change working directory for detection
  local old_filereadable = vim.fn.filereadable
  local old_readfile = vim.fn.readfile

  vim.fn.filereadable = function(path)
    return old_filereadable(fixtures_dir .. "npm-workspace/" .. path)
  end

  vim.fn.readfile = function(path)
    return old_readfile(fixtures_dir .. "npm-workspace/" .. path)
  end

  local result = presets.npm.detect()

  vim.fn.filereadable = old_filereadable
  vim.fn.readfile = old_readfile

  assert_true(result, "npm workspace should be detected")
end)

test("npm preset lists packages", function()
  local result = vim.system(presets.npm.cmd, {
    text = true,
    cwd = fixtures_dir .. "npm-workspace"
  })

  local packages = presets.npm.parse(result.stdout)

  assert_true(#packages == 5, string.format("Expected 5 packages, got %d", #packages))

  local names = {}
  for _, pkg in ipairs(packages) do
    names[pkg.name] = true
  end

  assert_true(names["@test/npm-lib-a"], "Should have @test/npm-lib-a")
  assert_true(names["@test/npm-lib-b"], "Should have @test/npm-lib-b")
  assert_true(names["@test/npm-lib-c"], "Should have @test/npm-lib-c")
  assert_true(names["@test/npm-app-1"], "Should have @test/npm-app-1")
  assert_true(names["@test/npm-app-2"], "Should have @test/npm-app-2")
end)

test("yarn preset detects workspace", function()
  local old_filereadable = vim.fn.filereadable
  local old_readfile = vim.fn.readfile

  vim.fn.filereadable = function(path)
    return old_filereadable(fixtures_dir .. "yarn-workspace/" .. path)
  end

  vim.fn.readfile = function(path)
    return old_readfile(fixtures_dir .. "yarn-workspace/" .. path)
  end

  local result = presets.yarn.detect()

  vim.fn.filereadable = old_filereadable
  vim.fn.readfile = old_readfile

  assert_true(result, "yarn workspace should be detected")
end)

test("yarn preset lists packages", function()
  local result = vim.system(presets.yarn.cmd, {
    text = true,
    cwd = fixtures_dir .. "yarn-workspace"
  })

  local packages = presets.yarn.parse(result.stdout)

  assert_true(#packages == 5, string.format("Expected 5 packages, got %d", #packages))

  local names = {}
  for _, pkg in ipairs(packages) do
    names[pkg.name] = true
  end

  assert_true(names["@test/yarn-lib-a"], "Should have @test/yarn-lib-a")
  assert_true(names["@test/yarn-lib-b"], "Should have @test/yarn-lib-b")
  assert_true(names["@test/yarn-lib-c"], "Should have @test/yarn-lib-c")
  assert_true(names["@test/yarn-app-1"], "Should have @test/yarn-app-1")
  assert_true(names["@test/yarn-app-2"], "Should have @test/yarn-app-2")
end)

test("moon preset detects workspace", function()
  local old_isdirectory = vim.fn.isdirectory
  local old_filereadable = vim.fn.filereadable

  vim.fn.isdirectory = function(path)
    return old_isdirectory(fixtures_dir .. "moon-workspace/" .. path)
  end

  vim.fn.filereadable = function(path)
    return old_filereadable(fixtures_dir .. "moon-workspace/" .. path)
  end

  local result = presets.moon.detect()

  vim.fn.isdirectory = old_isdirectory
  vim.fn.filereadable = old_filereadable

  assert_true(result, "moon workspace should be detected")
end)

test("moon preset lists packages", function()
  local result = vim.system(presets.moon.cmd, {
    text = true,
    cwd = fixtures_dir .. "moon-workspace"
  })

  local packages = presets.moon.parse(result.stdout)

  assert_true(#packages == 5, string.format("Expected 5 packages, got %d", #packages))

  local names = {}
  for _, pkg in ipairs(packages) do
    names[pkg.name] = true
  end

  assert_true(names["lib-a"], "Should have lib-a")
  assert_true(names["lib-b"], "Should have lib-b")
  assert_true(names["lib-c"], "Should have lib-c")
  assert_true(names["app-1"], "Should have app-1")
  assert_true(names["app-2"], "Should have app-2")
end)

-- Print summary
print("\n" .. string.rep("=", 50))
print(string.format("Tests run: %d", tests_run))
print(string.format("Tests passed: %d", tests_passed))
print(string.format("Tests failed: %d", tests_failed))
print(string.rep("=", 50))

if tests_failed > 0 then
  os.exit(1)
else
  os.exit(0)
end
