function! CommentOutMail()
    execute '%s/\(^ *\)\(mail(\)/\1\/\/\2/g'
endfunction
