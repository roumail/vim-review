function! review#read(file) abort
  let l:comments = []
  let l:skipped = 0
  for l:line in readfile(a:file)
    if l:line[0] ==# "\t" && !empty(l:comments)
      let l:comments[-1].body .= "\n" . l:line[1:]
      continue
    endif
    let l:m = matchlist(l:line, '^\(.\{-}\):\(\d\+\)\%(-\(\d\+\)\)\=: \(.*\)$')
    if empty(l:m)
      let l:skipped += !empty(trim(l:line))
      continue
    endif
    call add(l:comments, {'path': l:m[1], 'start': str2nr(l:m[2]),
          \ 'end': str2nr(empty(l:m[3]) ? l:m[2] : l:m[3]), 'body': l:m[4]})
  endfor
  return {'comments': l:comments, 'skipped': l:skipped}
endfunction

function! review#write(file, comments) abort
  let l:lines = []
  for l:c in a:comments
    let l:body = split(l:c.body, "\n", 1)
    call add(l:lines, l:c.path . ':' . l:c.start . (l:c.end > l:c.start ? '-' . l:c.end : '')
          \ . ': ' . l:body[0])
    call extend(l:lines, map(l:body[1:], '"\t" . v:val'))
  endfor
  call writefile(l:lines, a:file)
endfunction
