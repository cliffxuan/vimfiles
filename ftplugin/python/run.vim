if !has("python")
    finish
endif
nmap <buffer> <localleader>r :w<Esc>mwG:!python %<CR>

