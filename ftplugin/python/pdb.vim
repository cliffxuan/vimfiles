if has("python")
python << EOF
import vim
import_str = 'exec "try: import ipdb as pdb\\nexcept:import pdb" #####import ipdb or pdb'
call_str = 'pdb.set_trace()'

def SetBreakpoint():
    import re
    nLine = int( vim.eval( 'line(".")'))

    strLine = vim.current.line
    strWhite = re.search( '^(\s*)', strLine).group(1)

    vim.current.buffer.append(
       """%(space)s%(call_str)s  %(mark)s Breakpoint %(mark)s""" %
         {'space':strWhite, 'mark': '#' * 30, 'call_str': call_str}, nLine - 1)

    for strLine in vim.current.buffer:
        if strLine == import_str:
            break
    else:
        vim.current.buffer.append( import_str, 0)
        vim.command( 'normal j1')

vim.command( 'map  ,b :py SetBreakpoint()<cr>')

def RemoveBreakpoints():
    import re

    nCurrentLine = int( vim.eval( 'line(".")'))

    nLines = []
    nLine = 1
    for strLine in vim.current.buffer:
        if strLine == import_str or strLine.lstrip()[:15] == call_str:
            nLines.append( nLine)
        nLine += 1

    nLines.reverse()

    for nLine in nLines:
        vim.command( 'normal %dG' % nLine)
        vim.command( 'normal dd')
        if nLine < nCurrentLine:
            nCurrentLine -= 1

    vim.command( 'normal %dG' % nCurrentLine)

vim.command( 'map ,d :py RemoveBreakpoints()<cr>')
EOF

nmap <buffer> <F5> :w<Esc>mwG:!python %<CR>
endif
