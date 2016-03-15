if !has('python')
    finish
endif
function! FormatJson()
python << EOF
import json
import vim
vim.current.buffer[:] = json.dumps(
  json.loads('\n'.join(vim.current.buffer)), indent=2).split('\n')

EOF
endfunction
command! -register FormatJson call FormatJson()
