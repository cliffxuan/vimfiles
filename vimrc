if 0 | endif
"Start vim-plug Scripts-----------------------------
if &compatible
  set nocompatible               " Be iMproved
endif

filetype off

" vimplug is the plugin manager
call plug#begin('~/.vimplugged')

Plug 'ConradIrwin/vim-bracketed-paste'
Plug 'Lokaltog/vim-easymotion'
Plug 'begriffs/haskell-vim-now', { 'for': 'haskell' }
Plug 'editorconfig/editorconfig-vim'
Plug 'elzr/vim-json', { 'for': 'json' }
Plug 'fatih/vim-go', { 'do': ':GoInstallBinaries', 'for': 'go' }
Plug 'godlygeek/tabular'
Plug 'google/yapf', { 'rtp': 'plugins/vim', 'for': 'python' }
" Plug 'guns/vim-sexp', { 'for': 'clojure' }
Plug 'hynek/vim-python-pep8-indent', { 'for': 'python' }
Plug 'jelera/vim-javascript-syntax', { 'for': 'javascript' }
Plug 'jiangmiao/auto-pairs'
Plug 'jmcantrell/vim-virtualenv', { 'for': 'python' }
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
Plug 'justinmk/vim-dirvish'
Plug 'leafgarland/typescript-vim', { 'for': 'typescript' }
Plug 'majutsushi/tagbar'
Plug 'mattn/gist-vim'
Plug 'mattn/webapi-vim'
Plug 'Yggdroot/indentLine'
Plug 'sjl/gundo.vim'
Plug 'voldikss/vim-floaterm'
" Plug 'tomlion/vim-solidity', { 'for': 'solidity' }
Plug 'tpope/vim-abolish'
" Plug 'tpope/vim-fireplace', { 'for': 'clojure' }
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-commentary'
Plug 'lambdalisue/suda.vim'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'dense-analysis/ale'
Plug 'OmniSharp/omnisharp-vim', { 'for': 'cs' }
Plug 'Glench/Vim-Jinja2-Syntax', { 'for': 'jinja' }
Plug 'haishanh/night-owl.vim'
Plug 'terryma/vim-multiple-cursors'
Plug 'junegunn/goyo.vim'
Plug 'preservim/nerdtree'
Plug 'hashivim/vim-terraform', { 'for': 'terraform' }
Plug 'airblade/vim-gitgutter'

" themes
Plug 'joshdick/onedark.vim'
Plug 'morhetz/gruvbox'
Plug 'sickill/vim-monokai'
Plug 'dracula/vim'
Plug 'jnurmine/Zenburn'
Plug 'chriskempson/base16-vim'
Plug 'sonph/onehalf', {'rtp': 'vim/'}


if has('python3')
  Plug 'SirVer/ultisnips'
  let g:UltiSnipsSnippetDirectories=['ultisnips']
  " UltiSnips triggering
  let g:UltiSnipsExpandTrigger = '<C-j>'
  let g:UltiSnipsJumpForwardTrigger = '<C-j>'
  let g:UltiSnipsJumpBackwardTrigger = '<C-k>'
  function! BuildYCM(info)
    " info is a dictionary with 3 fields
    " - name:   name of the plugin
    " - status: 'installed', 'updated', or 'unchanged'
    " - force:  set on PlugInstall! or PlugUpdate!
    if a:info.status == 'installed' || a:info.force
      !python3 ./install.py --go-completer
    endif
  endfunction
  Plug 'ycm-core/YouCompleteMe', { 'do': function('BuildYCM') }
endif

call plug#end()

filetype plugin indent on

"End vim-plug Scripts-------------------------

set nobackup noswapfile
if !has('nvim')
  set encoding=utf-8
endif
set fileformat=unix
set number
if exists('&relativenumber')
  set relativenumber
endif
set hidden
set numberwidth=4
set expandtab
set tabstop=8
set softtabstop=4
set shiftwidth=4
set noignorecase "case sensitive
set backspace=2 "make backspace work like most other applications
set hlsearch incsearch
set cursorline
set showcmd "Show (partial) command in the last line of the screen.
set dictionary=/usr/share/dict/words
set autoread
set autowrite
set clipboard^=unnamed,unnamedplus
set shell=zsh
" Wrapped lines goes down/up to next row, rather than next line in file.
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

"folding
set foldmethod=indent
set foldlevelstart=20

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

" Buffer Cycling
nnoremap <Tab> :bnext<cr>
nnoremap <S-Tab> :bprevious<cr>

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

set list " show whitespace
" show tabs and trailing whitespaces
set listchars=tab:\|_,eol:¬,extends:❯,precedes:❮

"warn me if my line is over 88 columns
if exists('+colorcolumn')
  set colorcolumn=88
else
  au BufWinEnter * let w:m2=matchadd('ErrorMsg', '\%>88v.\+', -1)
endif

" set <leader> to ,
let mapleader = " "
let maplocalleader = ","

syntax on
set background=dark
set termguicolors
" if custom themes exists, use it
" otherwise koehler
try
  if has('nvim')
    colorscheme base16-dracula
    " colorscheme gruvbox
    " colorscheme onedark
  else
    " colorscheme onedark
    colorscheme gruvbox
    " colorscheme base16-tomorrow-night
    " colorscheme base16-gruvbox-dark-hard
  endif
catch /^Vim\%((\a\+)\)\=:E185/
  colorscheme koehler
endtry

" map ; to :
noremap ; :
if !has("gui_vimr")
  " this doesn't work in vimr https://github.com/qvacua/vimr/issues/552
  noremap : ;
endif

" Kill window
nnoremap K :hide<cr>

" Explorer
nnoremap Q :call FileManager()<cr>

function! FileManager()
  if exists(':FloatermNew') && executable('lf')
    execute "FloatermNew lf"
    return
  endif
  return ToggleExplorer()
endfunction


function! ToggleExplorer()
  if exists('w:original_buffer_name')
    echo 'open ' . w:original_buffer_name
    execute 'e  ' . w:original_buffer_name
    unlet w:original_buffer_name
    if exists('w:original_cwd')
      execute 'cd ' . w:original_cwd
      unlet w:original_cwd
    endif
  elseif &ft !=# 'netrw'
    let w:original_buffer_name=expand('%:p')
    let w:original_cwd=getcwd()
    echo 'open directory ' . expand('%:p:h')
    Explore
    cd %:p:h
  else
    echo 'original buffer not found'
  endif
endfunction

" ToggleTab
function! ToggleTab()
  if &expandtab
    set noexpandtab
    echo 'tab on'
  else
    set expandtab
    echo 'tab off'
  endif
endfunction

" Emacs bindings in command line mode
cnoremap <c-a> <home>
cnoremap <c-e> <end>

" filter command
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

" netrw settings
" let g:netrw_liststyle=1
" keep the curreent directory the same as the browsing directory
" let g:netrw_keepdir= 0
let g:netrw_list_hide= '.*\.pyc$'

" airline powerline fonts
let g:airline_powerline_fonts = 1
let g:airline_theme='luna'
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#left_sep = ' '
let g:airline#extensions#tabline#left_alt_sep = '|'
let g:airline#extensions#tabline#buffer_nr_show = 1

" fugitive {{{

augroup ft_fugitive
  au!

  au BufNewFile,BufRead .git/index setlocal nolist
augroup END

"don't allow vim-gitgutter to set up any mappings at all
let g:gitgutter_map_keys = 0
let g:gitgutter_preview_win_floating = 1

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


function! CopyMatches(reg)
  let hits = []
  %s//\=len(add(hits, submatch(0))) ? submatch(0) : ''/ge
  let reg = empty(a:reg) ? '+' : a:reg
  execute 'let @'.reg.' = join(hits, "\n") . "\n"'
endfunction
command! -register CopyMatches call CopyMatches(<q-reg>)

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

function! g:ShellCommandPrefix()
  if has('nvim')
    if exists(':FloatermNew')
      return 'FloatermNew '
    else
      return 'term '
    endif
  else
    return '! '
  endif
endfunction

function! s:RunCurrentBuffer()
  let l:file = expand('%')
  if &filetype ==# 'vim'
    execute "source " . l:file
    return
  endif

  let l:mapping = {
              \'python': '/usr/bin/env python3',
              \'sh': '/usr/bin/env bash',
              \}
  if !has_key(l:mapping, &filetype)
    echoerr "no command registered for filetype " . &filetype
    return
  endif
  let l:prefix = g:ShellCommandPrefix()
  execute join([g:ShellCommandPrefix(), l:mapping[&filetype], l:file], ' ')
endfunction

"https://vim.fandom.com/wiki/Capture_ex_command_output
function! TabMessage(cmd)
  redir => message
  silent execute a:cmd
  redir END
  if empty(message)
    echoerr "no output"
  else
    " use "new" instead of "tabnew" below if you prefer split windows instead of tabs
    tabnew
    setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted nomodified
    silent put=message
  endif
endfunction
command! -nargs=+ -complete=command TabMessage call TabMessage(<q-args>)

vnoremap <leader>aa :<c-u>call <SID>GrepOperator(visualmode())<cr>
nnoremap <leader>aa :Rg<tab>
nnoremap <leader>as :exec 'Rg ' . substitute(@/, '\\[<>]', '\\b', 'g')<cr>
nnoremap <leader>b :Buffers<cr>
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
nnoremap <leader>ed :bdelete<cr>
noremap <leader>ep :UltiSnipsEdit<cr>
noremap <leader>er :execute 'tab new ' . resolve(expand($MYVIMRC))<cr>
noremap <leader>es :source $MYVIMRC<cr>
noremap <leader>ev :Vexplore<cr>
noremap <leader>en :vnew<cr>
nnoremap <leader>f :call fzf#run(fzf#wrap({'source': 'rg --files', 'dir': getcwd()}))<cr>
" g for git related mappings
nnoremap <leader>gd :Gvdiff<cr>
nnoremap <leader>gg :Git<cr>
nnoremap <leader>ga :Git add %<cr>
nnoremap <leader>gp :Git push<cr>
nnoremap <leader>gb :Gblame<cr>
nnoremap <leader>gc :Gcommit<cr>
nnoremap <leader>gf :GFiles?<cr>
nnoremap <leader>gl :Commits<cr>
nnoremap <leader>go :BCommits<cr>
nnoremap <leader>gr :Gread<cr>
nnoremap <leader>gw :Gwrite<cr>
nmap <leader>gj <Plug>(GitGutterNextHunk)
nmap <leader>gk <Plug>(GitGutterPrevHunk)
nmap gs <Plug>(GitGutterStageHunk)
nmap gu <Plug>(GitGutterUndoHunk)
nmap gv <Plug>(GitGutterPreviewHunk)
nnoremap <leader>gh :Gbrowse<cr>
vnoremap <leader>gh :Gbrowse<cr>
nnoremap <leader>hh :History<cr>
nnoremap <leader>hs :History/<cr>
nnoremap <leader>hc :History:<cr>
map <leader>j <Plug>(easymotion-j)
map <leader>k <Plug>(easymotion-k)
map <leader><leader>j <Plug>(easymotion-w)
map <leader><leader>k <Plug>(easymotion-b)
nnoremap <leader>l :Lines<cr>
nnoremap <leader>m :Marks<cr>
nnoremap <leader>n :call NumberToggle()<cr>
nnoremap <leader>o :TagbarToggle<cr>
" toggle relativenumber
nnoremap <leader>p :call NumberAndListToggle()<cr>
nnoremap <leader>q :call QuickfixToggle()<cr>
nnoremap <leader>r :call <SID>RunCurrentBuffer()<cr>
nnoremap <leader>s :Snippets<cr>
nnoremap <leader>t :FloatermToggle<cr>
" Clean trailing whitespace
nnoremap <leader>u mz:%s/\s\+$//<cr>:let @/=''<cr>`z
" Split Open
noremap <leader>v :vsp<cr>
noremap <leader><tab> :call ToggleTab()<cr>


" save
nnoremap <leader>w :w<cr>
" alx-fix
nnoremap <leader>x :ALEFix<cr>

" copy file name
nnoremap <leader>y :call CopyFileName()<cr>
noremap <leader>z za
vnoremap <leader>z za
" }}}
"

" ale
let g:ale_statusline_format = ['⨉ %d', '⚠ %d', '⬥ ok']
let g:ale_fixers = {'python': ['black', 'autopep8'], 'go': ['gofmt', 'goimports'], 'terraform': 'terraform'}

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

"nerdcommenter
let g:NERDSpaceDelims = 1
let g:NERDDefaultAlign = 'left'
let NERDTreeIgnore = ['\.pyc$', '\.egg-info$', '__pycache__', '__pycache__']

"nerdtree
let g:NERDTreeWinSize=30


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

" terminal
tnoremap <Esc> <C-\><C-n>
if has('nvim')
  let $NVIM_TUI_ENABLE_TRUE_COLOR=1
  autocmd TermOpen term://* startinsert
endif

" fzf completion
imap <c-x><c-k> <plug>(fzf-complete-word)
imap <c-x><c-f> <plug>(fzf-complete-path)
imap <c-x><c-j> <plug>(fzf-complete-file-ag)
imap <c-x><c-l> <plug>(fzf-complete-line)
" Advanced customization using autoload functions
inoremap <expr> <c-x><c-k> fzf#vim#complete#word({'left': '15%'})

" do not show indentation for json
let g:vim_json_syntax_conceal = 0

" YCM
let g:ycm_key_detailed_diagnostics = '<leader>ex'
nnoremap gd :YcmCompleter GoToDefinition<cr>
nnoremap gr :YcmCompleter GoToReferences<cr>
" no docstring window popup during completion
autocmd FileType python setlocal completeopt-=preview
autocmd FileType go setlocal completeopt-=preview

" Allow vim-terraform to align settings automatically with Tabularize.
let g:terraform_align=1

" Ale
let g:ale_python_mypy_options="--ignore-missing-imports"
nmap <silent> <C-k> <Plug>(ale_previous_wrap)
nmap <silent> <C-j> <Plug>(ale_next_wrap)

" Floaterm
let g:floaterm_autoclose=2  " Always close floaterm window
let g:floaterm_gitcommit="tabe"
