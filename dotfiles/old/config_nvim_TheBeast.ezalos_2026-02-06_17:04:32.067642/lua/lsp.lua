-- LSP configuration

local lspconfig = require("lspconfig")
local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- Python LSP
lspconfig.pylsp.setup({
  capabilities = capabilities,
  settings = {
    pylsp = {
      plugins = {
        flake8 = {
          enabled = true,
        },
      },
    },
  },
})

-- C/C++ LSP
lspconfig.clangd.setup({
  capabilities = capabilities,
})

-- JavaScript/TypeScript LSP
lspconfig.tsserver.setup({
  capabilities = capabilities,
})

-- Lua LSP
lspconfig.lua_ls.setup({
  capabilities = capabilities,
  settings = {
    Lua = {
      diagnostics = {
        globals = { "vim" },
      },
    },
  },
})
