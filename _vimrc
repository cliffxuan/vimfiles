set nocompatible
set nobackup noswapfile
set encoding=utf-8
set fileformat=unix
set number numberwidth=4
set expandtab
set softtabstop=4
set shiftwidth=4
set noignorecase "case censitive
set backspace=2 "make backspace work like most other apps
set guioptions-=TM " Remove tool bar
set hlsearch incsearch
set cursorline
set showcmd "Show (partial) command in the last line of the screen.

"set title
set title titlestring=[vim] "vim
set titlestring+=\ "seperator
set titlestring+=%F "Full path to the file in the buffer.
set titlestring+=\ "seperator
set titlestring+=%m "Modified flag, text is "[+]"; "[-]" if 'modifiable' is off
" Do not show 'Thanks for flying vim' on exit
set titleold=""


" statusline
set laststatus=2 "The value of this option influences when the last window will have a status line: 2: always
set statusline=%.40F "file path max 40
set statusline+=%m "Modified flag, text is "[+]"; "[-]" if 'modifiable' is off
set statusline+=\ "seperator
set statusline+=[%l/%L\ \ %c\ (%p%%)] "line num, total, cursor col, percentage
set statusline+=%= "align right
set statusline+=[%{&fileencoding}]
set statusline+=\ "seperator
set statusline+=[%{&fileformat}]
set statusline+=\ "seperator
set statusline+=%h "help buffer flag, text is "[help]"
set statusline+=\ "seperator
set statusline+=%r "Readonly flag, text is "[RO]".

set autoindent
set wildmenu

" show whitespace
set list
" show tabs and trailing whitespaces
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
