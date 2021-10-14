nnoremap <buffer> <localleader>y :call <SID>jestTestSingleFile()<CR>

function! s:jestTestSingleFile()
  let l:prefix = g:ShellCommandPrefix()
  let l:winview = winsaveview()
  execute l:prefix . " npx jest " . expand('%')
  call winrestview(l:winview)
endfunction
