set modeline
set ls=2
set expandtab
set tabstop=8
set softtabstop=4
set shiftwidth=4
set backup
set backupdir=.\\_backup,~/tmp/vimbak,\\temp\\vimbak
set noswapfile
set ic
set nocompatible
set encoding=utf-8
" Remove tool bar
set go-=T
set go-=M
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
syntax on
filetype plugin on
colorscheme koehler

" Keyboard mappings
map ,v :sp ~/.vimrc<cr> " edit my .vimrc file in a split
map ,e :e ~/.vimrc<cr>      " edit my .vimrc file
map ,u :source ~/.vimrc<cr> " update the system settings from my vimrc file
map ,p :Lodgeit<cr>      " copy to newman pastebin

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

"cpy is treated as python
au BufNewFile,BufRead *.cpy setf python

if has("gui_running")
    " determin platform
    let s:platform=system('uname -s | perl -pe "chomp"')
    " set guifont
    " Menlo 12 for Mac
    if s:platform == "Darwin"
        set guifont=Menlo:h12
    " Otherwise Gohu size 14
    else
        set guifont=gohufont-14
    endif
    " Remove menu bar
    set go-=m
    "toggle window size
    function ToggleWindowSize(act)
      if a:act < 0 || a:act > 2 | return | endif
      let posX = getwinposx()
      let posY = getwinposy()
      let actTab = "XXX__X_XR__XX_X__RRRR__R"
      let idx = ((exists("g:twsWM") + exists("g:twsHM") * 2) * 3 + a:act) * 2
      let actW = strpart(actTab, idx, 1)
      let actH = strpart(actTab, idx + 1, 1)
      " note. g:tws + [Width,Height,X,Y] + [Maximized,Saved]
      if actW == "X"
        let g:twsWS = &columns | let g:twsXS = posX
        set columns=999
        let posX = getwinposx()
        let g:twsWM = &columns | let g:twsXM = posX
      elseif actW == "R"
        if g:twsWM == &columns
          let &columns = g:twsWS
          if g:twsXM == posX | let posX = g:twsXS | endif
        endif
        unlet g:twsWM g:twsWS g:twsXM g:twsXS
      endif
      if actH == "X"
        let g:twsHS = &lines | let g:twsYS = posY
        set lines=999
        let posY = getwinposy()
        let g:twsHM = &lines | let g:twsYM = posY
      elseif actH == "R"
        if g:twsHM == &lines
          let &lines = g:twsHS
          if g:twsYM == posY | let posY = g:twsYS | endif
        endif
        unlet g:twsHM g:twsHS g:twsYM g:twsYS
      endif
      execute "winpos " . posX . " " . posY
    endfunction
    nnoremap <F11> :call ToggleWindowSize(2)<CR>
    nnoremap <S-F11> :call ToggleWindowSize(1)<CR>
    nnoremap <C-F11> :call ToggleWindowSize(0)<CR>
    imap <F11> <C-O><F11>
    imap <S-F11> <C-O><S-F11>
    imap <C-F11> <C-O><C-F11>
endif
