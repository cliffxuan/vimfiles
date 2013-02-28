set modeline
set ls=2
set expandtab
set softtabstop=4
set shiftwidth=4
set nobackup
set noswapfile
set noic
set nocompatible
set encoding=utf-8
" Remove tool bar
set go-=T
set go-=M
set fileformat=unix
set number
set hlsearch
set incsearch
set cursorline
set showcmd
set ruler
set title titlestring=[vim]\ %t%(\ %M%)%(\ (%{expand(\"%:.:h\")})%)%(\ %a%)\ -\ %{v:servername}

" Do not show 'Thanks for flying vim' on exit
set titleold=""
set backspace=2
set numberwidth=4
set statusline=%f%m%r%h%w\ [%{&ff}]\ [%l/%L\ \ %c\ (%p%%)]  

set autoindent
set wildmenu

" show whitespace
set list
" show tabs
set listchars=tab:\|_,trail:.

"warn me if my line is over 80 columns
set colorcolumn=80

" disable use of included files in default completion
set complete-=i

" colorscheme koehler
colorscheme Tomorrow-Night-Bright

" set <leader> to ,
let mapleader = ","
let maplocalleader = " "

" maps

"save file
noremap <C-s> :update<CR>
inoremap <C-s> <Esc>:update<CR>

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
