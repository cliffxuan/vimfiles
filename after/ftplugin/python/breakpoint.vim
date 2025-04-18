noremap <LocalLeader>a :py set_breakpoint()<cr>:update<cr>
noremap <LocalLeader>p :py set_breakpoint('pdb')<cr>:update<cr>
noremap <LocalLeader>b :py remove_breakpoints()<cr>:update<cr>

python3 << EOF
import vim
import sys

plugin_dir = vim.eval('stdpath("config")') + '/python'
sys.path.insert(0, plugin_dir)
from breakpoint import *
EOF
