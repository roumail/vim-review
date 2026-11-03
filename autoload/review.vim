let s:title = 'Review'
let s:context = 2

function! s:error(msg) abort
  echohl ErrorMsg
  echomsg 'vim-review: ' . a:msg
  echohl None
endfunction

function! s:default_root() abort
  return getcwd()
endfunction

function! s:default_target() abort
  let l:prefix = s:prefix()
  let l:file = expand('%:p')
  if !empty(&buftype) || empty(l:file) || stridx(l:file, l:prefix) != 0
    return {'error': 'not a file under ' . fnamemodify(l:prefix, ':~')}
  endif
  return {'path': l:file[len(l:prefix):]}
endfunction

function! s:default_save_dir() abort
  " Named for the root's path, as 'undodir' names files
  return get(g:, 'review_dir', expand('~/.vim/review')) . '/'
        \ . substitute(fnamemodify(review#root(), ':p:h'), '/', '%', 'g')
endfunction

function! s:default_scope() abort
  return ''
endfunction

function! s:call(name) abort
  let l:provider = get(g:, 'review_provider', {})
  let l:value = has_key(l:provider, a:name) ? l:provider[a:name]() : ''
  return empty(l:value) ? function('s:default_' . a:name)() : l:value
endfunction

function! review#root() abort
  return s:call('root')
endfunction

function! s:prefix() abort
  return substitute(review#root(), '/\=$', '/', '')
endfunction

function! s:find_id() abort
  for l:nr in range(1, getqflist({'nr': '$'}).nr)
    let l:info = getqflist({'nr': l:nr, 'title': 1, 'id': 0})
    if l:info.title ==# s:title
      return l:info.id
    endif
  endfor
  return 0
endfunction

function! s:list_id() abort
  let l:id = s:find_id()
  if l:id
    return l:id
  endif
  " Without 'items', ' ' would only retitle the current list
  call setqflist([], ' ', {'title': s:title, 'items': []})
  return getqflist({'nr': '$', 'id': 0}).id
endfunction

function! s:items() abort
  return getqflist({'id': s:list_id(), 'items': 1}).items
endfunction

function! review#check() abort
  let l:id = s:find_id()
  let l:scope = l:id ? getqflist({'id': l:id, 'context': 0}).context : ''
  if type(l:scope) == v:t_string && !empty(l:scope) && l:scope !=# s:call('scope')
    echohl WarningMsg
    echomsg 'vim-review: unsaved review comments from ' . l:scope . ' (:CommentsSave)'
    echohl None
  endif
endfunction

function! s:target(line1, line2) abort
  call review#check()
  let l:target = s:call('target')
  if has_key(l:target, 'error')
    call s:error(l:target.error)
    return {}
  endif
  let l:item = {'filename': s:prefix() . l:target.path, 'lnum': a:line1}
  if a:line2 != a:line1
    let l:item.end_lnum = a:line2
  endif
  return {'item': l:item,
        \ 'label': l:target.path . ':' . a:line1 . (a:line1 == a:line2 ? '' : '-' . a:line2)}
endfunction

function! s:append(item) abort
  call setqflist([], 'a', {'id': s:list_id(), 'items': [a:item],
        \ 'context': s:call('scope')})
  return len(s:items()) - 1
endfunction

let s:unsent = {}

function! review#add(line1, line2, text) abort
  let l:target = s:target(a:line1, a:line2)
  if empty(l:target)
    return
  endif
  let l:text = a:text
  if empty(l:text)
    " Kept for the next prompt on those lines, so you can look something up and
    " go on
    let s:typed = get(s:unsent, l:target.label, '')
    " CmdlineLeave is too late: <Esc> has emptied the line by then
    augroup review_prompt
      autocmd!
      autocmd CmdlineChanged @ let s:typed = getcmdline()
    augroup END
    try
      let l:text = input('Comment ' . l:target.label . ': ', s:typed)
    finally
      autocmd! review_prompt
    endtry
    if !empty(l:text) || empty(s:typed)
      silent! call remove(s:unsent, l:target.label)
    else
      let s:unsent[l:target.label] = s:typed
      redraw
      echo 'Comment kept: :Comment or :CommentDraft on ' . l:target.label . ' goes on from it'
    endif
    if empty(l:text)
      return
    endif
  endif
  call s:append(extend(l:target.item, {'text': l:text}))
  redraw
  echo 'Review comments: ' . len(s:items())
endfunction

function! review#edit(line1, line2, text) abort
  let l:target = s:target(a:line1, a:line2)
  if empty(l:target)
    return
  endif
  let l:text = empty(a:text) ? get(s:unsent, l:target.label, '') : a:text
  silent! call remove(s:unsent, l:target.label)
  call s:draft(l:target.label, empty(l:text) ? [] : [l:text],
        \ function('s:add_comment', [l:target.item]), 'adds')
  startinsert!
endfunction

function! s:draft(label, lines, OnClose, verb) abort
  call roumail_draft#open('review://comment/' . a:label, a:lines, a:OnClose,
        \ {'split': 'belowright ' . get(g:, 'review_comment_height', 10) . 'new',
        \  'saved': 'Comment saved: closing ' . a:verb . ' it',
        \  'empty': 'Comment empty: closing ' . a:verb . ' nothing'})
  setlocal filetype=markdown
endfunction

function! s:add_comment(item, text) abort
  call s:append(extend(copy(a:item), {'text': a:text}))
  echo 'Review comments: ' . len(s:items())
endfunction

function! s:shown_list_id() abort
  let l:id = s:find_id()
  return !getwininfo(win_getid())[0].loclist && getqflist({'id': 0}).id == l:id ? l:id : 0
endfunction

function! review#change(lnum, keys) abort
  if !s:shown_list_id()
    execute 'normal!' a:keys
    return
  endif
  let l:items = s:items()
  if a:lnum > len(l:items)
    return
  endif
  let l:item = l:items[a:lnum - 1]
  call s:draft(fnamemodify(bufname(l:item.bufnr), ':~:.') . ':' . l:item.lnum
        \ . (get(l:item, 'end_lnum', 0) > l:item.lnum ? '-' . l:item.end_lnum : ''),
        \ split(l:item.text, "\n", 1),
        \ function('s:change_comment', [l:item]), 'changes')
endfunction

function! s:change_comment(item, text) abort
  let l:items = s:items()
  let l:i = index(l:items, a:item)
  if l:i < 0
    " Deleted meanwhile: added back rather than lose the text
    call s:append(extend(copy(a:item), {'text': a:text}))
    echo 'Comment no longer in the list: added again, changed'
    return
  endif
  let l:items[l:i].text = a:text
  call setqflist([], 'r', {'id': s:find_id(), 'items': l:items, 'idx': l:i + 1})
  echo 'Comment changed'
endfunction

function! review#open() abort
  execute 'silent chistory' getqflist({'id': s:list_id(), 'nr': 0}).nr
  copen
endfunction

" Comments as {path, line, start_line?, body}, paths relative to the root
function! s:comments() abort
  let l:prefix = s:prefix()
  let l:comments = []
  for l:item in s:items()
    let l:file = fnamemodify(bufname(l:item.bufnr), ':p')
    let l:comment = {'path': stridx(l:file, l:prefix) == 0 ? l:file[len(l:prefix):] : l:file,
          \ 'start': l:item.lnum, 'end': max([l:item.lnum, get(l:item, 'end_lnum', 0)]),
          \ 'body': l:item.text}
    if l:item.type ==# 'W'
      let l:comment.orphaned = 1
    endif
    call add(l:comments, l:comment)
  endfor
  return l:comments
endfunction

function! review#list() abort
  return s:find_id() ? s:comments() : []
endfunction

function! review#clear() abort
  call setqflist([], 'r', {'id': s:list_id(), 'items': [], 'context': ''})
endfunction

function! s:lines(bufnr) abort
  if bufloaded(a:bufnr)
    return getbufline(a:bufnr, 1, '$')
  endif
  let l:file = fnamemodify(bufname(a:bufnr), ':p')
  return filereadable(l:file) ? readfile(l:file) : []
endfunction

function! s:saves() abort
  return reverse(sort(map(glob(s:call('save_dir') . '/*.txt', 1, 1),
        \ 'fnamemodify(v:val, ":t")')))
endfunction

function! review#complete_load(lead, cmdline, pos) abort
  if a:lead =~# '[/~.]'
    return getcompletion(a:lead, 'file')
  endif
  return filter(s:saves(), 'stridx(v:val, a:lead) == 0')
        \ + getcompletion(a:lead, 'file')
endfunction

function! review#save(file) abort
  " Named for the time, so they sort
  let l:file = empty(a:file) ? s:call('save_dir') . '/' . strftime('%Y%m%d-%H%M%S') . '.txt'
        \ : fnamemodify(a:file, ':p')
  let l:items = s:items()
  let l:comments = s:comments()
  let l:files = {}
  let l:lines = []
  let l:anchors = []
  for l:i in range(len(l:comments))
    let l:c = l:comments[l:i]
    let l:item = l:items[l:i]
    let l:body = split(l:c.body, "\n", 1)
    let l:key = l:c.path . ':' . l:c.start . (l:c.end > l:c.start ? '-' . l:c.end : '')
    call add(l:lines, l:key . ': ' . l:body[0])
    call extend(l:lines, map(l:body[1:], '"\t" . v:val'))
    " An orphaned comment keeps the anchor it was loaded with: its lines
    " may come back, and those at its line now aren't its
    let l:anchor = get(get(l:item, 'user_data', {}), 'anchor', {})
    if l:item.type !=# 'W' || empty(l:anchor)
      if !has_key(l:files, l:item.bufnr)
        let l:files[l:item.bufnr] = s:lines(l:item.bufnr)
      endif
      let l:source = l:files[l:item.bufnr]
      let l:first = l:item.lnum - 1
      " Up to 20 of the comment's lines
      let l:last = min([max([l:item.end_lnum, l:item.lnum]) - 1, l:first + 19])
      let l:anchor = l:first < 0 || l:first >= len(l:source) ? {} : {
            \ 'lines': l:source[l:first : l:last],
            \ 'before': l:first > 0 ? l:source[max([0, l:first - s:context]) : l:first - 1] : [],
            \ 'after': l:source[l:last + 1 : l:last + s:context]}
    endif
    if !empty(l:anchor)
      call add(l:anchors, json_encode({'at': l:key, 'anchor': l:anchor}))
    endif
  endfor
  call mkdir(fnamemodify(l:file, ':h'), 'p')
  call writefile(l:lines, l:file)
  " The anchors are not for reading, so they go beside the comments
  if empty(l:anchors)
    call delete(l:file . '.anchors')
  else
    call writefile(l:anchors, l:file . '.anchors')
  endif
  call setqflist([], 'a', {'id': s:list_id(), 'context': ''})
  echo 'Saved ' . len(l:comments) . ' review comments to ' . fnamemodify(l:file, ':~')
endfunction

function! review#load(file) abort
  let l:saves = s:saves()
  let l:file = index(l:saves, a:file) >= 0 ? s:call('save_dir') . '/' . a:file
        \ : !empty(a:file) ? fnamemodify(a:file, ':p')
        \ : empty(l:saves) ? '' : s:call('save_dir') . '/' . l:saves[0]
  if empty(l:file)
    let l:scope = s:call('scope')
    call s:error('no saved comments' . (empty(l:scope) ? '' : ' for ' . l:scope))
    return
  endif
  if !filereadable(l:file)
    call s:error('no review file ' . fnamemodify(l:file, ':~'))
    return
  endif
  let l:items = []
  let l:anchors = []
  let l:sidecar = {}
  if filereadable(l:file . '.anchors')
    for l:json in readfile(l:file . '.anchors')
      try
        let l:entry = json_decode(l:json)
        let l:sidecar[l:entry.at] = get(l:sidecar, l:entry.at, []) + [l:entry.anchor]
      catch
        " Not an anchor: its comment loads where it was saved
      endtry
    endfor
  endif
  for l:line in readfile(l:file)
    if l:line[0] ==# "\t" && !empty(l:items)
      let l:items[-1].text .= "\n" . l:line[1:]
      continue
    endif
    let l:m = matchlist(l:line, '^\(.\{-}\):\(\d\+\)\%(-\(\d\+\)\)\=: \(.*\)$')
    if empty(l:m)
      continue
    endif
    let l:item = {'filename': s:prefix() . l:m[1],
          \ 'lnum': str2nr(l:m[2]), 'text': l:m[4]}
    if !empty(l:m[3])
      let l:item.end_lnum = str2nr(l:m[3])
    endif
    call add(l:items, l:item)
    let l:found = get(l:sidecar, l:m[1] . ':' . l:m[2] . (empty(l:m[3]) ? '' : '-' . l:m[3]), [])
    call add(l:anchors, empty(l:found) ? {} : remove(l:found, 0))
  endfor
  call setqflist([], 'r', {'id': s:list_id(), 'items': l:items, 'context': ''})

  let l:items = s:items()
  let l:trimmed = {}
  let [l:moved, l:lost] = [0, 0]
  for l:i in range(len(l:items))
    let l:saved = get(l:anchors, l:i, {})
    if empty(l:saved)
      continue
    endif
    let l:item = l:items[l:i]
    " Ignoring indentation, so reindenting doesn't lose a comment
    let l:anchor = map(copy(l:saved), 'map(copy(v:val), "trim(v:val)")')
    if !has_key(l:trimmed, l:item.bufnr)
      let l:trimmed[l:item.bufnr] = map(s:lines(l:item.bufnr), 'trim(v:val)')
    endif
    let l:lines = l:trimmed[l:item.bufnr]
    let l:n = len(l:anchor.lines)
    let [l:lnum, l:best] = [0, 0]
    for l:at in range(l:n ? max([0, len(l:lines) - l:n + 1]) : 0)
      if l:lines[l:at : l:at + l:n - 1] !=# l:anchor.lines
        continue
      endif
      let l:score = 0
      for l:k in range(len(l:anchor.before))
        let l:j = l:at - len(l:anchor.before) + l:k
        let l:score += l:j >= 0 && l:lines[l:j] ==# l:anchor.before[l:k]
      endfor
      for l:k in range(len(l:anchor.after))
        let l:j = l:at + l:n + l:k
        let l:score += l:j < len(l:lines) && l:lines[l:j] ==# l:anchor.after[l:k]
      endfor
      " More matching context wins; the distance only breaks ties
      let l:score = l:score * 1000000 - abs(l:at + 1 - l:item.lnum)
      if !l:lnum || l:score > l:best
        let [l:lnum, l:best] = [l:at + 1, l:score]
      endif
    endfor
    if !l:lnum
      let l:item.type = 'W'
      let l:item.user_data = {'anchor': l:saved}
      let l:lost += 1
    elseif l:lnum != l:item.lnum
      if l:item.end_lnum > 0
        let l:item.end_lnum += l:lnum - l:item.lnum
      endif
      let l:item.lnum = l:lnum
      let l:moved += 1
    endif
  endfor
  call setqflist([], 'r', {'id': s:list_id(), 'items': l:items})

  call review#open()
  redraw
  echo 'Review comments: ' . len(l:items)
        \ . (l:moved ? ', ' . l:moved . ' moved to where their lines are now' : '')
        \ . (l:lost ? ', ' . l:lost . ' whose lines are gone (W)' : '')
endfunction
