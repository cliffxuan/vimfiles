if !has("python")
    finish
endif
python << EOF
import re
import vim
IMPORT = 'import ipdb #####import ipdb'
CALL = 'ipdb.set_trace()'

def set_breakpoint():
    n_line = int(vim.eval('line(".")'))

    whitespace = re.search('^(\s*)', vim.current.line).group(1)

    vim.current.buffer.append(whitespace + IMPORT, n_line - 1)
    vim.current.buffer.append(
       """%(space)s%(call_str)s  %(mark)s Breakpoint %(mark)s""" %
         {'space':whitespace, 'mark': '#' * 30, 'call_str': CALL}, n_line)

    vim.command( 'normal j1')


def remove_breakpoints():

    n_currentline = int(vim.eval( 'line(".")'))

    n_lines = []
    n_line = 1
    for line in vim.current.buffer:
        if line.lstrip() == IMPORT or line.lstrip()[:15] == CALL:
            n_lines.append(n_line)
        n_line += 1

    n_lines.reverse()

    for n_line in n_lines:
        vim.command( 'normal %dG' % n_line)
        vim.command( 'normal dd')
        if n_line < n_currentline:
            n_currentline -= 1

    vim.command( 'normal %dG' % n_currentline)

vim.command('noremap  <LocalLeader>b :py set_breakpoint()<cr>:update<cr>')
vim.command('noremap <LocalLeader>d :py remove_breakpoints()<cr>:update<cr>')
EOF
