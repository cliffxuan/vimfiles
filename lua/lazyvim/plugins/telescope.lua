local actions = require('telescope.actions')

return {
    'nvim-telescope/telescope.nvim',
    dependencies = { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    config = function()
        require('telescope').setup {
        extensions = {
            fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
            case_mode = 'smart_case',
            },
        },
        pickers = {
            buffers = {
                mappings = {
                    n = {['dd'] = actions.delete_buffers,}
                }
            }
        }
        }
        require('telescope').load_extension 'fzf'
        vim.cmd 'autocmd User TelescopePreviewerLoaded setlocal number'
    end,
}