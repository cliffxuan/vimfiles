vim.g.mapleader = ' '
vim.g.maplocalleader = ','
vim.cmd [[
" basic settings
filetype plugin indent on
syntax on

set nobackup noswapfile
set encoding=utf-8
set fileformat=unix
set number
set relativenumber
set hidden
set noshowmode
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

set autoindent
set list " show whitespace
" show tabs and trailing whitespaces
set listchars=tab:\|_,eol:¬,extends:❯,precedes:❮

]]

local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system {
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', -- latest stable release
    lazypath,
  }
end
vim.opt.rtp:prepend(lazypath)
require('lazy').setup 'lazyvim/plugins'

vim.cmd [[
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
  autocmd FileType lua        setlocal sw=2 ts=4 sts=2 et
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
set colorcolumn=88
set background=dark
set termguicolors
let g:eliteColors = uniq(split('
   \ tokyonight-night
   \ kanagawa
   \ catppuccin-mocha
   \ gruvbox
   \ PaperColor
   \ dracula
   \ hydrangea
   \ monokai
   \ night-owl
   \ nord
 \'))
let $NVIM_TUI_ENABLE_TRUE_COLOR=1
execute 'colorscheme ' . g:eliteColors[0]
" }}}
]]

vim.cmd [[
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
  for c in split(globpath(&rtp, 'colors/*.{lua,vim}'), '\n')
    if a:includeBuiltin == 1 || match(c, 'lazy') >= 0
      let l:cs = add(l:cs, split(split(c, '/')[-1], '\.')[0])
    endif
  endfor
  return l:cs
endfunction

function! UpdateColor(nextColor)
  let l:currColor = g:colors_name
  exec 'colorscheme ' . a:nextColor
  redraw
  echom 'colorscheme: ' . l:currColor . ' -> ' . a:nextColor
endfunction

function! CycleColor(step, options=[])
  if len(a:options) == 0
    let l:colors = GetColors()
  else
    let l:colors = a:options
  endif
  let l:currColor = g:colors_name
  let l:index = index(l:colors, l:currColor)
  if l:index == -1
    echom 'current colorscheme not in colors: ' . l:currColor
    return
  endif
  let l:nextColor = l:colors[(index(l:colors, l:currColor) + a:step) % len(l:colors)]
  call UpdateColor(l:nextColor)
endfunction

function! SetRandomColor()
  let l:cs = GetColors(0)
  call UpdateColor(l:cs[rand() % len(l:cs)])
endfunction
" }}}
]]

vim.cmd [[
" global variables {{{
  let $FZF_DEFAULT_COMMAND = 'rg --files'
  let $FZF_DEFAULT_OPTS = "--preview-window 'right:80%' --preview 'bat --style=numbers --line-range :300 {}'
\ --bind ctrl-y:preview-up,ctrl-e:preview-down,
\ctrl-u:preview-half-page-up,ctrl-d:preview-half-page-down,
\shift-up:preview-top,shift-down:preview-bottom"
  let g:fzf_layout = { 'window': { 'width': 0.98, 'height': 0.8, 'highlight': 'Todo', 'border': 'sharp' } }
  let g:indentLine_setColors = 0
  let g:terraform_align=1
  let g:UltiSnipsSnippetDirectories=['ultisnips']
  let g:UltiSnipsExpandTrigger = '<C-j>'
  let g:UltiSnipsJumpForwardTrigger = '<C-j>'
  let g:UltiSnipsJumpBackwardTrigger = '<C-k>'

  " python provider uses pynvim specific virtualenv
  if !empty(glob('~/.virtualenvs/pynvim/bin/python3'))
    let g:python3_host_prog = '~/.virtualenvs/pynvim/bin/python3'
  endif
" }}}
]]

require 'config'
require 'copilot'
require 'keymaps'
require 'clipboard'
require 'gpt'
