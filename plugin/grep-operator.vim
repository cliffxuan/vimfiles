nnoremap <leader>g :set operatorfunc=<SID>GrepOperator<cr>g@
vnoremap <leader>g :<c-u>call <SID>GrepOperator(visualmode())<cr>

function! s:GrepOperator(type)
    let saved_unnamed_register = @@

    if a:type ==# 'v'
        normal! `<v`>y
    elseif a:type ==# 'char'
        normal! `[v`]y
    else
        return
    endif

    let excludes = ''
    for d in ['.git', '.svn', '.hg']
        let excludes = excludes . '--exclude-dir=' 
                    \. shellescape(d)  . ' '
    endfor

    silent execute "grep! -R " . excludes . shellescape(@@) . " ."
    copen

    let @@ = saved_unnamed_register
endfunction
