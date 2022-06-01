" vim: set foldmethod=marker foldlevel=0 nomodeline:
"Start vim-plug Scripts----------------------------- {{{
if &compatible
  set nocompatible               " Be iMproved
endif

filetype off

" vimplug is the plugin manager
call plug#begin('~/.vimplugged')

Plug 'ConradIrwin/vim-bracketed-paste'
Plug 'Lokaltog/vim-easymotion'
Plug 'justinmk/vim-sneak'
Plug 'begriffs/haskell-vim-now', { 'for': 'haskell' }
Plug 'editorconfig/editorconfig-vim'
Plug 'fatih/vim-go', { 'do': ':GoInstallBinaries', 'for': 'go' }
Plug 'godlygeek/tabular'
Plug 'jiangmiao/auto-pairs'
Plug 'junegunn/fzf',  " installation is done by zinit { 'dir': '~/.fzf', 'do': './install --all' }
  let $FZF_DEFAULT_COMMAND = 'rg --files'
Plug 'junegunn/fzf.vim'
  let g:fzf_layout = { 'window': { 'width': 0.98, 'height': 0.8, 'highlight': 'Todo', 'border': 'sharp' } }
Plug 'liuchengxu/vim-clap', { 'do': ':Clap install-binary!' }
  let g:clap_layout = { 'width': '60%', 'height': '40%' }
  let g:clap_theme = 'material_design_dark'
Plug 'justinmk/vim-dirvish'
Plug 'leafgarland/typescript-vim', { 'for': 'typescript' }
Plug 'majutsushi/tagbar'
Plug 'Yggdroot/indentLine'
  let g:indentLine_setColors = 0
Plug 'voldikss/vim-floaterm'
  let g:floaterm_autoclose = 2  " Always close floaterm window
  let g:floaterm_gitcommit = "tabe"
  " let g:floaterm_width = 0.96
  " let g:floaterm_height = 0.8
Plug 'tpope/vim-abolish'
Plug 'tpope/vim-endwise'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-commentary'
Plug 'kana/vim-textobj-user'
Plug 'kana/vim-textobj-indent'
Plug 'jeetsukumaran/vim-pythonsense', { 'for': 'python' }
Plug 'Vimjas/vim-python-pep8-indent', { 'for': 'python' }
Plug 'vim-airline/vim-airline'
  let g:airline_powerline_fonts = 1
  let g:airline_theme='ayu_dark'
  let g:airline#extensions#tabline#enabled = 1
  let g:airline#extensions#tabline#left_sep = ' '
  let g:airline#extensions#tabline#left_alt_sep = '|'
  let g:airline#extensions#tabline#buffer_nr_show = 1
Plug 'vim-airline/vim-airline-themes'
Plug 'dense-analysis/ale'
  let g:ale_statusline_format = ['⨉ %d', '⚠ %d', '⬥ ok']
  let g:ale_linters = {'haskell': ['hlint', 'hdevtools', 'hfmt'], 'rust': ['analyzer']}
  let g:ale_fixers = {'python': ['black', 'autopep8'], 'go': ['gofmt', 'goimports'],
        \'terraform': 'terraform', 'javascript': ['prettier'],
        \'css': ['prettier'], 'typescript': ['prettier'],
        \'haskell':['ormolu'], 'rust':['rustfmt']}
  let g:ale_python_mypy_options="--ignore-missing-imports"
Plug 'OmniSharp/omnisharp-vim', { 'for': 'cs' }
Plug 'Glench/Vim-Jinja2-Syntax', { 'for': 'jinja' }
Plug 'terryma/vim-multiple-cursors'
Plug 'junegunn/goyo.vim'
Plug 'preservim/nerdtree'
  let g:NERDTreeWinSize=30
  let NERDTreeIgnore = ['\.pyc$', '\.egg-info$', '__pycache__', '__pycache__']
Plug 'hashivim/vim-terraform', { 'for': 'terraform' }
  let g:terraform_align=1
Plug 'mhinz/vim-signify'
Plug 'rhysd/git-messenger.vim'
Plug 'sheerun/vim-polyglot'
  let g:polyglot_disabled = ['python', 'markdown', 'autoindent']
Plug 'rust-lang/rust.vim', {'for': 'rust'}
" themes
Plug 'morhetz/gruvbox'
Plug 'sickill/vim-monokai'
Plug 'dracula/vim'
Plug 'jnurmine/Zenburn'
Plug 'haishanh/night-owl.vim'
Plug 'ayu-theme/ayu-vim'
Plug 'arcticicestudio/nord-vim'
Plug 'junegunn/seoul256.vim'
Plug 'altercation/vim-colors-solarized'
Plug 'yuttie/hydrangea-vim'
Plug 'NLKNguyen/papercolor-theme'

" snippet
Plug 'SirVer/ultisnips'
  let g:UltiSnipsSnippetDirectories=['ultisnips']
  let g:UltiSnipsExpandTrigger = '<C-j>'
  let g:UltiSnipsJumpForwardTrigger = '<C-j>'
  let g:UltiSnipsJumpBackwardTrigger = '<C-k>'

" completion
function! BuildYCM(info)
  " info is a dictionary with 3 fields
  " - name:   name of the plugin
  " - status: 'installed', 'updated', or 'unchanged'
  " - force:  set on PlugInstall! or PlugUpdate!
  if a:info.status == 'installed' || a:info.force
    !python3 ./install.py --go-completer --ts-completer --rust-completer
  endif
endfunction
Plug 'ycm-core/YouCompleteMe', { 'do': function('BuildYCM') }
  let g:ycm_key_detailed_diagnostics = '<leader>ex'
  let g:ycm_server_keep_logfiles = 1
  let g:ycm_server_log_level = 'debug'
  let g:ycm_language_server =
        \[ { 'name': 'haskell', 'filetypes': [ 'haskell', 'hs', 'lhs' ],
        \'cmdline': [ 'haskell-language-server-wrapper' , '--lsp'],
        \'project_root_files': ['*.cabal', 'stack.yaml', 'cabal.project', 'package.yaml', 'hie.yaml'] } ]
  let g:ycm_autoclose_preview_window_after_insertion = 1
  let g:ycm_autoclose_preview_window_after_completion = 1
  let g:ycm_auto_hover = ''

call plug#end()
"End vim-plug Scripts-------------------------
"}}}

" basic settings {{{
filetype plugin indent on
syntax on

" set <leader> to and localleader
let mapleader = " "
let maplocalleader = ","

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

" statusline
set laststatus=2 "The value of this option influences when the last window will have a status line: 2: always
set statusline=%.40F "file path max 40
set statusline+=%m "Modified flag, text is "[+]"; "[-]" if 'modifiable' is off
set statusline+=\ "seperator
set statusline+=[%l/%L\ \ %c\ (%p%%)] "line num, total, cursor col, percentage
set statusline+=%< "truncate from here
set statusline+=%= "align right
set statusline+=%{exists('g:loaded_fugitive')?fugitive#statusline():''}
set statusline+=%y "Type of file in the buffer, e.g., "[vim]".  See 'filetype'.
set statusline+=\ "seperator
set statusline+=[%{&fileencoding}]
set statusline+=\ "seperator
set statusline+=[%{&fileformat}]
set statusline+=\ "seperator
set statusline+=%r "Readonly flag, text is "[RO]".

set autoindent
set list " show whitespace
" show tabs and trailing whitespaces
set listchars=tab:\|_,eol:¬,extends:❯,precedes:❮
" }}}

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

" Wildmenu completion {{{
"
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
" if custom themes exists, use it
" otherwise koehler
try
  if has('nvim')
    let $NVIM_TUI_ENABLE_TRUE_COLOR=1
    colorscheme PaperColor
    " colorscheme gruvbox
    " colorscheme monokai
    " colorscheme nord
    " colorscheme dracula
    " colorscheme hydrangea
    " colorscheme night-owl
  else
    colorscheme monokai
    " colorscheme dracula
    " colorscheme hydrangea
  endif
catch /^Vim\%((\a\+)\)\=:E185/
  colorscheme koehler
endtry
" }}}

" commands {{{

" filter lines
command! -nargs=? Filter let @a='' | execute 'g/<args>/y A' | new | setlocal bt=nofile | put! a

" Typos
command! -bang E e<bang>
command! -bang Q q<bang>
command! -bang W w<bang>
command! -bang QA qa<bang>
command! -bang Qa qa<bang>
command! -bang Wa wa<bang>
command! -bang WA wa<bang>
command! -bang Wq wq<bang>
command! -bang WQ wq<bang>

" sudo
command! Suw :w !sudo tee %

function! CopyMatches(reg)
  let hits = []
  %s//\=len(add(hits, submatch(0))) ? submatch(0) : ''/ge
  let reg = empty(a:reg) ? '+' : a:reg
  execute 'let @'.reg.' = join(hits, "\n") . "\n"'
endfunction
command! -register CopyMatches call CopyMatches(<q-reg>)

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

command! BD call fzf#run(fzf#wrap({
  \ 'source': s:list_buffers(),
  \ 'sink*': { lines -> s:delete_buffers(lines) },
  \ 'options': '--multi --reverse --bind ctrl-a:select-all+accept'
\ }))
" }}}

" netrw settings
" let g:netrw_liststyle=1
" keep the curreent directory the same as the browsing directory
" let g:netrw_keepdir= 0
let g:netrw_list_hide= '.*\.pyc$'


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

" toggle quickfix
let g:quickfix_is_open = 0
function! QuickfixToggle()
  if g:quickfix_is_open
    cclose
    let g:quickfix_is_open = 0
    execute g:quickfix_return_to_window . "wincmd w"
  else
    let g:quickfix_return_to_window = winnr()
    copen
    let g:quickfix_is_open = 1
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
  else
    set number
    if exists('&relativenumber')
      set relativenumber
    endif
    set list
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

" key map {{{
" map ; to :
" noremap ; :
" if !has("gui_vimr")
"   " this doesn't work in vimr https://github.com/qvacua/vimr/issues/552
"   noremap : ;
" endif
map f <Plug>Sneak_s
map F <Plug>Sneak_S
" Kill window
nnoremap K :hide<cr>
" Explorer
nnoremap Q :call FileManager()<cr>

" Emacs bindings in command line mode
cnoremap <c-a> <home>
cnoremap <c-e> <end>


vnoremap <leader>aa :<c-u>call <SID>GrepOperator(visualmode())<cr>
nnoremap <leader>aa :Rg<tab>
nnoremap <leader>as :exec 'Rg ' . substitute(@/, '\\[<>]', '\\b', 'g')<cr>
nnoremap <leader>b :Buffers<cr>
nnoremap <leader>c :Clap colors<cr>
" cd into directories
nnoremap <leader>dd :exec "cd " . GuessProjectRoot() <bar> :pwd<cr>
nnoremap <leader>dj :exec "cd %:h"  <bar> :pwd<cr>
nnoremap <leader>dk :exec "cd " . join([getcwd(), ".."], "/")  <bar> :pwd<cr>
nnoremap <leader>df :call fzf#run(fzf#wrap({'sink': 'cd', 'source': 'fd . -t d '}))<cr>
nnoremap <leader>dp :echo getcwd()<cr>
" edit and source $MYVIMRC
noremap <leader>ee :execute 'NERDTree ' . GuessProjectRoot() . ' <bar> NERDTreeFind ' . expand('%')<cr>
noremap <leader>ef :execute 'NERDTree ' . GuessProjectRoot()<cr>
noremap <leader>ej :execute 'NERDTree %' . ' <bar> NERDTreeFind ' . expand('%')<cr>
noremap <leader>ek :NERDTreeClose<cr>
noremap <leader>ep :UltiSnipsEdit<cr>
noremap <leader>er :call OpenVimRC()<cr>
noremap <leader>es :source $MYVIMRC<cr>
noremap <leader>ev :Vexplore<cr>
noremap <leader>en :vnew<cr>
" nnoremap <leader>f :call fzf#run(fzf#wrap({'source': 'rg --files', 'dir': getcwd()}))<cr>
nnoremap <leader>f :Files<cr>
" g for git related mappings
nnoremap <leader>ga :Git add %<cr>
nnoremap <leader>gd :SignifyHunkDiff<cr>
nnoremap <leader>gg :Git<cr>
nnoremap <leader>gp :Git push<cr>
nnoremap <leader>gb :Git blame<cr>
nnoremap <leader>gc :Git commit<cr>
nnoremap <leader>gf :GFiles?<cr>
nnoremap <leader>gh :Gbrowse<cr>
vnoremap <leader>gh :Gbrowse<cr>
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
nmap <leader>i <Plug>(YCMHover)
map <leader>j <Plug>(easymotion-j)
map <leader>k <Plug>(easymotion-k)
nnoremap <leader><leader>d :bwipeout<cr>
nnoremap <leader><leader>D :call DeleteOtherBuffers()<cr>
map <leader><leader>j <Plug>(easymotion-w)
map <leader><leader>k <Plug>(easymotion-b)
nnoremap <leader>l :Lines<cr>
nnoremap <leader>m :Marks<cr>
nnoremap <leader>n :call NumberToggle()<cr>
nnoremap <leader>o :TagbarToggle<cr>
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

" Buffer Cycling
nnoremap <Tab> :bnext<cr>
nnoremap <S-Tab> :bprevious<cr>

" ale
nmap <silent> <C-k> <Plug>(ale_previous_wrap)
nmap <silent> <C-j> <Plug>(ale_next_wrap)
" }}}

" environments (GUI/Console) ---------------------------------------------- {{{
if has('gui_running')
  " GUI Vim
  if exists("&guifont")
    set guifont=Menlo\ Regular\ for\ Powerline:h12
  endif
  " Remove all the UI cruft
  set guioptions-=T
  set guioptions-=l
  set guioptions-=L
  set guioptions-=r
  set guioptions-=R
endif

if has('gui_macvim')
  set macmeta
endif
" }}}

" fugitive {{{
augroup ft_fugitive
  au!
  au BufNewFile,BufRead .git/index setlocal nolist
augroup END
" }}}

" terminal {{{
tnoremap <C-o> <C-\><C-n>
if has('nvim')
  augroup nvim_term_insert
    autocmd TermOpen term://* startinsert
  augroup END
endif
" }}}

" fzf {{{
imap <c-x><c-k> <plug>(fzf-complete-word)
imap <c-x><c-f> <plug>(fzf-complete-path)
imap <c-x><c-j> <plug>(fzf-complete-file-ag)
imap <c-x><c-l> <plug>(fzf-complete-line)
" Advanced customization using autoload functions
inoremap <expr> <c-x><c-k> fzf#vim#complete#word({'left': '15%'})
" }}}

" ycm {{{
nnoremap gd :YcmCompleter GoToDefinition<cr>
nnoremap gr :YcmCompleter GoToReferences<cr>
" no docstring window popup during completion
augroup ycm_no_doc
  autocmd FileType python setlocal completeopt-=preview
  autocmd FileType go setlocal completeopt-=preview
augroup END
" }}}
