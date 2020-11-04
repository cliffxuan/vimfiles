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


function! s:_getTestName(lineNum)
  let num = a:lineNum
  while num >= 1
    for pat in ['\(def \)\@<=test\S*(\@=',  '\(class \)\@<=Test\S*(\@=']
      let name = matchstr(getline(num), pat)
      if len(name) > 0
        return name
      endif
    endfor
    let num = num - 1
  endwhile
  return ''
endfunction


function! s:pytestOneTestCase()
  let l:winview = winsaveview()
  let l:name = s:_getTestName(line('.'))
  if len(l:name)
    execute g:ShellCommandPrefix() . " set -x; pytest -s " . expand('%') . " -k " . l:name
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
