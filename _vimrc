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

" colorscheme koehler
colorscheme Tomorrow-Night-Bright

" Keyboard mappings
map ,v :sp ~/.vimrc<cr> " edit my .vimrc file in a split
map ,e :e ~/.vimrc<cr>      " edit my .vimrc file
map ,u :source ~/.vimrc<cr> " update the system settings from my vimrc file

" FuzzyFinder
nmap ,f :FufFileWithCurrentBufferDir<CR>
nmap ,b :FufBuffer<CR>
nmap ,t :FufTaggedFile<CR>

" work with tabs
map tt :tabnew<CR>
map tl :tablast<CR>
map th :tabfirst<CR>
map tk :tabprevious<CR>
map tj :tabnext<CR>

" netrw settings
" keep the curreent directory the same as the browsing directory
let g:netrw_keepdir= 0

"warn me if my line is over 80 columns
"to clear, use this command
":call clearmatches()
if exists('+colorcolumn')
  set colorcolumn=80
else
  au BufWinEnter * let w:m2=matchadd('ErrorMsg', '\%>80v.\+', -1)
endif

" add ultisnips to runtime dir
set runtimepath+=~/.vim/ultisnips_rep
" disable use of included files in default completion
set complete-=i
" Pathogen load
filetype off

call pathogen#infect()
call pathogen#helptags()

filetype plugin indent on
syntax on
