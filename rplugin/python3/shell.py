import subprocess

import pynvim  # type: ignore


def decode_bytes(text):
    if isinstance(text, bytes):
        return text.decode("utf-8")
    return text


def format_error(exc: subprocess.CalledProcessError) -> str:
    stdout = decode_bytes(exc.stdout)
    return f"""\
cmd:
{exc.cmd}
stdout:
{stdout}
"""


def set_result(nvim, text):
    nvim.command("botright new")
    nvim.command("set buftype=nofile bufhidden=wipe noswapfile")
    nvim.current.buffer[:] = text.strip().split("\n")


@pynvim.plugin
class Shell:
    def __init__(self, nvim):
        self.nvim = nvim

    @pynvim.command("ShellCommand", nargs=1, sync=True)
    def shell_command(self, args):
        try:
            text = subprocess.check_output(
                args,
                shell=True,
                stderr=subprocess.STDOUT,
            ).decode("utf-8")
        except subprocess.CalledProcessError as exc:
            text = format_error(exc)
        set_result(self.nvim, text)
