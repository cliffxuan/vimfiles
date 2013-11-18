python <<EOF
import vim, sys
new_path = vim.eval('expand("<sfile>:h")')
sys.path.append(new_path) # add current dir sys.path
EOF

" hastebin.com
function! s:Hastebin(...)
  py from pastebin import Hastebin
  if a:0
    for path in a:000
      py Hastebin.retrieve(vim.eval('path'))
    endfor
  else
    py Hastebin.paste()
  endif
endfunction
command! -nargs=* Haste call <SID>Hastebin(<f-args>)

" sprunge.us
function! s:Sprunge()
  py from pastebin import Sprunge; Sprunge.paste()
endfunction
command! -register Sprunge call <SID>Sprunge()
