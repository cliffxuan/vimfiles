nnoremap <buffer> <localleader>a :call <SID>testFile(1)<CR>
nnoremap <buffer> <localleader>y :call <SID>testFile(0)<CR>
nnoremap <buffer> <localleader>c :call <SID>mkCargo()<CR>
nnoremap <buffer> <localleader>k :call <SID>testOneTestCase()<CR>

function! s:testFile(includeIgnored)
  let l:prefix = g:ShellCommandPrefix()
  let l:winview = winsaveview()
  if a:includeIgnored
    execute l:prefix . " runrust --test " . expand('%') . " -- --include-ignored"
  else
    execute l:prefix . " runrust --test " . expand('%')
  endif
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
      while 1
        let curline = getline(num + i)
        if curline == '' || curline[:1] == "//" || match(curline, '# *\[ *ignore *\]') >= 0
          let i += 1
        else
          break
        endif
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
      \ . " runrust --test " . expand('%') . " -- --include-ignored --nocapture " . l:name
  else
    echo 'no testcase found'
  endif
  call winrestview(l:winview)
endfunction
