nnoremap <buffer> <localleader>y :call <SID>testFile()<CR>
nnoremap <buffer> <localleader>c :call <SID>mkCargo()<CR>
nnoremap <buffer> <localleader>k :call <SID>testOneTestCase()<CR>

function! s:testFile()
  let l:prefix = g:ShellCommandPrefix()
  let l:winview = winsaveview()
  execute l:prefix . " runrust --test " . expand('%')
  call winrestview(l:winview)
endfunction

function! s:mkCargo()
  execute "!runrust --make-cargo " . expand('%') . " | xargs cat"
endfunction

function! s:_getTestName(lineNum)
  let num = a:lineNum
  let testMark = '# *\[ *test *\]'
  let testFunction = '\(^fn \)\@<=\S*(\@='
  while num >= 1
    if match(getline(num), testMark) >= 0
      let i = 1
      while getline(num + i) == '' || getline(num + i)[:1] == "//"
        let i += 1
      endwhile
      let funcName = matchstr(getline(num + i), testFunction)
      return funcName
    endif
    let num = num - 1
  endwhile
  return ''
endfunction


function! s:testOneTestCase()
  let l:winview = winsaveview()
  let l:name = s:_getTestName(line('.'))
  if len(l:name)
    execute g:ShellCommandPrefix() 
      \ . " runrust --test " . expand('%') . " -- " . l:name
  else
    echo 'no testcase found'
  endif
  call winrestview(l:winview)
endfunction
