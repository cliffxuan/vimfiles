local utils = require 'utils'
local function search_word_under_cursor()
  require('telescope.builtin').grep_string { search = vim.fn.expand '<cword>' }
end

local function search_highlighted_text()
  require('telescope.builtin').grep_string { search = utils.get_highlighted_text(), use_regex = true }
end

local function search_word_under_cursor_in_current_file()
  local current_word = vim.fn.expand '<cword>'
  vim.cmd('Lines ' .. current_word)
end

local function search_visual_selection()
  -- Get the visually selected text and escape it
  local text = utils.get_visual_selection()
  text = vim.fn.escape(text, '?\\.*$^~[')
  -- Replace whitespace sequences with a pattern matching any whitespace
  text = text:gsub('%s+', '\\_s\\+')
  require('telescope.builtin').grep_string { search = text, use_regex = true }
end

local function find_in_subdirectory()
  local telescope = require 'telescope.builtin'
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local pickers = require 'telescope.pickers'

  local find_command = { 'fd', '--type', 'd', '.', vim.fn.getcwd() }

  pickers
    .new({}, {
      prompt_title = 'Select Directory',
      finder = finders.new_oneshot_job(find_command, {}),
      sorter = conf.generic_sorter {},
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          if selection == nil then
            return
          end

          actions.close(prompt_bufnr)

          local dir_path = selection.value
          telescope.find_files {
            prompt_title = 'Find Files in ' .. dir_path,
            cwd = dir_path,
            initial_mode = 'normal',
          }
        end)
        return true
      end,
    })
    :find()
end

local keymap = vim.keymap.set
keymap('n', '-', function()
  local MiniFiles = require 'mini.files'
  if vim.bo.filetype == 'minifiles' then
    MiniFiles.go_out()
  else
    MiniFiles.open(vim.fn.expand '%:p:h', false)
  end
end, { noremap = true, silent = true })
keymap('n', 's', '<Plug>(easymotion-overwin-f2)')
keymap({ 'o', 'x' }, 's', '<Plug>(easymotion-f2)')

-- Hide window
keymap('n', 'K', ':hide<CR>', { noremap = true })

-- leader
require('which-key').add {
  { '<leader>a', group = 'Text Search' },
  { '<leader>d', group = 'Gpt' },
  { '<leader>u', group = 'Display Settings' },
  { '<leader>e', group = 'Edit' },
  { '<leader>g', group = 'Git' },
  { '<leader>k', group = 'Change directory' },
  { '<leader>h', group = 'History' },
}

keymap('n', '<leader>aa', search_word_under_cursor, { desc = 'Search word under the cursor', noremap = true })
keymap('n', '<leader>a ', require('telescope.builtin').live_grep, { desc = 'Live search', noremap = true })
keymap('n', '<leader>as', search_highlighted_text, { desc = 'Search highlighted text', noremap = true })
keymap(
  'n',
  '<leader>al',
  search_word_under_cursor_in_current_file,
  { desc = 'Search word under the cursor in current file', noremap = true }
)
keymap('n', '<leader>ag', ':Rg ', { desc = 'Search with Rg', noremap = true })
keymap('n', '<leader>aj', function()
  require('trouble').toggle 'lsp_references'
end, { desc = 'Search references', noremap = true })
keymap({ 'n', 'v' }, '<leader>av', search_visual_selection, { desc = 'Search visual selection', noremap = true })

keymap('n', '<leader>b', ':Telescope buffers<cr>', { desc = 'Search buffers', noremap = true })

keymap(
  'n',
  '<leader>kj',
  ':exec "cd " .. GuessProjectRoot() <bar> :pwd<cr>',
  { desc = 'cd into the project root', noremap = true }
)
keymap(
  'n',
  '<leader>kk',
  ':exec "cd " .. expand("%:h") <bar> :pwd<cr>',
  { desc = 'cd into the directory of the current file', noremap = true }
)
keymap(
  'n',
  '<leader>kl',
  ':exec  "cd " . join([getcwd(), ".."], "/")  <bar> :pwd<cr>',
  { desc = 'cd into parent directory', noremap = true }
)
keymap(
  'n',
  '<leader>k ',
  ":call fzf#run(fzf#wrap({'sink': 'cd', 'source': 'fd . -t d '}))<cr>",
  { desc = 'choose working direcotry', noremap = true }
)
keymap('n', '<leader>cp', ':echo getcwd()<cr>', { desc = 'echo current directory', noremap = true })

keymap('n', '<leader>d ', ':GptWindowToggle<cr>', { noremap = true })
-- keymap('n', '<leader>dd', ':Gpt ', { noremap = true })
-- keymap('v', '<leader>dd', ':<C-U>GptVisual ', { noremap = true })
keymap('n', '<leader>dd', ':GptInput<cr>', { noremap = true })
keymap('v', '<leader>dd', ':<C-U>GptInputVisual<cr>', { noremap = true })
keymap('n', '<leader>dk', ':GptCode ', { noremap = true })
keymap('v', '<leader>dk', ':<C-U>GptCodeVisual ', { noremap = true })
keymap('n', '<leader>dm', ':GptGitCommitMsg<cr>', { noremap = true })
keymap('n', '<leader>dM', ':GptGitDiffSummary<cr>', { noremap = true })
keymap('n', '<leader>dj', ':GptWindowOpen<cr>', { noremap = true })

keymap('n', '<leader>eb', ':botright new<cr>', { noremap = true })
keymap('n', '<leader>ee', '<cmd>lua vim.diagnostic.setloclist()<CR>', { noremap = true })
keymap('n', '<leader>ek', ':call OpenKeymaps()<cr>', { noremap = true })
keymap('n', '<leader>ep', ':call OpenPlugins()<cr>', { noremap = true })
keymap('n', '<leader>er', ':call OpenVimRC()<cr>', { noremap = true })
keymap('n', '<leader>es', ':source $MYVIMRC<cr>', { noremap = true })
keymap('n', '<leader>et', ':tabnew<cr>', { noremap = true })
keymap('n', '<leader>eu', ':UltiSnipsEdit<cr>', { noremap = true })
keymap('n', '<leader>ev', ':Vexplore<cr>', { noremap = true })
keymap('n', '<leader>en', ':vnew<cr>', { noremap = true })
keymap('n', '<leader>ex', [[:%s/\s\+$//<CR>:let @/=''<CR>]], { noremap = true })

keymap('n', '<leader>f', ':Telescope find_files<cr>', { noremap = true })

keymap('n', '<leader>ga', ':Git add %<cr>', { noremap = true })
keymap('n', '<leader>gb', ':Git blame<cr>', { noremap = true })
keymap('n', '<leader>gc', ':Git commit<cr>', { noremap = true })
keymap('n', '<leader>gd', ':SignifyHunkDiff<cr>', { noremap = true })
keymap('n', '<leader>gf', ':GFiles?<cr>', { noremap = true })
keymap('n', '<leader>gg', ':Git<cr>', { noremap = true })
keymap('n', '<leader>gh', ':GBrowse<cr>', { noremap = true })
keymap('v', '<leader>gh', ':GBrowse<cr>', { noremap = true })
keymap('n', '<leader>gl', ':Commits<cr>', { noremap = true })
keymap('v', '<leader>gl', function()
  require('telescope.builtin').git_bcommits_range()
end, { noremap = true })
keymap('n', '<leader>gm', ':GitMessenger<cr>', { noremap = true })
keymap('n', '<leader>go', ':BCommits<cr>', { noremap = true })
keymap('n', '<leader>gp', ':Git push<cr>', { noremap = true })
keymap('n', '<leader>gr', ':Gread<cr>', { noremap = true })
keymap('n', '<leader>gs', ':Telescope git_status<cr>', { noremap = true })
keymap('n', '<leader>gu', ':SignifyHunkUndo<cr>', { noremap = true })
keymap('n', '<leader>gv', ':Gvdiff<cr>', { noremap = true })
keymap('n', '<leader>gw', ':Gwrite<cr>', { noremap = true })
keymap('n', '<leader>gj', '<plug>(signify-next-hunk)', { noremap = true, silent = true })
keymap('n', '<leader>gk', '<plug>(signify-prev-hunk)', { noremap = true, silent = true })

keymap('n', '<leader>hh', require('telescope.builtin').oldfiles, { noremap = true })
keymap('n', '<leader>hs', require('telescope.builtin').search_history, { noremap = true })
keymap('n', '<leader>hc', require('telescope.builtin').command_history, { noremap = true })

keymap('n', '<leader>jj', function()
  require('telescope.builtin').find_files {
    cwd = vim.fn.expand '%:p:h',
    initial_mode = 'normal',
    preview_title = vim.fn.expand '%:p:h',
  }
end, { noremap = true, desc = 'open the directory of current file' })

keymap(
  'n',
  '<leader>j ',
  find_in_subdirectory,
  { noremap = true, silent = true, desc = 'open file in chosen sub directory' }
)

keymap('n', '<leader><leader>d', ':bwipeout<CR>', { noremap = true })
keymap('n', '<leader><leader>D', ':call DeleteOtherBuffers()<CR>', { noremap = true })
keymap('n', '<leader><leader>j', '<Plug>(easymotion-j)', { noremap = true })
keymap('n', '<leader><leader>k', '<Plug>(easymotion-k)', { noremap = true })

keymap('n', '<leader>l', ':Trouble diagnostics toggle filter.buf=0 focus=true<CR>', { noremap = true, silent = true })
keymap('n', '<leader>m', ':Marks<CR>', { noremap = true })
keymap('n', '<leader>o', ':WhichKey<CR>', { noremap = true })
keymap('n', '<leader>p', '"+p', { noremap = true })
keymap('n', '<leader>q', ':bdelete<CR>', { noremap = true })
keymap('n', '<leader>r', '<Plug>RunCurrentBuffer', { noremap = true })
keymap('n', '<leader>s', ':Snippets<CR>', { noremap = true })
keymap('n', '<leader>t', ':FloatermToggle<CR>', { noremap = true })

keymap('n', '<leader>u ', ':call NumberAndListToggle()<cr>', { desc = 'Toggle number and list', noremap = true })
keymap('n', '<leader>un', ':call NumberToggle()<cr>', { desc = 'Toggle number', noremap = true })
keymap('n', '<leader>uo', ':TagbarToggle<cr>', { desc = 'Toggle tag bar', noremap = true })
keymap('n', '<leader>uj', ':call CycleColor(1, g:eliteColors)<cr>', { desc = 'next colorscheme', noremap = true })
keymap('n', '<leader>uk', ':call CycleColor(-1, g:eliteColors)<cr>', { desc = 'prev colorscheme', noremap = true })
keymap('n', '<leader>ur', ':call SetRandomColor()<cr>', { desc = 'random colorscheme', noremap = true })
keymap('n', '<leader>up', ':colorscheme<cr>', { desc = 'show colorscheme', noremap = true })
keymap('n', '<leader>uu', ':Telescope commands<cr>', { desc = 'Telescope command', noremap = true })

keymap('n', '<leader>v', ':vsp<CR>', { noremap = true })
keymap('n', '<leader>w', ':w<CR>', { noremap = true })
keymap('n', '<leader>x', ':ALEFix<CR>', { noremap = true })
keymap('n', '<leader>y', [[:call CopyFileName()<CR>]], { noremap = true })
keymap('v', '<leader>y', '"+y', { noremap = true })
keymap({ 'n', 'v' }, '<leader>z', 'za', { noremap = true })
keymap('n', 'j', ':<C-U>call Down(v:count)<CR>', { silent = true })
keymap('v', 'j', 'gj', { silent = true })
keymap('n', 'k', ':<C-U>call Up(v:count)<CR>', { silent = true })
keymap('v', 'k', 'gk', { silent = true })
keymap('n', '<Tab>', ':bnext<CR>', {})
keymap('n', '<S-Tab>', ':bprevious<CR>', {})
keymap('n', '<C-k>', '<Plug>(ale_previous_wrap)', { silent = true })
keymap('n', '<C-j>', '<Plug>(ale_next_wrap)', { silent = true })

keymap('i', '<c-x><c-k>', function()
  return vim.fn['fzf#vim#complete#word'] { window = { width = 0.2, height = 0.9, xoffset = 1 } }
end, { expr = true })
keymap('i', '<c-x><c-f>', '<plug>(fzf-complete-path)', {})
keymap('i', '<c-x><c-l>', '<plug>(fzf-complete-line)', {})
keymap('t', '<c-j>', '<c-\\><c-n>', { noremap = true })
keymap('n', '<c-/>', ':FloatermToggle<cr>', { noremap = true })
keymap('t', '<c-/>', '<c-\\><c-n>:hide<cr>', { noremap = true })
keymap('n', '<c-_>', ':FloatermToggle<cr>', { noremap = true }) -- same as <c-/> in tmux
keymap('t', '<c-_>', '<c-\\><c-n>:hide<cr>', { noremap = true }) -- same as <c-/> in tmux
