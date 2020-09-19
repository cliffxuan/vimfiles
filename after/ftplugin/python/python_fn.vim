" -*- vim -*-
" Shortcuts:
"   ]f             -- start of next function
"   [f             -- start of function
"   ]F             -- end of function
"   [F             -- end of previous function
"   [t             -- Jump to previous line with the same/lower indentation
"   ]t             -- Jump to next line with the same/lower indentation
"   <localleader>t -- Jump to beginning of block
"   <localleader>e -- Jump to end of block
"   <localleader>v -- Select (Visual Line Mode) block
"   <localleader>< -- Shift block to left
"   <localleader>> -- Shift block to right

" Only do this when not done yet for this buffer
if exists("b:loaded_py_ftplugin")
  finish
endif
let b:loaded_py_ftplugin = 1

setlocal foldmethod=indent

" unmap the default m/M from the Pythonsense plugin for function
let s:mappings = [
      \ [']m', ']f', 'PythonsenseStartOfNextPythonFunction'], 
      \ ['[m', '[f', 'PythonsenseStartOfPythonFunction'],
      \ [']M', ']F', 'PythonsenseEndOfPythonFunction'], 
      \ ['[M', '[F', 'PythonsenseEndOfPreviousPythonFunction'],
\ ]
      " \ [']]', ']c', 'PythonsenseStartOfNextPythonClass'], 
      " \ ['[[', '[c', 'PythonsenseStartOfPythonClass'],
      " \ ['[]', '[C', 'PythonsenseEndOfPreviousPythonClass'],
      " \ ['][', ']C', 'PythonsenseEndOfPythonClass'], 
for s:m in s:mappings
  let s:old = s:m[0]
  let s:new = s:m[1]
  let s:name = '<Plug>(' . s:m[2] . ')'
  if mapcheck(s:old) == s:name
    execute join(['unmap <buffer>' . s:old], ' ')
  endif
  execute join(['map <buffer>', s:new, s:name], ' ')
endfor

"   Jump to next line with the same/lower indentation
noremap <buffer> ]t   :call PythonNextLine(1)<CR>
"   Jump to previous line with the same/lower indentation
noremap <buffer> [t   :call PythonNextLine(-1)<CR>

noremap  <localleader>t   :PBoB<CR>
vnoremap <localleader>t   :<C-U>PBoB<CR>m'gv``
noremap  <localleader>e   :PEoB<CR>
vnoremap <localleader>e   :<C-U>PEoB<CR>m'gv``

noremap  <localleader>v   :PBoB<CR>:normal! V<CR>:<C-U>PEoB<CR>m'gv``
noremap  <localleader><   :PBoB<CR>:normal! V<CR>:<C-U>PEoB<CR>m'gv``<
noremap  <localleader>>   :PBoB<CR>:normal! V<CR>:<C-U>PEoB<CR>m'gv``>

:com! PBoB execute "normal ".PythonBoB(line('.'), -1, 1)."G"
:com! PEoB execute "normal ".PythonBoB(line('.'), 1, 1)."G"


" Go to a block boundary (-1: previous, 1: next)
" If force_sel_comments is true, 'g:py_select_trailing_comments' is ignored
function! PythonBoB(line, direction, force_sel_comments)
  let ln = a:line
  let ind = indent(ln)
  let mark = ln
  let indent_valid = strlen(getline(ln))
  let ln = ln + a:direction
  if (a:direction == 1) && (!a:force_sel_comments) &&
      \ exists("g:py_select_trailing_comments") &&
      \ (!g:py_select_trailing_comments)
    let sel_comments = 0
  else
    let sel_comments = 1
  endif

  while((ln >= 1) && (ln <= line('$')))
    if  (sel_comments) || (match(getline(ln), "^\\s*#") == -1)
      if (!indent_valid)
        let indent_valid = strlen(getline(ln))
        let ind = indent(ln)
        let mark = ln
      else
        if (strlen(getline(ln)))
          if (indent(ln) < ind)
            break
          endif
          let mark = ln
        endif
      endif
    endif
    let ln = ln + a:direction
  endwhile

  return mark
endfunction


" Go to previous (-1) or next (1) class/function definition
function! PythonDec(obj, direction)
  if (a:obj == "class")
    let objregexp = "^\\s*class\\s\\+[a-zA-Z0-9_]\\+"
        \ . "\\s*\\((\\([a-zA-Z0-9_,. \\t\\n]\\)*)\\)\\=\\s*:"
  else
    let objregexp = "^\\s*def\\s\\+[a-zA-Z0-9_]\\+\\s*(\\_[^:#]*)\\s*:"
  endif
  let flag = "W"
  if (a:direction == -1)
    let flag = flag."b"
  endif
  let res = search(objregexp, flag)
endfunction


" Select an object ("class"/"function")
function! PythonSelectObject(obj)
  " Go to the object declaration
  normal $
  call PythonDec(a:obj, -1)
  let beg = line('.')

  if !exists("g:py_select_leading_comments") || (g:py_select_leading_comments)
    let decind = indent(beg)
    let cl = beg
    while (cl>1)
      let cl = cl - 1
      if (indent(cl) == decind) && (getline(cl)[decind] == "#")
        let beg = cl
      else
        break
      endif
    endwhile
  endif

  if (a:obj == "class")
    let eod = "\\(^\\s*class\\s\\+[a-zA-Z0-9_]\\+\\s*"
            \ . "\\((\\([a-zA-Z0-9_,. \\t\\n]\\)*)\\)\\=\\s*\\)\\@<=:"
  else
   let eod = "\\(^\\s*def\\s\\+[a-zA-Z0-9_]\\+\\s*(\\_[^:#]*)\\s*\\)\\@<=:"
  endif
  " Look for the end of the declaration (not always the same line!)
  call search(eod, "")

  " Is it a one-line definition?
  if match(getline('.'), "^\\s*\\(#.*\\)\\=$", col('.')) == -1
    let cl = line('.')
    execute ":".beg
    execute "normal V".cl."G"
  else
    " Select the whole block
    execute "normal \<Down>"
    let cl = line('.')
    execute ":".beg
    execute "normal V".PythonBoB(cl, 1, 0)."G"
  endif
endfunction


" Jump to the next line with the same (or lower) indentation
" Useful for moving between "if" and "else", for example.
function! PythonNextLine(direction)
  let ln = line('.')
  let ind = indent(ln)
  let indent_valid = strlen(getline(ln))
  let ln = ln + a:direction

  while((ln >= 1) && (ln <= line('$')))
    if (!indent_valid) && strlen(getline(ln))
        break
    else
      if (strlen(getline(ln)))
        if (indent(ln) <= ind)
          break
        endif
      endif
    endif
    let ln = ln + a:direction
  endwhile

  execute "normal ".ln."G"
endfunction
