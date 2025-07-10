-- Introduce a new filetype for koka
vim.filetype.add {
  extension = {
    kk = 'koka',
  },
}

vim.treesitter.language.register('koka', 'koka')
