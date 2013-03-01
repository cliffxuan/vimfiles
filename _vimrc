set nocompatible
set nobackup
set noswapfile
set encoding=utf-8
set fileformat=unix
set number
set numberwidth=4
set expandtab
set softtabstop=4
set shiftwidth=4
set noignorecase "case censitive
" Remove tool bar
set go-=T
set go-=M
set incsearch
set cursorline
set showcmd
set title titlestring=[vim]\ %t%(\ %M%)%(\ (%{expand(\"%:.:h\")})%)%(\ %a%)\ -\ %{v:servername}

" Do not show 'Thanks for flying vim' on exit
set titleold=""
set backspace=2 "make backspace work like most other apps

set laststatus=2 "The value of this option influences when the last window will have a status line: 2: always


" statusline
set statusline=%.40F "file path max 40
set statusline+=\ "seperator
set statusline+=[%l/%L\ \ %c\ (%p%%)] "line num, total, cursor col, percentage
set statusline+=%= "align right
set statusline+=[%{&fileencoding}]
set statusline+=\ "seperator
set statusline+=[%{&fileformat}]
set statusline+=\ "seperator

set autoindent
set wildmenu

" show whitespace
set list
" show tabs
set listchars=tab:\|_,trail:.

"warn me if my line is over 80 columns
set colorcolumn=80

" set <leader> to ,
let mapleader = ","
let maplocalleader = " "

" maps

" edit and source $MYVIMRC
noremap <leader>ev :vsp $MYVIMRC<CR>
noremap <leader>sv :source $MYVIMRC<CR>

"map jk to exit insert mode
inoremap jk <Esc>

"map ; to :
noremap ; :

" FuzzyFinder
nnoremap <leader>f :FufFileWithCurrentBufferDir<CR>
nnoremap <leader>b :FufBuffer<CR>
nnoremap <leader>t :FufTaggedFile<CR>

" work with tabs
noremap tt :tabnew<CR>
noremap tl :tablast<CR>
noremap th :tabfirst<CR>
noremap tk :tabprevious<CR>
noremap tj :tabnext<CR>
noremap td :tabclose<CR>

" netrw settings
" keep the curreent directory the same as the browsing directory
let g:netrw_keepdir= 0

" Pathogen load
filetype off

call pathogen#infect()
call pathogen#helptags()

filetype plugin indent on
syntax on

"if Tomorrow-Night-Bright exists, use it
"otherwise koehler
try
    colorscheme Tomorrow-Night-Bright
catch /^Vim\%((\a\+)\)\=:E185/
     colorscheme koehler
endtry
