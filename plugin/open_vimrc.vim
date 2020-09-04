function! OpenVimRC()
  let l:vimrc = resolve(expand($MYVIMRC))
  if bufname("%") == ''
    execute 'e ' . l:vimrc
  else
    execute 'tab new ' . l:vimrc
  endif
endfunction
