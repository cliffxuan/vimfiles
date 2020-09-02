function! g:ShellCommandPrefix()
  if has('nvim')
    if exists(':FloatermNew')
      return 'FloatermNew --autoclose=0'
    else
      return 'term '
    endif
  else
    return '! '
  endif
endfunction
