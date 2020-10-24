nnoremap <buffer> <localleader>y :call <SID>pytestFile()<CR>
nnoremap <buffer> <localleader>k :call <SID>pytestOneTestCase()<CR>
nnoremap <buffer> <localleader>x :!autoflake --remove-all-unused-imports --in-place %<CR>
nnoremap <buffer> <localleader>d :call <SID>convertDict()<CR>

function! s:pytestFile()
  let l:prefix = g:ShellCommandPrefix()
  let l:winview = winsaveview()
  execute l:prefix . " pytest -s " . expand('%')
  call winrestview(l:winview)
endfunction


function! s:pytestOneTestCase()
  let l:prefix = g:ShellCommandPrefix()
  let l:winview = winsaveview()
  let l:num = line('.')
  while l:num >= 1
    let l:str = getline(l:num)
    let l:name = matchstr(l:str, '\(def \)\@<=test\S*(\@=')
    if len(l:name) > 0
      break
    endif
    let l:num = l:num - 1
  endwhile
  if len(l:name)
    execute l:prefix . " set -x; pytest -s " . expand('%') . " -k " . l:name
  else
    echo 'no testcase found'
  endif
  call winrestview(l:winview)
endfunction


function! s:convertDict()
  exec "normal! vi{"
  try
    exec '''<,''>s/^\(\s\+\)\"\(\w\+\)\": /\1\2=/g'
    exec "normal \<Esc>"
    exec "normal ds{"
  catch /.*/
    echom "Caught error: " . v:exception
    exec "normal \<Esc>"
  endtry
endfunction
