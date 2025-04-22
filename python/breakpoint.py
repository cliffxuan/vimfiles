import re

import vim  # type: ignore

DEBUGGERS = ["pdb", "ipdb", "pudb"]


def get_line(debugger=None):
    if debugger is None:
        statement = "breakpoint()"
    else:
        statement = f'__import__("{debugger}").set_trace()'
    return f"{statement}  # !!!!!!!!!!"


def set_breakpoint(debugger=None):
    n_line = int(vim.eval('line(".")'))
    match = re.search(r"^(\s*)", vim.current.line)
    if match is None:
        vim.command("echoerr 'No whitespace found in the current line.'")
        return
    whitespace = match.group(1)
    vim.current.buffer.append(whitespace + get_line(debugger), n_line - 1)


def remove_breakpoints():
    n_currentline = int(vim.eval('line(".")'))

    n_lines = []
    n_line = 1
    for line in vim.current.buffer:
        if line.lstrip() in [
            get_line(),
            *[get_line(debugger) for debugger in DEBUGGERS],
        ]:
            n_lines.append(n_line)
        n_line += 1

    n_lines.reverse()

    for n_line in n_lines:
        vim.command("normal %dG" % n_line)
        vim.command("normal dd")
        if n_line < n_currentline:
            n_currentline -= 1

    vim.command("normal %dG" % n_currentline)
