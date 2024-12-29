return {
  'echasnovski/mini.nvim',
  config = function ()
    require('mini.align').setup()
    require('mini.basics').setup()
    require('mini.cursorword').setup()
    require('mini.files').setup()
    require('mini.jump').setup()
    require('mini.move').setup()
    require('mini.notify').setup()
    require('mini.pairs').setup()
    require('mini.splitjoin').setup()
    require('mini.starter').setup()
    require('mini.tabline').setup()
  end
}
