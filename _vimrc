" Neobundle load
if has('vim_starting')
    if &compatible
      set nocompatible               " Be iMproved
    endif

    set runtimepath+=~/.vim/bundle/neobundle.vim/
endif

call neobundle#begin(expand('~/.vim/bundle/'))

" Let NeoBundle manage NeoBundle
NeoBundleFetch 'Shougo/neobundle.vim'

" After install, run from shell:
" cd ~/.vim/bundle/vimproc, (n,g)make -f os_makefile
"
NeoBundle 'Shougo/vimproc', {
      \ 'build' : {
      \     'windows' : 'make -f make_mingw32.mak',
      \     'cygwin' : 'make -f make_cygwin.mak',
      \     'mac' : 'make -f make_mac.mak',
      \     'unix' : 'make -f make_unix.mak',
      \    },
      \ }

" Installing bundles to ~/.vim/bundle
NeoBundle 'tpope/vim-fugitive'
NeoBundle 'sjl/gundo.vim'
NeoBundle 'scrooloose/syntastic'
NeoBundle 'mileszs/ack.vim'
NeoBundle 'bling/vim-airline.git'
NeoBundle 'ervandew/supertab'
NeoBundle 'jmcantrell/vim-virtualenv'
NeoBundle 'ivanov/vim-ipython'
NeoBundle 'mattn/gist-vim'
NeoBundle 'mattn/webapi-vim'
NeoBundle 'tpope/vim-surround'
NeoBundle 'Lokaltog/vim-easymotion'
NeoBundle 'scrooloose/nerdcommenter'
NeoBundle 'rodjek/vim-puppet'
NeoBundle 'Shougo/unite.vim'
NeoBundle 'Shougo/vimshell.vim'
NeoBundle 'christoomey/vim-tmux-navigator'
NeoBundle 'benmills/vimux.git'
NeoBundle 'tpope/vim-fireplace'
NeoBundle 'guns/vim-sexp'
NeoBundle 'jiangmiao/auto-pairs'
NeoBundle 'godlygeek/tabular'
NeoBundle 'hynek/vim-python-pep8-indent'
if has('python')
    NeoBundle 'SirVer/ultisnips'
    NeoBundle 'davidhalter/jedi-vim'
endif
if exists('*gettabvar')
  NeoBundle 'airblade/vim-gitgutter'
endif

call neobundle#end()

filetype plugin indent on

" Brief help
" :NeoBundleList          - list configured bundles
" :NeoBundleInstall(!)    - install(update) bundles
" :NeoBundleClean(!)      - confirm(or auto-approve) removal of unused bundles
" Installation check.
NeoBundleCheck

set nobackup noswapfile
set encoding=utf-8
set fileformat=unix
set number
if exists('&relativenumber')
    set relativenumber
endif
set hidden
set numberwidth=4
set expandtab
set tabstop=4
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
" Wrapped lines goes down/up to next row, rather than next line in file.
nnoremap <silent> j :<C-U>call Down(v:count)<CR>
vnoremap <silent> j gj

nnoremap <silent> k :<C-U>call Up(v:count)<CR>
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
nnoremap <Tab> :bnext<CR>
nnoremap <S-Tab> :bprevious<CR>

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
let mapleader = ","
let maplocalleader = " "

syntax on
"if Tomorrow-Night-Bright exists, use it
"otherwise koehler
try
    colorscheme Tomorrow-Night-Bright
catch /^Vim\%((\a\+)\)\=:E185/
     colorscheme koehler
endtry

" maps

" edit and source $MYVIMRC
noremap <leader>er :execute 'e ' . resolve(expand($MYVIMRC))<CR>
noremap <leader>es :source $MYVIMRC<CR>

" map ; to :
noremap ; :
noremap : ;

" Kill window
noremap K :hide<CR>

" Split Open
noremap <leader>v :vsp<CR>
noremap <leader>ev :Vexplore<CR>
noremap <leader>en :vnew<CR>

" Explorer
noremap Q :call ToggleExplorer()<CR>
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
noremap <leader><tab> :call ToggleTab()<CR>
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

"folding
noremap <leader><Space> za
vnoremap <leader><Space> za

" netrw settings
" keep the curreent directory the same as the browsing directory
let g:netrw_keepdir= 0
let g:netrw_list_hide= '.*\.pyc$'

" airline powerline fonts
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline_theme='bubblegum'
let g:airline#extensions#tabline#left_sep = ' '
let g:airline#extensions#tabline#left_alt_sep = '|'
let g:airline#extensions#tabline#buffer_nr_show = 1

" fugitive {{{
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

augroup ft_fugitive
    au!

    au BufNewFile,BufRead .git/index setlocal nolist
augroup END

" github
nnoremap <leader>gh :Gbrowse<cr>
vnoremap <leader>gh :Gbrowse<cr>

" }}}
"
" Clean trailing whitespace
nnoremap <leader>w mz:%s/\s\+$//<cr>:let @/=''<cr>`z

" toggle relativenumber
nnoremap <leader>n :call NumberToggle()<CR>
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
nnoremap <leader>q :call QuickfixToggle()<cr>
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
nnoremap <leader>l :call NumberAndListToggle()<cr>
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
nnoremap <leader>/ :set operatorfunc=<SID>GrepOperator<cr>g@
vnoremap <leader>/ :<c-u>call <SID>GrepOperator(visualmode())<cr>

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

" unite
function! s:ShowProjectDirectoryFile()
    let b:dirname = fnamemodify(expand('%:p'), ':h')
    let b:cvsroot = unite#util#path2project_directory(b:dirname, 1)
    if unite#util#has_vimproc()
        let b:file_rec = 'file_rec/async'
    else
        let b:file_rec = 'file_rec'
    endif
    if b:cvsroot == ''
      let b:opendir = b:dirname
    else
      let b:opendir = b:cvsroot
    endif
    execute('Unite ' . b:file_rec . ':' . b:opendir . ' -start-insert')
endfunction
"this does not work
call unite#custom#source('file,file/new,buffer,file_rec/async', 'ignore_globs', split(&wildignore, ','))
"have to have a white_globs otherwise nothing will be filtered because of a bug in unite
call unite#custom#source('file,file/new,buffer,file_rec/async', 'white_globs', ['xxxxxxxxxx'])
nnoremap <leader>f :call <SID>ShowProjectDirectoryFile()<CR>
nnoremap <leader>b :Unite buffer -start-insert<CR>
nnoremap <leader>e :Unite buffer -start-insert<CR>
nnoremap <leader>u :Unite<space>
let g:unite_source_history_yank_enable = 1
nnoremap <leader>y :Unite history/yank<cr>

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
" }}}


"vim-ipython
let g:ipy_perform_mappings = 0
map <buffer> <silent> <LocalLeader>, <Plug>(IPython-RunLine)
map <buffer> <silent> <LocalLeader>. <Plug>(IPython-RunLines)
map <buffer> <silent> <LocalLeader>f <Plug>(IPython-RunFile)


"tmux
noremap <leader>t :call VimuxOpenPane()<CR>

let g:tmux_navigator_no_mappings = 1

nnoremap <silent> <C-h> :TmuxNavigateLeft<cr>
nnoremap <silent> <C-j> :TmuxNavigateDown<cr>
nnoremap <silent> <C-k> :TmuxNavigateUp<cr>
nnoremap <silent> <C-\> :TmuxNavigatePrevious<cr>

"nerdcommenter
let g:NERDSpaceDelims = 1

"easymotion
nmap <leader>s <Plug>(easymotion-s)
nmap <leader>j <Plug>(easymotion-j)
nmap <leader>k <Plug>(easymotion-k)

"cursors in insert mode when using tmux
if exists('$TMUX')
  let &t_SI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=1\x7\<Esc>\\"
  let &t_EI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=0\x7\<Esc>\\"
else
  let &t_SI = "\<Esc>]50;CursorShape=1\x7"
  let &t_EI = "\<Esc>]50;CursorShape=0\x7"
endif
