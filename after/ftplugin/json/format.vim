function! s:UsingPython3()
  if has('python3')
    return 1
  endif
    return 0
endfunction
let s:using_python3 = s:UsingPython3()
let s:python_until_eof = s:using_python3 ? "python3 << EOF" : "python << EOF"
let s:python_command = s:using_python3 ? "py3 " : "py "

nnoremap <buffer> <localleader>x :call <SID>FormatJson()<CR>
command! -register FormatJson call <SID>FormatJson()

function! s:FormatJson()
exec s:python_until_eof
import json
import vim
vim.current.buffer[:] = json.dumps(
  json.loads('\n'.join(vim.current.buffer)), indent=2).split('\n')

EOF
endfunction
