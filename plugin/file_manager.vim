function! FileManager()
  if exists(':FloatermNew') && executable('lf')
    execute "FloatermNew lf"
    return
  endif
  return ToggleExplorer()
endfunction


function! ToggleExplorer()
  if exists('w:original_buffer_name')
    echo 'open ' . w:original_buffer_name
    execute 'e  ' . w:original_buffer_name
    unlet w:original_buffer_name
    if exists('w:original_cwd')
      execute 'cd ' . w:original_cwd
      unlet w:original_cwd
    endif
  elseif &ft !=# 'netrw'
    let w:original_buffer_name=expand('%:p')
    let w:original_cwd=getcwd()
    echo 'open directory ' . expand('%:p:h')
    Explore
    cd %:p:h
  else
    echo 'original buffer not found'
  endif
endfunction

