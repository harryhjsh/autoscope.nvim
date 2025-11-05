# autoscope.nvim Tests

This directory contains tests for the autoscope.nvim workspace detection presets.

## Test Structure

```
tests/
├── fixtures/              # Test monorepo fixtures
│   ├── pnpm-workspace/    # pnpm test workspace (6 packages)
│   ├── npm-workspace/     # npm test workspace (5 packages)
│   ├── yarn-workspace/    # yarn classic test workspace (5 packages)
│   └── moon-workspace/    # moonrepo test workspace (5 projects)
├── test_presets.sh        # Main test suite (Bash)
├── test_presets_nvim.lua  # Neovim-based tests (requires nvim with Lua)
├── run_tests.sh           # Test runner for Neovim tests
└── README.md              # This file
```

## Running Tests

### Bash Test Suite (Recommended)

The bash test suite tests the actual workspace tools and validates their output format:

```bash
./tests/test_presets.sh
```

**Requirements:**
- bash
- jq (for JSON parsing)
- pnpm, npm, yarn, moon (the tools being tested)

### Neovim Test Suite

If you have Neovim with Lua support:

```bash
./tests/run_tests.sh
```

**Requirements:**
- nvim with Lua support
- pnpm, npm, yarn, moon

## Test Fixtures

Each fixture is a real monorepo initialized with the respective tool:

### pnpm-workspace
- 3 library packages: `@test/lib-a`, `@test/lib-b`, `@test/lib-c`
- 2 app packages: `@test/app-1`, `@test/app-2`
- 1 root package (workspace root)
- Total: 6 packages

### npm-workspace
- 3 library packages: `@test/npm-lib-a`, `@test/npm-lib-b`, `@test/npm-lib-c`
- 2 app packages: `@test/npm-app-1`, `@test/npm-app-2`
- Total: 5 packages

### yarn-workspace
- 3 library packages: `@test/yarn-lib-a`, `@test/yarn-lib-b`, `@test/yarn-lib-c`
- 2 app packages: `@test/yarn-app-1`, `@test/yarn-app-2`
- Total: 5 packages
- Note: Uses Yarn Classic (v1)

### moon-workspace
- 3 library projects: `lib-a`, `lib-b`, `lib-c`
- 2 application projects: `app-1`, `app-2`
- Total: 5 projects

## What's Being Tested

For each preset, the tests verify:

1. **Detection**: The preset correctly detects its workspace configuration files
2. **Command Output**: The tool command produces valid JSON output
3. **Package Count**: The expected number of packages/projects are returned
4. **Required Fields**: Packages have the required `name` and `path`/`location`/`source` fields
5. **Specific Packages**: Known packages can be found in the output

## Test Philosophy

These tests use **real workspace tools** rather than mocking them. This ensures:

- The presets work with actual tool output
- Changes in tool behavior are caught
- Output format assumptions are validated
- Integration issues are detected early

## Adding New Tests

To add tests for a new preset:

1. Create a fixture directory under `tests/fixtures/`
2. Initialize it with the workspace tool
3. Add test cases to `test_presets.sh` following the existing pattern
4. Run tests to verify

## Continuous Integration

These tests are designed to run in CI environments where the workspace tools are available. Ensure your CI has:

```bash
npm install -g pnpm
npm install -g @moonrepo/cli
# yarn is typically bundled with node
```
