nnoremap <buffer> <localleader>r :call <SID>run_py_file()<CR>

function! s:run_py_file()
    let l:winview = winsaveview()
    !python %
    call winrestview(l:winview)
endfunction
