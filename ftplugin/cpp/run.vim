nnoremap <buffer> <localleader>r :call <SID>compile_and_run()<CR>

function! s:compile_and_run()
    let l:winview = winsaveview()
    exec '!g++ '.shellescape('%').' -o '.shellescape('%:r').' && ./'.shellescape('%:r')
    call winrestview(l:winview)
endfunction
