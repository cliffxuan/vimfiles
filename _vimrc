" Vbundle load
filetype off
set rtp+=~/.vim/bundle/vundle/
call vundle#rc()
" Installing bundles to ~/.vim/bundle
Bundle 'SearchComplete'
Bundle 'gmarik/vundle'
Bundle 'tpope/vim-fugitive.git'
Bundle 'sjl/gundo.vim.git'
Bundle 'SirVer/ultisnips.git'
Bundle 'scrooloose/syntastic.git'
Bundle 'kien/ctrlp.vim.git'
Bundle 'mileszs/ack.vim.git'
Bundle 'Lokaltog/vim-powerline.git'
Bundle 'ervandew/supertab'
Bundle 'jmcantrell/vim-virtualenv.git'
Bundle 'davidhalter/jedi-vim.git'
Bundle 'ivanov/vim-ipython.git'
Bundle 'mattn/gist-vim.git'
Bundle 'mattn/webapi-vim'
Bundle 'airblade/vim-gitgutter.git'
Bundle 'tpope/vim-surround'
Bundle 'Lokaltog/vim-easymotion'
Bundle 'scrooloose/nerdcommenter'
Bundle 'plasticboy/vim-markdown'
Bundle 'Raimondi/delimitMate'
Bundle 'myusuf3/numbers.vim'
filetype plugin indent on


set nocompatible
set nobackup noswapfile
set encoding=utf-8
set fileformat=unix
if exists('&relativenumber')
    set relativenumber
else
    set number
endif
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
" Wrapped lines goes down/up to next row, rather than next line in file.
nnoremap j gj
nnoremap k gk

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
set wildmenu

set list " show whitespace
" show tabs and trailing whitespaces
set listchars=tab:\|_,eol:¬,extends:❯,precedes:❮

"warn me if my line is over 80 columns
if exists('+colorcolumn')
      set colorcolumn=80
else
    au BufWinEnter * let w:m2=matchadd('ErrorMsg', '\%>80v.\+', -1)
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
noremap <leader>ev :execute 'vsp ' . resolve(expand($MYVIMRC))<CR>
noremap <leader>sv :source $MYVIMRC<CR>

" map ; to :
noremap ; :
noremap : ;

" Kill window
noremap K :q<CR>

" Split Open
noremap <leader>v :vsp<CR>
noremap <leader>ee :Vexplore<CR>
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


" work with tabs
noremap <leader>tt :tabnew<CR>
noremap <leader>tl :tablast<CR>
noremap <leader>th :tabfirst<CR>
noremap <leader>tk :tabprevious<CR>
noremap <leader>tj :tabnext<CR>
noremap <leader>td :tabclose<CR>

" Emacs bindings in command line mode
cnoremap <c-a> <home>
cnoremap <c-e> <end>

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

" netrw settings
" keep the curreent directory the same as the browsing directory
let g:netrw_keepdir= 0

" CtrlP
nnoremap <leader>f :CtrlP<CR>
nnoremap <leader>b :CtrlPBuffer<CR>

" Fugitive {{{
nnoremap <leader>gd :Gdiff<cr>
nnoremap <leader>gs :Gstatus<cr>
nnoremap <leader>gw :Gwrite<cr>
nnoremap <leader>ga :Gadd<cr>
nnoremap <leader>gb :Gblame<cr>
nnoremap <leader>gco :Gcheckout<cr>
nnoremap <leader>gci :Gcommit<cr>
nnoremap <leader>gm :Gmove<cr>
nnoremap <leader>gr :Gremove<cr>
nnoremap <leader>gl :!git gl -18<cr>:wincmd \|<cr>

augroup ft_fugitive
    au!

    au BufNewFile,BufRead .git/index setlocal nolist
augroup END

" "Hub"
nnoremap <leader>H :Gbrowse<cr>
vnoremap <leader>H :Gbrowse<cr>

" }}}
"
" Clean trailing whitespace
nnoremap <leader>w mz:%s/\s\+$//<cr>:let @/=''<cr>`z

" Toggle relativenumber
nnoremap <leader>n :call NumberToggle()<CR>
function! NumberToggle()
    if !exists('&relativenumber')
        return
    endif
    if(&relativenumber == 1)
        setlocal number
    else
        setlocal relativenumber
    endif
endfunction

" Toggle quickfix
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

"Grep
nnoremap <leader>g :set operatorfunc=<SID>GrepOperator<cr>g@
vnoremap <leader>g :<c-u>call <SID>GrepOperator(visualmode())<cr>

function! s:GrepOperator(type)
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
    silent execute "grep! -R " . excludes . shellescape(@@) . " ."
    copen
    let @@ = saved_unnamed_register
endfunction

"jedi
let g:jedi#pydoc = "<localleader>k"
let g:jedi#popup_on_dot = 0
let g:jedi#show_function_definition = 0
let g:jedi#autocompletion_command = "<C-K>"
let g:jedi#goto_command = "<localleader>g"
let g:jedi#related_names_command = "<localleader>n"

"folding
noremap <leader><Space> za
vnoremap <leader><Space> za

" Powerline {{{
let g:Powerline_symbols = 'fancy'
let g:Powerline_cache_enabled = 1
" }}}


" Environments (GUI/Console) ---------------------------------------------- {{{
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
