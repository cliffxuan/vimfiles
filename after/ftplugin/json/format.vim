nnoremap <buffer> <localleader>x :call <SID>FormatJson()<CR>
command! -register FormatJson call <SID>FormatJson()

function! s:FormatJson()
python << EOF
import json
import vim
formatted = json.dumps(
  json.loads('\n'.join(vim.current.buffer)), indent=2).split('\n')
if vim.current.buffer[:] != formatted:
  vim.current.buffer[:] = formatted
  vim.command('echo "json formatted"')
else:
  vim.command('echo "no change"')

EOF
endfunction
