python <<EOF
import vim, sys
new_path = vim.eval('expand("<sfile>:h")')
sys.path.append(new_path) # add current dir sys.path
EOF

" hastebin.com
function! s:Hastebin(...)
python <<EOF
from pastebin import Hastebin
args = vim.eval("a:000")
if args:
    for path in args:
        Hastebin.retrieve(path)
else:
    Hastebin.paste()
EOF
endfunction
command! -nargs=* Haste call <SID>Hastebin(<f-args>)

" sprunge.us
function! s:Sprunge()
    py from pastebin import Sprunge; Sprunge.paste()
endfunction
command! -register Sprunge call <SID>Sprunge()
