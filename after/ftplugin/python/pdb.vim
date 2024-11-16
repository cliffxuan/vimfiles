function! s:UsingPython3()
  if has('python3')
    return 1
  endif
    return 0
endfunction
let s:using_python3 = s:UsingPython3()
let s:python_until_eof = s:using_python3 ? "python3 << EOF" : "python << EOF"
let s:python_command = s:using_python3 ? "py3 " : "py "

exec s:python_until_eof
import re
import vim
LINE0 = 'breakpoint()  # !!!!!!!!!!'
LINE1 = '__import__("pdb").set_trace()  # !!!!!!!!!!'
LINE2 = '__import__("ipdb").set_trace()  # !!!!!!!!!!'


def set_breakpoint():
    n_line = int(vim.eval('line(".")'))
    whitespace = re.search(r'^(\s*)', vim.current.line).group(1)
    vim.current.buffer.append(whitespace + LINE0, n_line - 1)
    vim.command( 'normal j1')


def remove_breakpoints():

    n_currentline = int(vim.eval( 'line(".")'))

    n_lines = []
    n_line = 1
    for line in vim.current.buffer:
        if line.lstrip() in [LINE0, LINE1, LINE2]:
            n_lines.append(n_line)
        n_line += 1

    n_lines.reverse()

    for n_line in n_lines:
        vim.command( 'normal %dG' % n_line)
        vim.command( 'normal dd')
        if n_line < n_currentline:
            n_currentline -= 1

    vim.command( 'normal %dG' % n_currentline)

vim.command('noremap  <LocalLeader>a :' + vim.eval('s:python_command') + ' set_breakpoint()<cr>:update<cr>')
vim.command('noremap <LocalLeader>b :' + vim.eval('s:python_command') + ' remove_breakpoints()<cr>:update<cr>')
EOF
