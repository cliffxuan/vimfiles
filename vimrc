if 0 | endif
"Start vim-plug Scripts-----------------------------
if &compatible
  set nocompatible               " Be iMproved
endif

call plug#begin('~/.vim/plugged')

Plug 'tpope/vim-fugitive'
Plug 'sjl/gundo.vim'
Plug 'scrooloose/syntastic'
Plug 'rking/ag.vim'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'ervandew/supertab'
Plug 'jmcantrell/vim-virtualenv'
Plug 'mattn/gist-vim'
Plug 'mattn/webapi-vim'
Plug 'tpope/vim-surround'
Plug 'Lokaltog/vim-easymotion'
Plug 'scrooloose/nerdcommenter'
Plug 'Shougo/vimproc.vim', { 'do': 'make' }
Plug 'Shougo/unite.vim'
Plug 'Shougo/vimshell.vim'
Plug 'tpope/vim-fireplace'
Plug 'guns/vim-sexp'
Plug 'jiangmiao/auto-pairs'
Plug 'godlygeek/tabular'
Plug 'hynek/vim-python-pep8-indent'
Plug 'begriffs/haskell-vim-now'
Plug 'tpope/vim-abolish'
Plug 'ConradIrwin/vim-bracketed-paste'
Plug 'flazz/vim-colorschemes'
Plug 'rhysd/committia.vim'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
Plug 'jelera/vim-javascript-syntax'
Plug 'dracula/vim'

if has('python')
  Plug 'SirVer/ultisnips'
  let g:UltiSnipsSnippetDirectories=['ultisnips']
  Plug 'davidhalter/jedi-vim'
endif
if exists('*gettabvar')
  Plug 'airblade/vim-gitgutter'
endif
if has('nvim')
  Plug 'kassio/neoterm'
  let g:neoterm_size = 10
endif
if exists('g:nyaovim_version')
  Plug 'rhysd/nyaovim-mini-browser'
endif

call plug#end()

filetype plugin indent on

"End vim-plug Scripts-------------------------

if has('nvim')
  let $NVIM_TUI_ENABLE_TRUE_COLOR=1
endif

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
set clipboard=unnamedplus
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
set wildmode=list:longest
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

"warn me if my line is over 79 columns
if exists('+colorcolumn')
  set colorcolumn=79
else
  au BufWinEnter * let w:m2=matchadd('ErrorMsg', '\%>79v.\+', -1)
endif

" set <leader> to ,
let mapleader = " "
let maplocalleader = ","

syntax on
set background=dark
"if custom themes exists, use it
"otherwise koehler
try
  if has('nvim')
    colorscheme termschool
  else
    colorscheme Tomorrow-Night-Bright
  endif
catch /^Vim\%((\a\+)\)\=:E185/
  colorscheme koehler
endtry

" map ; to :
noremap ; :
noremap : ;

" Kill window
noremap K :hide<cr>

" Explorer
noremap Q :call ToggleExplorer()<cr>
if !isdirectory(expand('%'))
  let w:org_buffer_name=expand('%:p')
endif
function! ToggleExplorer()
  if !isdirectory(expand('%'))
    let w:org_buffer_name=expand('%:p')
    Explore
    normal gg
  elseif exists('w:org_buffer_name')
    execute 'e  ' . w:org_buffer_name
  endif
endfunction

" Explorer
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
" keep the curreent directory the same as the browsing directory
let g:netrw_keepdir= 0
let g:netrw_list_hide= '.*\.pyc$'

" airline powerline fonts
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline_theme='luna'
let g:airline#extensions#tabline#left_sep = ' '
let g:airline#extensions#tabline#left_alt_sep = '|'
let g:airline#extensions#tabline#buffer_nr_show = 1

" fugitive {{{

augroup ft_fugitive
  au!

  au BufNewFile,BufRead .git/index setlocal nolist
augroup END


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
  let b:dirname = fnamemodify(expand('%:p'), ':h')
  let b:cvsroot = unite#util#path2project_directory(b:dirname, 1)
  let saved_unnamed_register = @@
  if a:type ==# 'v'
    normal! `<v`>y
  elseif a:type ==# 'char'
    normal! `[v`]y
  else
    return
  endif
  let excludes = ''
  for d in ['.git', '.svn', '.hg', '.bzr']
    let excludes = excludes . '--exclude-dir='
          \. shellescape(d)  . ' '
  endfor
  silent execute "grep! -srnw --binary-files=without-match " . excludes . shellescape(@@) . " " . b:cvsroot
  copen
  let @@ = saved_unnamed_register
endfunction


function! CopyMatches(reg)
  let hits = []
  %s//\=len(add(hits, submatch(0))) ? submatch(0) : ''/ge
  let reg = empty(a:reg) ? '+' : a:reg
  execute 'let @'.reg.' = join(hits, "\n") . "\n"'
endfunction
command! -register CopyMatches call CopyMatches(<q-reg>)

"supertab
let g:SuperTabDefaultCompletionType = "<c-n>"

"jedi
let g:jedi#documentation_command = "<localleader>m"
let g:jedi#popup_on_dot = 1
let g:jedi#show_call_signatures = 0
let g:jedi#use_tabs_not_buffers = 0
let g:jedi#completions_command = "<c-j>"
let g:jedi#goto_assignments_command = "<localleader>g"
let g:jedi#usages_command = "<localleader>n"
" no docstring window popup during completion
autocmd FileType python setlocal completeopt-=preview

function! s:ShowProjectDirectoryFile()
  let b:dirname = fnamemodify(expand('%:p'), ':h')
  let b:cvsroot = unite#util#path2project_directory(b:dirname, 1)
  if b:cvsroot == ''
    let b:opendir = b:dirname
  else
    let b:opendir = b:cvsroot
  endif
  " execute('Unite ' . b:file_rec . ':' . b:opendir . ' -start-insert')
  call fzf#run({'source': 'ag -g ""', 'dir': b:opendir,
        \'down': '40%', 'sink': 'e'
        \})
endfunction
"this does not work
" call unite#custom#source('file,file/new,buffer,file_rec/async', 'ignore_globs', split(&wildignore, ','))
"have to have a white_globs otherwise nothing will be filtered because of a bug in unite
" call unite#custom#source('file,file/new,buffer,file_rec/async', 'white_globs', ['xxxxxxxxxx'])
nnoremap <leader>/ :set operatorfunc=<SID>GrepOperator<cr>g@
vnoremap <leader>a :<c-u>call <SID>GrepOperator(visualmode())<cr>
nnoremap <leader>a :Ag<cr>
nnoremap <leader>b :Buffers<cr>
" edit and source $MYVIMRC
noremap <leader>er :execute 'e ' . resolve(expand($MYVIMRC))<cr>
noremap <leader>es :source $MYVIMRC<cr>
nnoremap <leader>f :call <SID>ShowProjectDirectoryFile()<cr>
nnoremap <leader>l :Lines<cr>
nnoremap <leader>m :call NumberAndListToggle()<cr>
" toggle relativenumber
nnoremap <leader>n :call NumberToggle()<cr>
nnoremap <leader>q :call QuickfixToggle()<cr>
nnoremap <leader>u :Unite<space>
nnoremap <leader>x :GitFiles?<cr>
nmap <leader>s <Plug>(easymotion-s)
nmap <leader>j <Plug>(easymotion-j)
nmap <leader>k <Plug>(easymotion-k)
" Split Open
noremap <leader>v :vsp<cr>
noremap <leader>ev :Vexplore<cr>
noremap <leader>en :vnew<cr>
noremap <leader><tab> :call ToggleTab()<cr>
nnoremap <leader>gd :Gdiff<cr>
nnoremap <leader>gs :Gstatus<cr>
nnoremap <leader>gw :Gwrite<cr>
nnoremap <leader>ga :Git add %<cr>
nnoremap <leader>gp :Git add % -p<cr>
nnoremap <leader>gb :Gblame<cr>
nnoremap <leader>gc :Gcommit<cr>
nnoremap <leader>gm :Gmove<cr>
nnoremap <leader>gr :Gremove<cr>
nnoremap <leader>gl :!git gl -18<cr>:wincmd \|<cr>
" github
nnoremap <leader>gh :Gbrowse<cr>
vnoremap <leader>gh :Gbrowse<cr>

" Clean trailing whitespace
nnoremap <leader>w mz:%s/\s\+$//<cr>:let @/=''<cr>`z

" Git commits
nnoremap <leader>y :Commits<cr>
"folding
noremap <leader>z za
vnoremap <leader>z za
" }}}
"


" syntastic
let g:syntastic_check_on_open = 1

" environments (GUI/Console) ---------------------------------------------- {{{
if has('gui_running')
  " GUI Vim

  set guifont=Menlo\ Regular\ for\ Powerline:h12
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

" switch window
" this works in neovim and macvim
nnorema <silent> <M-h> <C-w>h
nnorema <silent> <M-j> <C-w>j
nnorema <silent> <M-k> <C-w>k
nnorema <silent> <M-l> <C-w>l
" this is for terminal vim
nnorema <silent> <Esc>h <C-w>h
nnorema <silent> <Esc>j <C-w>j
nnorema <silent> <Esc>k <C-w>k
nnorema <silent> <Esc>l <C-w>l

"nerdcommenter
let g:NERDSpaceDelims = 1

"cursors in insert mode when using tmux
if exists('$TMUX')
  let &t_SI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=1\x7\<Esc>\\"
  let &t_EI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=0\x7\<Esc>\\"
else
  let &t_SI = "\<Esc>]50;CursorShape=1\x7"
  let &t_EI = "\<Esc>]50;CursorShape=0\x7"
endif

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

" neovim terminal
if has('nvim')
  tnoremap <Esc> <C-\><C-n>
  tnoremap <M-h> <C-\><C-n><C-w>h
  tnoremap <M-j> <C-\><C-n><C-w>j
  tnoremap <M-k> <C-\><C-n><C-w>k
  tnoremap <M-l> <C-\><C-n><C-w>l
  nnoremap <leader>o :call neoterm#toggle()<cr>
endif

" Insert mode completion
imap <c-x><c-k> <plug>(fzf-complete-word)
imap <c-x><c-f> <plug>(fzf-complete-path)
imap <c-x><c-j> <plug>(fzf-complete-file-ag)
imap <c-x><c-l> <plug>(fzf-complete-line)

" Advanced customization using autoload functions
inoremap <expr> <c-x><c-k> fzf#vim#complete#word({'left': '15%'})

" use eslint as js linter
let g:syntastic_javascript_checkers = ['eslint']

" ag search project directory
let g:ag_working_path_mode="r"
