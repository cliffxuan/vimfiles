nnoremap <buffer> <localleader>r :call <SID>run_php_file()<CR>

function! s:run_php_file()
    let l:winview = winsaveview()
    !php %
    call winrestview(l:winview)
endfunction
