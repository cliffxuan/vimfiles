nnoremap <buffer> <localleader>r :call <SID>compile_and_run()<CR>

function! s:compile_and_run()
    let l:winview = winsaveview()
    execute '!rm -f ' . shellescape('%:p:r')
    execute '!g++ '. shellescape('%') . ' -o ' . shellescape('%:r')
    execute '!' . shellescape('%:p:r')
    call winrestview(l:winview)
endfunction
