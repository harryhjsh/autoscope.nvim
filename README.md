# autoscope.nvim

Automatically scope Telescope pickers to workspace package directories without mutating nvim's cwd.

## Installation + Configuration

Use your package manager!

```
harryhjsh/autoscope.nvim
```

For config, check [init.lua](./lua/autoscope/init.lua) until I can be bothered to put something in here to copy-paste. You can configure a few basic options, define your own tool presets, and define the order to check presets in.

Type definitions for configuring additional presets are in [default_presets.lua](./lua/autoscope/default_presets.lua) for now.

## Presets
Presets are descriptions of workspace tools. The name `preset` should probably be changed. They:
* Check whether the current directory is managed by the workspace tool (package manager or other orchestrator)
* Call the tool to get a list of workspace packages

Both of these things happen during `setup()` for all configured tools until one returns some packages.

Current default presets:
* `pnpm` -> detects `pnpm-workspace.yaml` and calls `pnpm ls`
* `npm` -> detects `(package.json).workspaces` and calls `npm query .workspaces`. Running `npm install` seems to be a pre-requisite of new workspace packages appearing in this output.
* with more (`yarn`, `cargo`, `moon`, `nx`) TODO -- or define your own during `setup()`.

## Telescope
Once a list of workspace packages has been gathered, the plugin takes the path of a file and detects which worksace package it's in. You can probably use this for other stuff (including populating `cwd` for your own/other custom pickers), but the built-in functionality is to pass this directory to the `cwd` of some builtin Telescope pickers.

### Wrapped builtin pickers
* `find_files` -> `:Telescope autoscope find_files`
* `git_files` -> `:Telescope autoscope git_files`. This also needs to override what's used as the git root, so there may be other issues around using it.
* `grep_string` -> `:Telescope autoscope grep_string`
* `live_grep` -> `:Telescope autoscope live_grep`

Telescope's builtin picker titles are hardcoded, so the same thing's been done here. This might result in some issues/annoyances.

## Planned
* Telescope picker for all workspace packages

