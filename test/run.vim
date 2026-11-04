" Headless tests, from the repository's root:
"   vim -Nu NONE -i NONE -Es -S test/run.vim
" Prints one line per test and exits non-zero when one fails; TEST=<pattern>
" in the environment runs the tests whose names match.
set nocompatible
execute 'set runtimepath^=' . fnameescape(expand('<sfile>:p:h:h'))

let s:tmp = resolve(tempname())
call mkdir(s:tmp, 'p')
let s:file = s:tmp . '/comments.txt'
let s:out = []

function! s:reset() abort
  call delete(s:file)
endfunction

function! s:test_read() abort
  call writefile([
        \ 'src/app.py:12: check the None case',
        \ 'src/app.py:20-24: is this loop needed?',
        \ "\tIt seems to repeat line 8.",
        \ "\t",
        \ "\tAnd line 9.",
        \ ], s:file)
  call assert_equal({'skipped': 0, 'comments': [
        \ {'path': 'src/app.py', 'start': 12, 'end': 12, 'body': 'check the None case'},
        \ {'path': 'src/app.py', 'start': 20, 'end': 24,
        \  'body': "is this loop needed?\nIt seems to repeat line 8.\n\nAnd line 9."},
        \ ]}, review#read(s:file))
endfunction

function! s:test_read_counts_lines_not_in_the_format() abort
  call writefile([
        \ 'Here are my comments:',
        \ '',
        \ 'a.py:3: one',
        \ 'a.py: no line',
        \ ], s:file)
  call assert_equal({'skipped': 2, 'comments': [
        \ {'path': 'a.py', 'start': 3, 'end': 3, 'body': 'one'},
        \ ]}, review#read(s:file))
endfunction

function! s:test_write() abort
  call review#write(s:file, [
        \ {'path': 'a.py', 'start': 3, 'end': 3, 'body': 'one'},
        \ {'path': 'dir/b.vim', 'start': 5, 'end': 7, 'body': "two\n\nthree"},
        \ ])
  call assert_equal([
        \ 'a.py:3: one',
        \ 'dir/b.vim:5-7: two',
        \ "\t",
        \ "\tthree",
        \ ], readfile(s:file))
endfunction

let s:prefix = expand('<SID>') . 'test_'
let s:failed = 0
let s:names = []
for s:line in split(execute('function'), "\n")
  if stridx(s:line, 'function ' . s:prefix) == 0
    call add(s:names, matchstr(s:line, '^function \zs[^(]\+'))
  endif
endfor
for s:name in s:names
  let s:label = matchstr(s:name, 'test_\zs\w\+')
  if !empty($TEST) && s:label !~# $TEST
    continue
  endif
  call s:reset()
  let v:errors = []
  try
    call call(s:name, [])
  catch
    call add(v:errors, v:exception . ' @ ' . v:throwpoint)
  endtry
  if empty(v:errors)
    call add(s:out, 'ok   ' . s:label)
  else
    let s:failed += 1
    call add(s:out, 'FAIL ' . s:label)
    call extend(s:out, map(copy(v:errors), '"     " . v:val'))
  endif
endfor
call add(s:out, s:failed ? s:failed . ' failed' : 'all passed')
call writefile(s:out, '/dev/stdout')
call delete(s:tmp, 'rf')
execute 'cquit' (s:failed ? 1 : 0)
