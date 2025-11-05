#!/bin/bash

# Test script for autoscope.nvim presets
# This script tests that the workspace tools produce output in the expected format

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

test_case() {
  local name="$1"
  TESTS_RUN=$((TESTS_RUN + 1))
  printf "%-60s" "Test: $name"
}

pass() {
  echo -e "${GREEN}✓ PASS${NC}"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
  echo -e "${RED}✗ FAIL${NC}"
  echo "  Error: $1"
  TESTS_FAILED=$((TESTS_FAILED + 1))
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local message="$3"

  if [ "$actual" = "$expected" ]; then
    return 0
  else
    echo "$message"
    echo "  Expected: $expected"
    echo "  Actual: $actual"
    return 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  if echo "$haystack" | grep -q "$needle"; then
    return 0
  else
    echo "$message"
    echo "  Expected to find: $needle"
    return 1
  fi
}

print_header() {
  echo ""
  echo "================================================================================"
  echo "$1"
  echo "================================================================================"
  echo ""
}

print_header "autoscope.nvim Preset Tests"

# PNPM Tests
print_header "--- PNPM Preset Tests ---"

test_case "pnpm: workspace file exists"
if [ -f "$FIXTURES_DIR/pnpm-workspace/pnpm-workspace.yaml" ]; then
  pass
else
  fail "pnpm-workspace.yaml not found"
fi

test_case "pnpm: command produces JSON output"
output=$(cd "$FIXTURES_DIR/pnpm-workspace" && pnpm ls --recursive --depth=-1 --json 2>/dev/null)
if echo "$output" | jq -e . > /dev/null 2>&1; then
  pass
else
  fail "Output is not valid JSON"
fi

test_case "pnpm: output contains 6 packages (5 + root)"
count=$(cd "$FIXTURES_DIR/pnpm-workspace" && pnpm ls --recursive --depth=-1 --json 2>/dev/null | jq 'length')
if [ "$count" = "6" ]; then
  pass
else
  fail "Expected 6 packages (including root), got $count"
fi

test_case "pnpm: packages have 'name' and 'path' fields"
output=$(cd "$FIXTURES_DIR/pnpm-workspace" && pnpm ls --recursive --depth=-1 --json 2>&1)
if echo "$output" | jq -e '.[0] | has("name") and has("path")' > /dev/null 2>&1; then
  pass
else
  fail "Packages missing required fields"
fi

test_case "pnpm: finds @test/lib-a package"
output=$(cd "$FIXTURES_DIR/pnpm-workspace" && pnpm ls --recursive --depth=-1 --json 2>&1)
if echo "$output" | jq -e '.[] | select(.name == "@test/lib-a")' > /dev/null 2>&1; then
  pass
else
  fail "@test/lib-a package not found"
fi

# NPM Tests
print_header "--- NPM Preset Tests ---"

test_case "npm: package.json has workspaces field"
if jq -e '.workspaces' "$FIXTURES_DIR/npm-workspace/package.json" > /dev/null 2>&1; then
  pass
else
  fail "workspaces field not found in package.json"
fi

test_case "npm: command produces JSON output"
output=$(cd "$FIXTURES_DIR/npm-workspace" && npm query ".workspace" --json 2>&1)
if echo "$output" | jq -e . > /dev/null 2>&1; then
  pass
else
  fail "Output is not valid JSON"
fi

test_case "npm: output contains 5 packages"
count=$(cd "$FIXTURES_DIR/npm-workspace" && npm query ".workspace" --json 2>&1 | jq 'length')
if [ "$count" = "5" ]; then
  pass
else
  fail "Expected 5 packages, got $count"
fi

test_case "npm: packages have 'name' and 'path' fields"
output=$(cd "$FIXTURES_DIR/npm-workspace" && npm query ".workspace" --json 2>&1)
if echo "$output" | jq -e '.[0] | has("name") and (has("path") or has("realpath"))' > /dev/null 2>&1; then
  pass
else
  fail "Packages missing required fields"
fi

test_case "npm: finds @test/npm-lib-a package"
output=$(cd "$FIXTURES_DIR/npm-workspace" && npm query ".workspace" --json 2>&1)
if echo "$output" | jq -e '.[] | select(.name == "@test/npm-lib-a")' > /dev/null 2>&1; then
  pass
else
  fail "@test/npm-lib-a package not found"
fi

# Yarn Tests
print_header "--- Yarn Preset Tests ---"

test_case "yarn: package.json has workspaces field"
if jq -e '.workspaces' "$FIXTURES_DIR/yarn-workspace/package.json" > /dev/null 2>&1; then
  pass
else
  fail "workspaces field not found in package.json"
fi

test_case "yarn: command produces parseable output"
output=$(cd "$FIXTURES_DIR/yarn-workspace" && COREPACK_ENABLE_STRICT=0 yarn workspaces info 2>&1)
if echo "$output" | grep -q "location"; then
  pass
else
  fail "Output doesn't contain expected 'location' field"
fi

test_case "yarn: output can be parsed as JSON"
json_output=$(cd "$FIXTURES_DIR/yarn-workspace" && COREPACK_ENABLE_STRICT=0 yarn workspaces info 2>&1 | grep -A 1000 '^{' | grep -B 1000 '^}' | head -n -1)
if echo "$json_output}" | jq -e . > /dev/null 2>&1; then
  pass
else
  fail "Cannot extract valid JSON from output"
fi

test_case "yarn: output contains 5 packages"
json_output=$(cd "$FIXTURES_DIR/yarn-workspace" && COREPACK_ENABLE_STRICT=0 yarn workspaces info 2>&1 | grep -A 1000 '^{' | grep -B 1000 '^}' | head -n -1)
count=$(echo "$json_output}" | jq 'length')
if [ "$count" = "5" ]; then
  pass
else
  fail "Expected 5 packages, got $count"
fi

test_case "yarn: packages have 'location' field"
json_output=$(cd "$FIXTURES_DIR/yarn-workspace" && COREPACK_ENABLE_STRICT=0 yarn workspaces info 2>&1 | grep -A 1000 '^{' | grep -B 1000 '^}' | head -n -1)
if echo "$json_output}" | jq -e '.["@test/yarn-lib-a"] | has("location")' > /dev/null 2>&1; then
  pass
else
  fail "Packages missing 'location' field"
fi

test_case "yarn: finds @test/yarn-lib-a package"
json_output=$(cd "$FIXTURES_DIR/yarn-workspace" && COREPACK_ENABLE_STRICT=0 yarn workspaces info 2>&1 | grep -A 1000 '^{' | grep -B 1000 '^}' | head -n -1)
if echo "$json_output}" | jq -e '.["@test/yarn-lib-a"]' > /dev/null 2>&1; then
  pass
else
  fail "@test/yarn-lib-a package not found"
fi

# Moon Tests
print_header "--- Moon Preset Tests ---"

test_case "moon: .moon/workspace.yml exists"
if [ -f "$FIXTURES_DIR/moon-workspace/.moon/workspace.yml" ]; then
  pass
else
  fail ".moon/workspace.yml not found"
fi

test_case "moon: command produces JSON output"
output=$(cd "$FIXTURES_DIR/moon-workspace" && moon query projects --json 2>&1)
if echo "$output" | jq -e . > /dev/null 2>&1; then
  pass
else
  fail "Output is not valid JSON"
fi

test_case "moon: output has 'projects' array"
output=$(cd "$FIXTURES_DIR/moon-workspace" && moon query projects --json 2>&1)
if echo "$output" | jq -e '.projects' > /dev/null 2>&1; then
  pass
else
  fail "Output missing 'projects' array"
fi

test_case "moon: output contains 5 projects"
count=$(cd "$FIXTURES_DIR/moon-workspace" && moon query projects --json 2>&1 | jq '.projects | length')
if [ "$count" = "5" ]; then
  pass
else
  fail "Expected 5 projects, got $count"
fi

test_case "moon: projects have 'id' and 'source' fields"
output=$(cd "$FIXTURES_DIR/moon-workspace" && moon query projects --json 2>&1)
if echo "$output" | jq -e '.projects[0] | has("id") and has("source")' > /dev/null 2>&1; then
  pass
else
  fail "Projects missing required fields"
fi

test_case "moon: finds lib-a project"
output=$(cd "$FIXTURES_DIR/moon-workspace" && moon query projects --json 2>&1)
if echo "$output" | jq -e '.projects[] | select(.id == "lib-a")' > /dev/null 2>&1; then
  pass
else
  fail "lib-a project not found"
fi

# Print summary
echo ""
echo "================================================================================"
echo "Tests run:    $TESTS_RUN"
echo -e "Tests passed: $TESTS_PASSED ${GREEN}✓${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
  echo -e "Tests failed: $TESTS_FAILED ${RED}✗${NC}"
else
  echo -e "Tests failed: $TESTS_FAILED"
fi
echo "================================================================================"
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
  echo -e "${RED}Some tests failed!${NC}"
  exit 1
else
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
fi
