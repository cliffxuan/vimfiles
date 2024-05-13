function! OpenVimRC()
  let l:vimrc = resolve(expand($MYVIMRC))
  if bufname("%") == ''
    execute 'e ' . l:vimrc
  else
    execute 'tab new ' . l:vimrc
  endif
endfunction


function! OpenKeymaps()
  let l:keymaps = expand(stdpath("config") . "/lua/keymaps.lua")
  if bufname("%") == ''
    execute 'e ' . l:keymaps
  else
    execute 'tab new ' . l:keymaps
  endif
endfunction


function! OpenPlugins()
  let l:keymaps = expand(stdpath("config") . "/lua/lazyvim/plugins/init.lua")
  if bufname("%") == ''
    execute 'e ' . l:keymaps
  else
    execute 'tab new ' . l:keymaps
  endif
endfunction
