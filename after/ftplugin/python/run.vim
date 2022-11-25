nnoremap <buffer> <localleader>y :call <SID>pytestFile()<CR>
nnoremap <buffer> <localleader>k :call <SID>pytestOneTestCase()<CR>
nnoremap <buffer> <localleader>u :call <SID>unitTestFile()<CR>
nnoremap <buffer> <localleader>s :call <SID>unitTestOneTestCase()<CR>
nnoremap <buffer> <localleader>f :!black %<CR>
nnoremap <buffer> <localleader>x :!autoflake --remove-all-unused-imports --expand-star-imports --in-place %; isort %; black %<CR>
nnoremap <buffer> <localleader>d :call <SID>convertDict()<CR>

function! s:pytestFile()
  let l:prefix = g:ShellCommandPrefix()
  let l:winview = winsaveview()
  execute l:prefix . " pytest -s " . expand('%')
  call winrestview(l:winview)
endfunction


function! s:unitTestFile()
  let l:winview = winsaveview()
  execute g:ShellCommandPrefix() . " cd " . expand('%:p:h')
     \ . "; set -x; python -m unittest " . expand('%:t:r')
  call winrestview(l:winview)
endfunction


function! s:_getTestName(lineNum, separator)
  let num = a:lineNum
  let testFunction = '\(^\(async \|\)def \)\@<=test\S*(\@='
  let testMethod = '\(\s\+\(async \|\)def \)\@<=test\S*(\@='
  let testClass = '\(^class \)\@<=Test\S*(\@='
  let methodName = ""
  while num >= 1
    let funcName = matchstr(getline(num), testFunction)
    if len(funcName) > 0
      return funcName
    endif
    if len(methodName) == 0
      let methodName = matchstr(getline(num), testMethod)
    endif
    let className = matchstr(getline(num), testClass)
    if len(className) > 0
      if len(methodName) == 0
        return className
      else
        return className . a:separator . methodName
      endif
    endif
    let num = num - 1
  endwhile
  return ''
endfunction

function! s:pytestOneTestCase()
  let l:winview = winsaveview()
  let l:name = s:_getTestName(line('.'), '::')
  if len(l:name)
    " execute g:ShellCommandPrefix() . " set -x; pytest -vv -s " . expand('%') . "::" . l:name
    execute g:ShellCommandPrefix() . " set -x; pytest -vv -s " . expand('%') . " -k " . l:name
  else
    echo 'no testcase found'
  endif
  call winrestview(l:winview)
endfunction


function! s:unitTestOneTestCase()
  let l:winview = winsaveview()
  let l:name = s:_getTestName(line('.'), '.')
  if len(l:name)
    execute g:ShellCommandPrefix() . " cd " . expand('%:p:h')
       \ . "; set -x; python -m unittest "
       \ . expand('%:t:r') . "." . l:name
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
