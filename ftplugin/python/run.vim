nnoremap <buffer> <localleader>r :call <SID>run_py_file()<CR>
nnoremap <buffer> <localleader>y :call <SID>pytest_file()<CR>

function! s:run_py_file()
    let l:winview = winsaveview()
    !python %
    call winrestview(l:winview)
endfunction


function! s:pytest_file()
    let l:winview = winsaveview()
    !pytest %
    call winrestview(l:winview)
endfunction
