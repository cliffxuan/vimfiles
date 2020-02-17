" vim-go options
let g:go_debug_log_output = ''
let g:go_debug_windows = {
          \ 'vars':       'leftabove 30vnew',
          \ 'out':        'botright 5new',
\ }
let g:go_highlight_types = 1
let g:go_highlight_fields = 1
let g:go_highlight_functions = 1
let g:go_highlight_function_calls = 1
let g:go_highlight_operators = 1
let g:go_highlight_build_constraints = 1
let g:go_highlight_format_strings = 1
let g:go_highlight_variable_declarations = 1
let g:go_highlight_variable_assignments = 1

nnoremap <buffer> <localleader>a :GoDebugBreakpoint<CR>
nnoremap <buffer> <localleader>c :GoDebugContinue<CR>
nnoremap <buffer> <localleader>i :GoImport<tab>
nnoremap <buffer> <localleader>m :GoImports<CR>
nnoremap <buffer> <localleader>n :GoDebugNext<CR>
nnoremap <buffer> <localleader>o :GoRun %<tab>
nnoremap <buffer> <localleader>p :GoDebugPrint<tab>
nnoremap <buffer> <localleader>q :GoDebugStop<CR>
nnoremap <buffer> <localleader>r :GoRun<CR>
nnoremap <buffer> <localleader>s :GoDebugStart<CR>
