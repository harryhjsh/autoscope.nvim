local previewers = require("telescope.previewers")

local package_header_previewer = previewers.new_buffer_previewer({
  define_preview = function(self, entry, _)
    local lines = {
      "Package: " .. (entry.value.name or "?"),
      "Path:    " .. (entry.path or entry.value.path or "?"),
    }

    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
  end,
})

return package_header_previewer
