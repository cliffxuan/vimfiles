
vim.keymap.set({ 'n', 'x', 'o' }, 'f', '<Plug>(leap-forward)')
vim.keymap.set({ 'n', 'x', 'o' }, 'F', '<Plug>(leap-backward)')
-- leader
vim.keymap.set({ 'n' }, '<leader>aa', ':Rg ', { desc = 'Search with Rg' })

vim.cmd [[
" keymaps {{{
" auto close
inoremap ' ''<left>
inoremap " ""<left>
inoremap ( ()<left>
inoremap [ []<left>
inoremap { {}<left>
augroup disableAutoCloseSingleQuote
  autocmd!
  autocmd FileType TelescopePrompt inoremap <buffer> ' '
  autocmd FileType chatgpt-input inoremap <buffer> ' '
augroup END

" Kill window
nnoremap K :hide<cr>
" leader
" nnoremap <leader>aa :Rg<tab>
nnoremap <leader>as :exec 'Rg ' . substitute(@/, '\\[<>]', '\\b', 'g')<cr>
nnoremap <leader>b <cmd>Telescope buffers<cr>
nnoremap <leader>cc :call NumberAndListToggle()<cr>
nnoremap <leader>cn :call NumberToggle()<cr>
nnoremap <leader>co :TagbarToggle<cr>
nnoremap <leader>cj :call CycleColor(1, g:eliteColors)<cr>
nnoremap <leader>ck :call CycleColor(-1, g:eliteColors)<cr>
nnoremap <leader>cr :call SetRandomColor()<cr>
nnoremap <leader>cp :colorscheme<cr>
" cd into directories
nnoremap <leader>dd :exec "cd " . GuessProjectRoot() <bar> :pwd<cr>
nnoremap <leader>dj :exec "cd %:h"  <bar> :pwd<cr>
nnoremap <leader>dk :exec "cd " . join([getcwd(), ".."], "/")  <bar> :pwd<cr>
nnoremap <leader>df :call fzf#run(fzf#wrap({'sink': 'cd', 'source': 'fd . -t d '}))<cr>
nnoremap <leader>dp :echo getcwd()<cr>
" edit and source $MYVIMRC
noremap <leader>ee <cmd>lua vim.diagnostic.setloclist()<CR>
noremap <leader>ep :UltiSnipsEdit<cr>
noremap <leader>er :call OpenVimRC()<cr>
noremap <leader>es :source $MYVIMRC<cr>
noremap <leader>ev :Vexplore<cr>
noremap <leader>en :vnew<cr>
nnoremap <leader>f <cmd>Telescope find_files<cr>
" g for git related mappings
nnoremap <leader>ga :Git add %<cr>
nnoremap <leader>gd :SignifyHunkDiff<cr>
nnoremap <leader>gg :Git<cr>
nnoremap <leader>gp :Git push<cr>
nnoremap <leader>gb :Git blame<cr>
nnoremap <leader>gc :Git commit<cr>
nnoremap <leader>gf :GFiles?<cr>
nnoremap <leader>gh :GBrowse<cr>
vnoremap <leader>gh :GBrowse<cr>
nnoremap <leader>gl :Commits<cr>
nnoremap <leader>gm :GitMessenger<cr>
nnoremap <leader>go :BCommits<cr>
nnoremap <leader>gr :Gread<cr>
nnoremap <leader>gw :Gwrite<cr>
nnoremap <leader>gu :SignifyHunkUndo<cr>
nnoremap <leader>gv :Gvdiff<cr>
nmap <leader>gj <plug>(signify-next-hunk)
nmap <leader>gk <plug>(signify-prev-hunk)
nmap <leader>gJ 9999<leader>gj
nmap <leader>gK 9999<leader>gk
nnoremap <leader>hh :History<cr>
nnoremap <leader>hs :History/<cr>
nnoremap <leader>hc :History:<cr>
" <leader>i lua/config.lua
map <leader>j <Plug>(easymotion-j)
map <leader>k <Plug>(easymotion-k)
nnoremap <leader><leader>d :bwipeout<cr>
nnoremap <leader><leader>D :call DeleteOtherBuffers()<cr>
map <leader><leader>j <Plug>(easymotion-w)
map <leader><leader>k <Plug>(easymotion-b)
" Toggle the location list window
nnoremap <silent> <leader>l :TroubleToggle<CR>
nnoremap <leader>m :Marks<cr>
" <leader>n lua/config.lua
nnoremap <leader>o :WhichKey<cr>
" toggle relativenumber
nnoremap <leader>p "+p
nnoremap <leader>q :bdelete<cr>
nmap <leader>r <Plug>RunCurrentBuffer
nnoremap <leader>s :Snippets<cr>
nnoremap <leader>t :FloatermToggle<cr>
" Clean trailing whitespace
nnoremap <leader>u mz:%s/\s\+$//<cr>:let @/=''<cr>`z
" Split Open
noremap <leader>v :vsp<cr>
" save
nnoremap <leader>w :w<cr>
" alx-fix
nnoremap <leader>x :ALEFix<cr>

" copy file name
nnoremap <leader>y :call CopyFileName()<cr>
vnoremap <leader>y "+y
noremap <leader>z za
vnoremap <leader>z za

" Search for selected text, forwards or backwards.
vnoremap <silent> * :<C-U>
      \let old_reg=getreg('"')<Bar>let old_regtype=getregtype('"')<cr>
      \gvy/<C-R><C-R>=substitute(
      \escape(@", '/\.*$^~['), '\_s\+', '\\_s\\+', 'g')<cr><cr>
      \gV:call setreg('"', old_reg, old_regtype)<cr>
vnoremap <silent> # :<C-U>
      \let old_reg=getreg('"')<Bar>let old_regtype=getregtype('"')<cr>
      \gvy?<C-R><C-R>=substitute(
      \escape(@", '?\.*$^~['), '\_s\+', '\\_s\\+', 'g')<cr><cr>
      \gV:call setreg('"', old_reg, old_regtype)<cr>

" wrapped lines goes down/up to next row, rather than next line in file.
nnoremap <silent> j :<C-U>call Down(v:count)<cr>
vnoremap <silent> j gj

nnoremap <silent> k :<C-U>call Up(v:count)<cr>
vnoremap <silent> k gk

" Buffer Cycling
nnoremap <Tab> :bnext<cr>
nnoremap <S-Tab> :bprevious<cr>

" ale
nmap <silent> <C-k> <Plug>(ale_previous_wrap)
nmap <silent> <C-j> <Plug>(ale_next_wrap)

" fzf
imap <c-x><c-k> <plug>(fzf-complete-word)
imap <c-x><c-f> <plug>(fzf-complete-path)
imap <c-x><c-j> <plug>(fzf-complete-file-ag)
imap <c-x><c-l> <plug>(fzf-complete-line)
" Advanced customization using autoload functions
inoremap <expr> <c-x><c-k> fzf#vim#complete#word({'left': '15%'})

" terminal
tnoremap <C-j> <C-\><C-n>
augroup nvim_term_insert
  autocmd TermOpen term://* startinsert
augroup END

" }}}
]]
