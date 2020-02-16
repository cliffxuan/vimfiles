" vim-go options
let g:go_debug_log_output = ''
let g:go_debug_windows = {
          \ 'vars':       'leftabove 30vnew',
          \ 'out':        'botright 5new',
\ }

nnoremap <buffer> <localleader>a :GoDebugBreakpoint<CR>
nnoremap <buffer> <localleader>c :GoDebugContinue<CR>
nnoremap <buffer> <localleader>i :GoImport<tab>
nnoremap <buffer> <localleader>m :GoImports<CR>
nnoremap <buffer> <localleader>n :GoDebugNext<CR>
nnoremap <buffer> <localleader>p :GoDebugPrint<tab>
nnoremap <buffer> <localleader>q :GoDebugStop<CR>
nnoremap <buffer> <localleader>r :GoRun<CR>
nnoremap <buffer> <localleader>s :GoDebugStart<CR>
