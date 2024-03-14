local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)
vim.g.mapleader = " "
vim.g.maplocalleader = ","
require("lazy").setup({
	"ConradIrwin/vim-bracketed-paste",
	"Lokaltog/vim-easymotion",
	"ggandor/leap.nvim",
	"editorconfig/editorconfig-vim",
	"godlygeek/tabular",
	"junegunn/fzf",
	"junegunn/fzf.vim",
	"justinmk/vim-dirvish",
	"nvim-treesitter/nvim-treesitter",
	"majutsushi/tagbar",
	"Yggdroot/indentLine",
	"voldikss/vim-floaterm",
	"tpope/vim-abolish",
	"tpope/vim-endwise",
	"tpope/vim-fugitive",
	"tpope/vim-surround",
	"tpope/vim-repeat",
	"tpope/vim-commentary",
	"tpope/vim-unimpaired",
	"kana/vim-textobj-user",
	"dense-analysis/ale",
	"terryma/vim-multiple-cursors",
	"junegunn/goyo.vim",
	"mhinz/vim-signify",
	"rhysd/git-messenger.vim",
	"sheerun/vim-polyglot",
	"github/copilot.vim",
	"folke/which-key.nvim",
	{ "folke/neodev.nvim", opts = {} },
	"williamboman/mason.nvim",
	{
		"jackMort/ChatGPT.nvim",
		event = "VeryLazy",
		dependencies = {
			"MunifTanjim/nui.nvim",
			"nvim-lua/plenary.nvim",
			"folke/trouble.nvim",
			"nvim-telescope/telescope.nvim",
		},
	},
	-- theme
	"morhetz/gruvbox",
	"sickill/vim-monokai",
	"dracula/vim",
	"jnurmine/Zenburn",
	"haishanh/night-owl.vim",
	"ayu-theme/ayu-vim",
	"arcticicestudio/nord-vim",
	"junegunn/seoul256.vim",
	"altercation/vim-colors-solarized",
	"yuttie/hydrangea-vim",
	"NLKNguyen/papercolor-theme",
	"folke/tokyonight.nvim",
	"rebelot/kanagawa.nvim",
	{
		"nvim-lualine/lualine.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
	},
	"SirVer/ultisnips",
	"neovim/nvim-lspconfig",
	"hrsh7th/nvim-cmp",
	"hrsh7th/cmp-nvim-lsp",
	"quangnguyen30192/cmp-nvim-ultisnips", -- lsp source for ultisnips
	"nvim-lua/plenary.nvim",
	-- language specific
	{ "begriffs/haskell-vim-now", ft = "haskell" },
	{ "hashivim/vim-terraform", ft = "terraform" },
	{ "OmniSharp/omnisharp-vim", ft = "cs" },
	{ "Glench/Vim-Jinja2-Syntax", ft = "jinja" },
	{ "jeetsukumaran/vim-pythonsense", ft = "python" },
	{ "Vimjas/vim-python-pep8-indent", ft = "python" },
	{ "simrat39/rust-tools.nvim", ft = "rust" }, -- rust analyzer inlay
	{ "rust-lang/rust.vim", ft = "rust" },
	{ "nvim-telescope/telescope.nvim", tag = "0.1.4" },
	{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
})

vim.cmd([[
" basic settings {{{
filetype plugin indent on
syntax on


set nobackup noswapfile
set encoding=utf-8
set fileformat=unix
set number
set relativenumber
set hidden
set numberwidth=4
set noignorecase "case sensitive
set backspace=2 "make backspace work like most other applications
set hlsearch incsearch
set cursorline
set showcmd "Show (partial) command in the last line of the screen.
set dictionary=/usr/share/dict/words
set autoread
set autowrite
" set clipboard^=unnamed,unnamedplus
set shell=zsh

"set title
set title titlestring=[vim] "vim
set titlestring+=\ "seperator
set titlestring+=%F "Full path to the file in the buffer.
set titlestring+=\ "seperator
set titlestring+=%m "Modified flag, text is "[+]"; "[-]" if 'modifiable' is off
set titleold="" " Do not show 'Thanks for flying vim' on exit

set autoindent
set list " show whitespace
" show tabs and trailing whitespaces
set listchars=tab:\|_,eol:¬,extends:❯,precedes:❮

" }}}
]])

vim.cmd([[
" tabs {{{
set shiftwidth=2  " sw
set tabstop=4     " ts
set softtabstop=2 " sts
set expandtab     " et

command! ShowTabs :echo printf("shiftwidth=%d tabstop=%d softtabstop=%d expandtab=%d", &sw, &ts, &sts, &et)

augroup tabs
  autocmd!
  autocmd FileType css        setlocal sw=2 ts=4 sts=2 et
  autocmd FileType html       setlocal sw=2 ts=4 sts=2 et
  autocmd FileType javascript setlocal sw=2 ts=4 sts=2 et
  autocmd FileType json       setlocal sw=2 ts=4 sts=2 et
  autocmd FileType ruby       setlocal sw=2 ts=4 sts=2 et
  autocmd FileType sh         setlocal sw=2 ts=4 sts=2 et
  autocmd FileType typescript setlocal sw=2 ts=4 sts=2 et
  autocmd FileType vim        setlocal sw=2 ts=4 sts=2 et
  autocmd FileType yaml       setlocal sw=2 ts=4 sts=2 et
  autocmd FileType python     setlocal sw=4 ts=8 sts=4 et
  autocmd FileType go         setlocal sw=4 ts=4 sts=4 noet
augroup END
" }}}
" foldmethod{{{
set foldmethod=syntax
set foldlevelstart=20

augroup folding
  autocmd!
  autocmd FileType python setlocal foldmethod=indent
augroup END
" }}}
" wildmenu completion {{{
set wildmenu
set wildmode=longest:full,full
set wildignore+=.hg,.git,.svn                    " Version control
set wildignore+=*.aux,*.out,*.toc                " LaTeX intermediate files
set wildignore+=*.jpg,*.bmp,*.gif,*.png,*.jpeg   " binary images
set wildignore+=*.o,*.obj,*.exe,*.dll,*.manifest " compiled object files
set wildignore+=*.spl                            " compiled spelling word lists
set wildignore+=*.sw?                            " Vim swap files
set wildignore+=*.DS_Store                       " OSX bullshit
set wildignore+=*.luac                           " Lua byte code
set wildignore+=migrations                       " Django migrations
set wildignore+=*.pyc,*.pyo,*pyd                 " Python byte code
set wildignore+=*.orig                           " Merge resolution files}
" }}}
" display {{{
"warn me if my line is over 88 columns
if exists('+colorcolumn')
  set colorcolumn=88
else
  au BufWinEnter * let w:m2=matchadd('ErrorMsg', '\%>88v.\+', -1)
endif

set background=dark
set termguicolors
let g:eliteColors = uniq(split('
      \ tokyonight
      \ gruvbox
      \ PaperColor
      \ kanagawa
      \ dracula
      \ hydrangea
      \ monokai
      \ night-owl
      \ nord
      \'))
" if custom themes exists, use it
" otherwise koehler
try
    let $NVIM_TUI_ENABLE_TRUE_COLOR=1
    execute 'colorscheme ' . g:eliteColors[0]
catch /^Vim\%((\a\+)\)\=:E185/
  colorscheme koehler
endtry
" }}}
]])

vim.cmd([[
" functions {{{
function! Down(vcount)
  if a:vcount == 0
    exe "normal! gj"
  else
    exe "normal! ". a:vcount ."j"
  endif
endfunction

function! Up(vcount)
  if a:vcount == 0
    exe "normal! gk"
  else
    exe "normal! ". a:vcount ."k"
  endif
endfunction

function! CopyFileName()
  let filename = expand('%:p')
  echo filename
  let @+ = filename
endfunction

function! NumberToggle()
  if !exists('&relativenumber')
    return
  endif
  if(&relativenumber == 1)
    setlocal norelativenumber
    setlocal number
  else
    setlocal relativenumber
  endif
endfunction

" toggle number and list
function! NumberAndListToggle()
  if &number || (exists('&relativenumber') && &relativenumber) || &list
    set nonumber
    if exists('&relativenumber')
      set norelativenumber
    endif
    set nolist
    if exists(":IndentLinesDisable")
      execute "IndentLinesDisable"
    endif
  else
    set number
    if exists('&relativenumber')
      set relativenumber
    endif
    set list
    if exists(":IndentLinesEnable")
      execute "IndentLinesEnable"
    endif
  endif
endfunction
"grep
function! s:GrepOperator(type)
  if a:type ==# 'v'
    normal! `<v`>y
  elseif a:type ==# 'char'
    normal! `[v`]y
  else
    return
  endif
  execute "Rg " . @@
endfunction


function! GuessProjectRoot()
  if @% != ''
    let l:dir = fnamemodify(expand('%:p'), ':h')
  else
    let l:dir = getcwd()
  endif
  while index(['/', '.'], l:dir) == -1
    for l:marker in ['.rootdir', '.git', '.hg', '.svn', 'bzr']
      if isdirectory(l:dir . '/' . l:marker)
        return l:dir
      endif
    endfor
    let l:dir = fnamemodify(l:dir, ':h')  " get parent directory
  endwhile
  " Nothing found, fallback to current working dir
  return l:dir
endfunction

function! AleStatus() abort
    let l:counts = ale#statusline#Count(bufnr(''))
    let l:all_errors = l:counts.error + l:counts.style_error
    let l:all_non_errors = l:counts.total - l:all_errors
    if l:counts.total == 0
      return "✅"
    else
      let l:status = ""
      if l:all_non_errors > 0
        let l:status = l:status . printf("%d ⚡", all_non_errors)
      endif
      if l:all_errors > 0
        let l:status = l:status . printf("%d 🚫", all_errors)
      endif
      return l:status
    endif
endfunction

function! CopyMatches(reg)
  let hits = []
  %s//\=len(add(hits, submatch(0))) ? submatch(0) : ''/ge
  let reg = empty(a:reg) ? '+' : a:reg
  execute 'let @'.reg.' = join(hits, "\n") . "\n"'
endfunction

function! s:list_buffers()
  redir => list
  silent ls
  redir END
  return split(list, "\n")
endfunction

function! s:delete_buffers(lines)
  execute 'bwipeout' join(map(a:lines, {_, line -> split(line)[0]}))
endfunction

function! DeleteOtherBuffers()
  let l:buffers = map(s:list_buffers(), {_, line -> split(line)[0]})
  let l:other_buffers = filter(l:buffers, {_, buf -> buf != bufnr('%')})
  if len(l:other_buffers) > 0
    execute 'bwipeout' join(l:other_buffers)
  else
    echo 'no other buffers found'
  endif
endfunction

" Function to toggle the location list window
function! ToggleLocationList()
    if exists('g:location_list_window_open')
        lclose
        unlet g:location_list_window_open
    else
        lopen
        let g:location_list_window_open = 1
    endif
endfunction

function! GetColors(includeBuiltin=0)
  let l:cs = []
  for c in split(globpath(&rtp, 'colors/*.vim'), '\n')
    if a:includeBuiltin == 1 || match(c, 'vimplugged') >= 0
      let l:cs = add(l:cs, split(split(c, '/')[-1], '\.')[0])
    endif
  endfor
  return l:cs
endfunction

function! UpdateColor(nextColor)
  let l:currColor = g:colors_name
  exec 'colorscheme ' . a:nextColor
  redraw
  echom 'colorschema: ' . l:currColor . ' -> ' . a:nextColor
endfunction

function! CycleColor(step, options=[])
  if len(a:options) == 0
    let l:colors = GetColors()
  else
    let l:colors = a:options
  endif
  let l:currColor = g:colors_name
  let l:nextColor = l:colors[(index(l:colors, l:currColor) + a:step) % len(l:colors)]
  call UpdateColor(l:colors[(index(l:colors, l:currColor) + a:step) % len(l:colors)])
endfunction

function! SetRandomColor()
  let l:cs = GetColors(0)
  call UpdateColor(l:cs[rand() % len(l:cs)])
endfunction
" }}}
]])

vim.keymap.set({ "n", "x", "o" }, "f", "<Plug>(leap-forward)")
vim.keymap.set({ "n", "x", "o" }, "F", "<Plug>(leap-backward)")
vim.cmd([[
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
augroup END

" Kill window
nnoremap K :hide<cr>
" leader
nnoremap <leader>aa :Rg<tab>
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
nnoremap <silent> <leader>l :call ToggleLocationList()<CR>
nnoremap <leader>m :Marks<cr>
" nnoremap <leader>n empty!
" nnoremap <leader>o emtry!
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
]])

vim.cmd([[
" global variables {{{
  let $FZF_DEFAULT_COMMAND = 'rg --files'
  let g:fzf_layout = { 'window': { 'width': 0.98, 'height': 0.8, 'highlight': 'Todo', 'border': 'sharp' } }
  let g:indentLine_setColors = 0
  let g:floaterm_autoclose = 2  " Always close floaterm window
  let g:floaterm_gitcommit = "tabe"
  let g:ale_linters = {'python': ['ruff',], 'haskell': ['hlint', 'hdevtools', 'hfmt'], 'rust': ['analyzer']}
  let g:ale_linters_ignore = {'typescript': ['deno'], 'typescriptreact': ['deno']}
  let g:ale_fixers = {'python': ['ruff', 'black', 'autopep8'], 'go': ['gofmt', 'goimports'],
        \'terraform': ['terraform'], 'javascript': ['prettier'],
        \'css': ['prettier'], 'typescript': ['prettier'], 'typescriptreact': ['prettier'],
        \'haskell':['ormolu'], 'rust':['rustfmt'], 'lua': 'stylua',
        \'sh':['shfmt']}
  let g:ale_hover_cursor = 0
  let g:ale_echo_msg_format = '[%linter%] (%code%): %s [%severity%]'
  let g:ale_echo_msg_error_str = '🚫'
  let g:ale_echo_msg_warning_str = '⚡'
  let g:ale_sh_shfmt_options = "-i 2"
  let g:ale_python_mypy_options="--ignore-missing-imports"
  let g:terraform_align=1
  let g:polyglot_disabled = ['python', 'markdown', 'autoindent']
  let g:UltiSnipsSnippetDirectories=['ultisnips']
  let g:UltiSnipsExpandTrigger = '<C-j>'
  let g:UltiSnipsJumpForwardTrigger = '<C-j>'
  let g:UltiSnipsJumpBackwardTrigger = '<C-k>'

" python provider uses pynvim specific virtualenv
if !empty(glob('~/.virtualenvs/pynvim/bin/python3'))
  let g:python3_host_prog = '~/.virtualenvs/pynvim/bin/python3'
endif

" }}}
]])

require("config")
require("copilot")
