nnoremap <buffer> <localleader>y :call <SID>pytest_file()<CR>
nnoremap <buffer> <localleader>k :call <SID>pytest_one_test_case()<CR>

function! s:pytest_file()
    let l:prefix = g:ShellCommandPrefix()
    let l:winview = winsaveview()
    execute l:prefix . " pytest " . expand('%')
    call winrestview(l:winview)
endfunction


function! s:pytest_one_test_case()
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
        execute l:prefix . " set -x; pytest " . expand('%') . " -k " . l:name
    else
        echo 'no testcase found'
    endif
    call winrestview(l:winview)
endfunction
