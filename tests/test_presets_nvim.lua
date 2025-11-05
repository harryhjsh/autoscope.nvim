-- Test runner for autoscope.nvim presets
-- Run with: nvim --headless --noplugin -u NONE -c "set runtimepath+=." -c "luafile tests/test_presets_nvim.lua" -c "qa!"

local tests_run = 0
local tests_passed = 0
local tests_failed = 0

local function test(name, fn)
  tests_run = tests_run + 1
  io.write(string.format("Test: %-50s ", name))
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

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s\nExpected: %s\nActual: %s",
      message or "Assertion failed",
      vim.inspect(expected),
      vim.inspect(actual)
    ))
  end
end

local function assert_true(value, message)
  if not value then
    error(message or "Expected true, got false")
  end
end

-- Load the presets module
local presets = require("autoscope.default_presets")

-- Test fixtures directory
local script_path = debug.getinfo(1, "S").source:sub(2)
local test_dir = vim.fn.fnamemodify(script_path, ":h")
local fixtures_dir = test_dir .. "/fixtures/"

print("\n" .. string.rep("=", 80))
print("autoscope.nvim Preset Tests")
print(string.rep("=", 80) .. "\n")

-- Helper to run preset command
local function run_preset_cmd(preset, cwd)
  local result = vim.system(preset.cmd, {
    text = true,
    cwd = cwd
  }):wait()

  if result.code ~= 0 then
    error(string.format("Command failed with code %d: %s", result.code, result.stderr or ""))
  end

  return result.stdout
end

-- PNPM Tests
print("\n--- PNPM Preset Tests ---\n")

test("pnpm: detects workspace", function()
  local old_cwd = vim.fn.getcwd()
  vim.fn.chdir(fixtures_dir .. "pnpm-workspace")

  local detected = presets.pnpm.detect()
  vim.fn.chdir(old_cwd)

  assert_true(detected, "pnpm workspace should be detected")
end)

test("pnpm: lists all 5 packages", function()
  local output = run_preset_cmd(presets.pnpm, fixtures_dir .. "pnpm-workspace")
  local packages = presets.pnpm.parse(output)

  assert_eq(#packages, 5, string.format("Expected 5 packages, got %d", #packages))
end)

test("pnpm: finds expected package names", function()
  local output = run_preset_cmd(presets.pnpm, fixtures_dir .. "pnpm-workspace")
  local packages = presets.pnpm.parse(output)

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

test("pnpm: packages have absolute paths", function()
  local output = run_preset_cmd(presets.pnpm, fixtures_dir .. "pnpm-workspace")
  local packages = presets.pnpm.parse(output)

  for _, pkg in ipairs(packages) do
    assert_true(pkg.path:match("^/"), string.format("Package %s path should be absolute: %s", pkg.name, pkg.path))
  end
end)

-- NPM Tests
print("\n--- NPM Preset Tests ---\n")

test("npm: detects workspace", function()
  local old_cwd = vim.fn.getcwd()
  vim.fn.chdir(fixtures_dir .. "npm-workspace")

  local detected = presets.npm.detect()
  vim.fn.chdir(old_cwd)

  assert_true(detected, "npm workspace should be detected")
end)

test("npm: lists all 5 packages", function()
  local output = run_preset_cmd(presets.npm, fixtures_dir .. "npm-workspace")
  local packages = presets.npm.parse(output)

  assert_eq(#packages, 5, string.format("Expected 5 packages, got %d", #packages))
end)

test("npm: finds expected package names", function()
  local output = run_preset_cmd(presets.npm, fixtures_dir .. "npm-workspace")
  local packages = presets.npm.parse(output)

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

test("npm: packages have absolute paths", function()
  local output = run_preset_cmd(presets.npm, fixtures_dir .. "npm-workspace")
  local packages = presets.npm.parse(output)

  for _, pkg in ipairs(packages) do
    assert_true(pkg.path:match("^/"), string.format("Package %s path should be absolute: %s", pkg.name, pkg.path))
  end
end)

-- Yarn Tests
print("\n--- Yarn Preset Tests ---\n")

test("yarn: detects workspace", function()
  local old_cwd = vim.fn.getcwd()
  vim.fn.chdir(fixtures_dir .. "yarn-workspace")

  local detected = presets.yarn.detect()
  vim.fn.chdir(old_cwd)

  assert_true(detected, "yarn workspace should be detected")
end)

test("yarn: lists all 5 packages", function()
  -- Set environment variable to avoid corepack issues
  local old_env = vim.env.COREPACK_ENABLE_STRICT
  vim.env.COREPACK_ENABLE_STRICT = "0"

  local output = run_preset_cmd(presets.yarn, fixtures_dir .. "yarn-workspace")
  local packages = presets.yarn.parse(output)

  vim.env.COREPACK_ENABLE_STRICT = old_env

  assert_eq(#packages, 5, string.format("Expected 5 packages, got %d", #packages))
end)

test("yarn: finds expected package names", function()
  local old_env = vim.env.COREPACK_ENABLE_STRICT
  vim.env.COREPACK_ENABLE_STRICT = "0"

  local output = run_preset_cmd(presets.yarn, fixtures_dir .. "yarn-workspace")
  local packages = presets.yarn.parse(output)

  vim.env.COREPACK_ENABLE_STRICT = old_env

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

test("yarn: packages have absolute paths", function()
  local old_env = vim.env.COREPACK_ENABLE_STRICT
  vim.env.COREPACK_ENABLE_STRICT = "0"

  local output = run_preset_cmd(presets.yarn, fixtures_dir .. "yarn-workspace")
  local packages = presets.yarn.parse(output)

  vim.env.COREPACK_ENABLE_STRICT = old_env

  for _, pkg in ipairs(packages) do
    assert_true(pkg.path:match("^/"), string.format("Package %s path should be absolute: %s", pkg.name, pkg.path))
  end
end)

-- Moon Tests
print("\n--- Moon Preset Tests ---\n")

test("moon: detects workspace", function()
  local old_cwd = vim.fn.getcwd()
  vim.fn.chdir(fixtures_dir .. "moon-workspace")

  local detected = presets.moon.detect()
  vim.fn.chdir(old_cwd)

  assert_true(detected, "moon workspace should be detected")
end)

test("moon: lists all 5 packages", function()
  local output = run_preset_cmd(presets.moon, fixtures_dir .. "moon-workspace")
  local packages = presets.moon.parse(output)

  assert_eq(#packages, 5, string.format("Expected 5 packages, got %d", #packages))
end)

test("moon: finds expected package names", function()
  local output = run_preset_cmd(presets.moon, fixtures_dir .. "moon-workspace")
  local packages = presets.moon.parse(output)

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

test("moon: packages have absolute paths", function()
  local output = run_preset_cmd(presets.moon, fixtures_dir .. "moon-workspace")
  local packages = presets.moon.parse(output)

  for _, pkg in ipairs(packages) do
    assert_true(pkg.path:match("^/"), string.format("Package %s path should be absolute: %s", pkg.name, pkg.path))
  end
end)

-- Print summary
print("\n" .. string.rep("=", 80))
print(string.format("Tests run:    %d", tests_run))
print(string.format("Tests passed: %d ✓", tests_passed))
print(string.format("Tests failed: %d %s", tests_failed, tests_failed > 0 and "✗" or ""))
print(string.rep("=", 80))

if tests_failed > 0 then
  vim.cmd("cq") -- Exit with error code
else
  print("\nAll tests passed! ✓")
end
