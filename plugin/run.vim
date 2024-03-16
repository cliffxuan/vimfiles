function! s:RunCurrentBuffer()
  let l:file = expand('%:p')
  if &filetype ==# 'vim'
    execute "source " . l:file
    return
  endif
  if &filetype ==# 'lua' && match(l:file, 'vimfiles') >= 0
    execute "source " . l:file
    return
  endif

  let l:mapping = {
              \'python': '/usr/bin/env python3',
              \'sh': '/usr/bin/env bash',
              \'typescript': '/usr/bin/env ts-node',
              \'haskell': '/usr/bin/env runhaskell',
              \'rust': '/usr/bin/env runrust',
              \'lua': '/usr/bin/env lua',
              \}
  if !has_key(l:mapping, &filetype)
    echoerr "no command registered for filetype " . &filetype
    return
  endif
  let l:prefix = g:ShellCommandPrefix()
  execute join([g:ShellCommandPrefix(), l:mapping[&filetype], '"' . l:file . '"'], ' ')
endfunction

nnoremap <Plug>RunCurrentBuffer :call <SID>RunCurrentBuffer()<cr>
