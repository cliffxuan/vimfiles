local utils = require 'utils'
local telescope = require 'telescope.builtin'
local Notify = require 'mini.notify'

local search_word_under_cursor = function()
  telescope.grep_string { search = vim.fn.expand '<cword>', initial_mode = 'normal' }
end

local search_highlighted_text = function()
  telescope.grep_string {
    search = utils.get_highlighted_text(),
    use_regex = true,
    initial_mode = 'normal',
  }
end

local search_word_in_current_file = function(default_text, initial_mode, fuzzy)
  if fuzzy == nil then
    fuzzy = false
  end
  telescope.current_buffer_fuzzy_find {
    prompt_title = 'Search in ' .. vim.api.nvim_buf_get_name(0),
    sorting_strategy = 'ascending',
    -- Sort by line number by giving it higher score
    tiebreak = function(entry1, entry2)
      return entry1.lnum < entry2.lnum
    end,
    initial_mode = initial_mode or 'insert',
    default_text = default_text or '',
    fuzzy = fuzzy,
  }
end

local search_visual_selection = function()
  -- Get the visually selected text and escape it
  local text = utils.get_visual_selection()
  text = vim.fn.escape(text, '?\\.*$^~[')
  -- Replace whitespace sequences with a pattern matching any whitespace
  text = text:gsub('%s+', '\\_s\\+')
  telescope.grep_string { search = text, use_regex = true, initial_mode = 'normal' }
end

local pick_directory = function(callback, finder_command)
  if not finder_command then
    finder_command = 'fd --type d --hidden --max-depth 3 --exclude .git . ' .. vim.fn.getcwd()
  end
  local actions = require 'telescope.actions'

  require('telescope.pickers')
    .new({}, {
      prompt_title = 'Select Directory',
      finder = require('telescope.finders').new_oneshot_job(utils.split(finder_command), {}),
      sorter = require('telescope.config').values.generic_sorter {},
      initial_mode = 'normal',
      previewer = require('telescope.previewers').new_termopen_previewer {
        get_command = function(entry)
          return utils.split('tree -L 2 -I *.pyc -I __pycache__ -I .git ' .. entry.value) -- TODO more generic
        end,
      },
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = require('telescope.actions.state').get_selected_entry()
          if selection == nil then
            return
          end

          actions.close(prompt_bufnr)
          callback(selection.value)
        end)
        return true
      end,
    })
    :find()
end

local find_files = function(dir_path)
  telescope.find_files {
    prompt_title = 'Find Files in ' .. dir_path,
    find_command = utils.split 'rg --files --color never --glob !*.pyc --glob !*.pyo --glob !*.pyd',
    cwd = dir_path,
    initial_mode = 'normal',
  }
end

local open_file_in_buffer_dir = function()
  local cwd = vim.fn.expand '%:p:h'
  telescope.find_files {
    cwd = cwd,
    initial_mode = 'normal',
    prompt_title = 'Find files in ' .. cwd,
  }
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
  { '<leader>j', group = 'Open file' },
  { '<leader>u', group = 'Display settings' },
  { '<leader>e', group = 'Edit' },
  { '<leader>g', group = 'Git' },
  { '<leader>k', group = 'Change directory' },
  { '<leader>h', group = 'History' },
}

keymap('n', '<leader>aa', search_word_under_cursor, { desc = 'Search word under the cursor', noremap = true })
keymap('n', '<leader>a ', telescope.live_grep, { desc = 'Live search', noremap = true })
keymap('n', '<leader>ab', function()
  telescope.live_grep {
    grep_open_files = true,
    default_text = vim.fn.expand '<cword>',
    prompt_title = 'Live Grep in Open Buffers',
    initial_mode = 'normal',
  }
end, { desc = 'Live grep in open buffers', noremap = true })
keymap('n', '<leader>as', search_highlighted_text, { desc = 'Search highlighted text', noremap = true })
keymap('n', '<leader>af', search_word_in_current_file, { desc = 'Search in current buffer', noremap = true })
keymap('n', '<leader>al', function()
  search_word_in_current_file(vim.fn.expand '<cword>', 'normal')
end, { desc = 'Search word under the cursor in current file', noremap = true })
keymap('n', '<leader>ag', ':Rg ', { desc = 'Search with Rg', noremap = true })
keymap('n', '<leader>aj', function()
  require('trouble').toggle 'lsp_references'
end, { desc = 'Search references', noremap = true })
keymap({ 'n', 'v' }, '<leader>av', search_visual_selection, { desc = 'Search visual selection', noremap = true })

keymap('n', '<leader>b', function()
  telescope.buffers {
    initial_mode = 'normal',
  }
end, { desc = 'Search buffers', noremap = true })

keymap('n', '<leader>d ', ':GptWindowToggle<cr>', { noremap = true })
-- keymap('n', '<leader>dd', ':Gpt ', { noremap = true })
-- keymap('v', '<leader>dd', ':<C-U>GptVisual ', { noremap = true })
keymap('n', '<leader>da', ':AvanteToggle<cr>', { noremap = true, desc = 'Toggle Avante' })
keymap('n', '<leader>db', ':GptInputBuffer<cr>', { noremap = true, desc = 'Input for Gpt with buffer as context' })
keymap('n', '<leader>dd', ':GptInput<cr>', { noremap = true, desc = 'Input for Gpt' })
keymap('v', '<leader>dd', ':<C-U>GptInputVisual<cr>', { noremap = true, desc = 'Input for Gpt in visual mode' })
keymap('n', '<leader>df', ':AvanteFocus<cr>', { noremap = true, desc = 'Toggle Avante Focus' })
keymap('n', '<leader>dk', ':GptCode ', { noremap = true, desc = 'Generate code with Gpt' })
keymap('v', '<leader>dk', ':<C-U>GptCodeVisual ', { noremap = true, desc = 'Generate code with Gpt in visual mode' })
keymap('n', '<leader>dm', ':GptGitCommitMsg<cr>', { noremap = true, desc = 'Get commit message from Gpt' })
keymap('n', '<leader>dM', ':GptGitDiffSummary<cr>', { noremap = true, desc = 'Get diff summary from Gpt' })
keymap('n', '<leader>dj', ':GptWindowOpen<cr>', { noremap = true, desc = 'Open Gpt window' })

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

keymap('n', '<leader>f', function()
  telescope.find_files {
    prompt_title = 'Find files in ' .. vim.fn.getcwd(),
  }
end, { noremap = true, desc = 'open file in workdir' })

keymap('n', '<leader>ga', function()
  vim.cmd('cd' .. utils.guess_project_root '.git')
  vim.cmd [[
    pwd
    Git add %
    Git status
  ]]
end, { noremap = true, desc = 'Git add current file' })
keymap('n', '<leader>gA', function()
  vim.cmd('cd' .. utils.guess_project_root '.git')
  vim.cmd [[
    pwd
    Git add .
    Git status
  ]]
end, { noremap = true, desc = 'Git add all files' })
keymap('n', '<leader>gb', ':Git blame<cr>', { noremap = true, desc = 'Show Git blame' })
keymap('n', '<leader>gc', ':Git commit<cr>', { noremap = true, desc = 'Git commit' })
keymap(
  'n',
  '<leader>gC',
  ':Git commit <bar> :GptGitCommitMsg<cr>',
  { noremap = true, desc = 'Git commit with Gpt message' }
)
keymap('n', '<leader>gd', ':SignifyHunkDiff<cr>', { noremap = true, desc = 'Show Git hunk diff' })
keymap('n', '<leader>gf', ':GFiles?<cr>', { noremap = true, desc = 'Find Git files' })
keymap('n', '<leader>gg', ':Git<cr>', { noremap = true, desc = 'Open Git status' })
keymap('n', '<leader>gl', ':Commits<cr>', { noremap = true, desc = 'Show Git commits' })
keymap('n', '<leader>gm', ':GitMessenger<cr>', { noremap = true, desc = 'Show Git messages' })
keymap('n', '<leader>go', ':BCommits<cr>', { noremap = true, desc = 'Show buffer commits' })
keymap('n', '<leader>gp', ':Git push<cr>', { noremap = true, desc = 'Push to Git' })
keymap('n', '<leader>gr', ':Gread<cr>', { noremap = true, desc = 'Read from Git' })
keymap('n', '<leader>gs', function()
  telescope.git_status {
    initial_mode = 'normal',
    cwd = vim.fn.expand '%:p:h',
  }
end, { noremap = true, desc = 'Git status' })
keymap('n', '<leader>gu', ':SignifyHunkUndo<cr>', { noremap = true, desc = 'Undo Git hunk' })
keymap('n', '<leader>gv', ':Gvdiff<cr>', { noremap = true, desc = 'Show Git diff' })
keymap('n', '<leader>gw', ':Gwrite<cr>', { noremap = true, desc = 'Write to Git' })
keymap('n', '<leader>gj', '<plug>(signify-next-hunk)', { noremap = true, desc = 'Next Git hunk' })
keymap('n', '<leader>gk', '<plug>(signify-prev-hunk)', { noremap = true, desc = 'Previous Git hunk' })

keymap('n', '<leader>hh', telescope.oldfiles, { noremap = true, desc = 'Show old files' })
keymap('n', '<leader>hs', telescope.search_history, { noremap = true, desc = 'Show search history' })
keymap('n', '<leader>hc', telescope.command_history, { noremap = true, desc = 'Show command history' })

keymap('n', '<leader>jf', function()
  pick_directory(find_files, 'zoxide query --list')
end, { noremap = true, desc = 'open file in a z directory' })
keymap('n', '<leader>jj', function()
  local cwd = utils.guess_project_root()
  telescope.find_files {
    cwd = cwd,
    initial_mode = 'normal',
    prompt_title = 'Find files in ' .. cwd,
  }
end, { noremap = true, desc = 'open file in project root' })
keymap('n', '<leader>jk', open_file_in_buffer_dir, { noremap = true, desc = 'open file in the same directory' })
keymap('n', '<leader>j ', open_file_in_buffer_dir, { noremap = true, desc = 'open file in the same directory' })
keymap('n', '<leader>jh', function()
  local cwd = vim.fn.expand '%:p:h:h'
  telescope.find_files {
    cwd = cwd,
    initial_mode = 'normal',
    prompt_title = 'Find files in ' .. cwd,
  }
end, { noremap = true, desc = 'open file in parent directory' })

keymap('n', '<leader>jl', function()
  pick_directory(find_files)
end, { noremap = true, silent = true, desc = 'open file in chosen sub directory' })

keymap('n', '<leader>kl', function()
  pick_directory(function(dir_path)
    vim.fn.chdir(dir_path)
    local nid = Notify.add('pwd: ' .. dir_path)
    vim.defer_fn(function()
      Notify.remove(nid)
    end, 2000)
  end)
end, { desc = 'cd into a subdirectory', noremap = true })
keymap('n', '<leader>kf', function()
  pick_directory(vim.fn.chdir, 'zoxide query --list')
end, { noremap = true, desc = 'cd into a z directory' })
keymap('n', '<leader>kp', ':echo getcwd()<cr>', { desc = 'echo current directory', noremap = true })
keymap('n', '<leader>kj', function()
  vim.fn.chdir(utils.guess_project_root())
  vim.print('pwd: ' .. vim.fn.getcwd())
end, { desc = 'cd into the project root', noremap = true })
keymap(
  'n',
  '<leader>k~',
  ':exec "cd " .. expand("~") <bar> :pwd<cr>',
  { desc = 'cd into home directory', noremap = true }
)
keymap(
  'n',
  '<leader>kk',
  ':exec "cd " .. expand("%:h") <bar> :pwd<cr>',
  { desc = 'cd into the directory of the current file', noremap = true }
)
keymap(
  'n',
  '<leader>kh',
  ':exec  "cd " . join([getcwd(), ".."], "/")  <bar> :pwd<cr>',
  { desc = 'cd into parent directory', noremap = true }
)
keymap('n', '<leader>k/', ':exec  "cd /"  <bar> :pwd<cr>', { desc = 'cd into /', noremap = true })

keymap('n', '<leader><leader>d', ':bwipeout<CR>', { noremap = true })
keymap('n', '<leader><leader>D', ':call DeleteOtherBuffers()<CR>', { noremap = true })
keymap('n', '<leader><leader>j', '<Plug>(easymotion-j)', { noremap = true })
keymap('n', '<leader><leader>k', '<Plug>(easymotion-k)', { noremap = true })

keymap('n', '<leader>l', ':Trouble diagnostics toggle filter.buf=0 focus=true<CR>', { noremap = true, silent = true })
keymap('n', '<leader>m', ':Marks<CR>', { noremap = true })
keymap('n', '<leader>o', ':WhichKey<CR>', { noremap = true })
keymap('n', '<leader>p', '"*p', { noremap = true })
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
keymap('v', '<leader>y', '"*y', { noremap = true })
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
