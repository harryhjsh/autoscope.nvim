#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "Running autoscope.nvim preset tests..."
echo "========================================"

# Run tests with nvim in headless mode
nvim --headless --noplugin -u NONE \
  -c "set runtimepath+=." \
  -c "luafile tests/test_presets_nvim.lua" \
  -c "qa!"
