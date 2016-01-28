if !has("python")
    finish
endif
python << EOF
import re
import vim
LINE = 'import ipdb; ipdb.set_trace()##########'

def set_breakpoint():
    n_line = int(vim.eval('line(".")'))

    whitespace = re.search('^(\s*)', vim.current.line).group(1)

    vim.current.buffer.append(whitespace + LINE, n_line - 1)

    vim.command( 'normal j1')


def remove_breakpoints():

    n_currentline = int(vim.eval( 'line(".")'))

    n_lines = []
    n_line = 1
    for line in vim.current.buffer:
        if line.lstrip() == LINE:
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
