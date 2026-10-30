" Review comments live in their own quickfix list, titled 'Review', so they
" don't mix with grep or diff results. Each entry is a path, a line (or
" range) and the comment. Saved as `path:line: comment` or
" `path:start-end: comment`, one per line, with each further line of a
" multi-line comment after it, tab-indented. Beside it, `<file>.anchors` has
" each comment's lines and a few around them, as they were (JSON, one per
" line, not for reading). Loading finds the
" lines again when the file has changed since; a comment whose lines are
" gone stays at its saved line, marked W. The list's context is the scope
" (e.g. the branch) its unsaved comments are from, '' once saved.
"
" What paths are relative to, which buffers take comments, where saves go and
" the scope come from a provider (review#use()), e.g. git-extras' for git
" work trees. Without one, or where it returns empty, they are files under
" the current directory, saved in g:review_dir.

let s:title = 'Review'
let s:provider = {}
" An anchor keeps a comment's first s:anchor_lines lines, and s:context
" lines on either side
let s:anchor_lines = 20
let s:context = 2

function! s:error(msg) abort
  echohl ErrorMsg
  echomsg 'vim-review: ' . a:msg
  echohl None
endfunction

" Public: sets the provider, a dict of functions, each optional; one that
" returns empty falls back to the default:
"   root()      the directory comment paths are relative to
"   target()    the current buffer as {'path': relative to root()}, or
"               {'error': why it takes no comments}
"   save_dir()  the directory saves go in
"   scope()     what the comments are on (e.g. the branch); unsaved ones
"               from another scope warn
function! review#use(provider) abort
  let s:provider = a:provider
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

" One directory per root, named for its path, as 'undodir' names files
function! s:default_save_dir() abort
  return get(g:, 'review_dir', expand('~/.vim/review')) . '/'
        \ . substitute(fnamemodify(review#root(), ':p:h'), '/', '%', 'g')
endfunction

function! s:default_scope() abort
  return ''
endfunction

" The provider's name() if it has one and it returns something, else the default
function! s:call(name) abort
  let l:value = has_key(s:provider, a:name) ? s:provider[a:name]() : ''
  return empty(l:value) ? function('s:default_' . a:name)() : l:value
endfunction

" Public: the directory comment paths are relative to
function! review#root() abort
  return s:call('root')
endfunction

" The root, ending in /
function! s:prefix() abort
  return substitute(review#root(), '/\=$', '/', '')
endfunction

" The id of the 'Review' quickfix list, 0 if there is none
function! s:find_id() abort
  for l:nr in range(1, getqflist({'nr': '$'}).nr)
    let l:info = getqflist({'nr': l:nr, 'title': 1, 'id': 0})
    if l:info.title ==# s:title
      return l:info.id
    endif
  endfor
  return 0
endfunction

" The id of the 'Review' quickfix list, created if missing
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

" Public: warns when the unsaved comments are from another scope than now
function! review#check() abort
  let l:id = s:find_id()
  let l:scope = l:id ? getqflist({'id': l:id, 'context': 0}).context : ''
  if type(l:scope) == v:t_string && !empty(l:scope) && l:scope !=# s:call('scope')
    echohl WarningMsg
    echomsg 'vim-review: unsaved review comments from ' . l:scope . ' (:CommentsSave)'
    echohl None
  endif
endfunction

" The quickfix item (without text) for a comment on lines line1-line2 of the
" current buffer, and its `path:line` or `path:start-end` label; {} when the
" buffer can't take comments
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
  let l:range = a:line1 == a:line2 ? a:line1 : a:line1 . '-' . a:line2
  return {'item': l:item, 'label': l:target.path . ':' . l:range}
endfunction

" Appends the item to the 'Review' list; returns its index in the list
function! s:append(item) abort
  call setqflist([], 'a', {'id': s:list_id(), 'items': [a:item],
        \ 'context': s:call('scope')})
  return len(s:items()) - 1
endfunction

" Text typed at the prompt and left with <Esc>, by label, to start from when
" commenting on those lines again
let s:unsent = {}

" Prompts for the comment unless text is given
function! review#add(line1, line2, text) abort
  let l:target = s:target(a:line1, a:line2)
  if empty(l:target)
    return
  endif
  let l:text = empty(a:text) ? s:prompt(l:target.label) : a:text
  if empty(l:text)
    return
  endif
  call s:append(extend(l:target.item, {'text': l:text}))
  redraw
  echo 'Review comments: ' . len(s:items())
endfunction

" The comment typed at the prompt; '' when left. What was typed is kept for
" the next prompt on those lines, so you can look something up and go on.
function! s:prompt(label) abort
  let s:typed = get(s:unsent, a:label, '')
  " CmdlineLeave is too late: <Esc> has emptied the line by then
  augroup review_prompt
    autocmd!
    autocmd CmdlineChanged @ let s:typed = getcmdline()
  augroup END
  try
    let l:text = input('Comment ' . a:label . ': ', s:typed)
  finally
    autocmd! review_prompt
  endtry
  if !empty(l:text) || empty(s:typed)
    silent! call remove(s:unsent, a:label)
  else
    let s:unsent[a:label] = s:typed
    redraw
    echo 'Comment kept: :Comment or :CommentDraft on ' . a:label . ' goes on from it'
  endif
  return l:text
endfunction

" Writes the comment in a buffer instead of at the prompt, for longer or
" multi-line ones: a draft (roumail/vim-draft) below, starting with the text
" if given, else with what was left at the :Comment prompt on these lines.
" Closing it adds the comment last saved.
function! review#edit(line1, line2, text) abort
  let l:target = s:target(a:line1, a:line2)
  if empty(l:target)
    return
  endif
  " Else what was typed at the :Comment prompt on these lines and left
  let l:text = empty(a:text) ? get(s:unsent, l:target.label, '') : a:text
  silent! call remove(s:unsent, l:target.label)
  call roumail_draft#open('review://comment/' . l:target.label,
        \ empty(l:text) ? [] : [l:text], function('s:add_comment', [l:target.item]),
        \ {'split': 'belowright ' . get(g:, 'review_comment_height', 10) . 'new',
        \  'saved': 'Comment saved: closing adds it',
        \  'empty': 'Comment empty: closing adds nothing'})
  setlocal filetype=markdown
  startinsert!
endfunction

" Adds the comment once its draft closes
function! s:add_comment(item, text) abort
  call s:append(extend(copy(a:item), {'text': a:text}))
  echo 'Review comments: ' . len(s:items())
endfunction

function! review#open() abort
  let l:nr = getqflist({'id': s:list_id(), 'nr': 0}).nr
  execute 'silent chistory' l:nr
  copen
endfunction

" dd and visual d in a quickfix window: delete the comments on lines
" line1-line2 when it shows the 'Review' list, otherwise do what keys do
function! review#delete(line1, line2, keys) abort
  let l:id = s:find_id()
  if getwininfo(win_getid())[0].loclist || getqflist({'id': 0}).id != l:id || !l:id
    execute 'normal!' a:keys
    return
  endif
  let l:items = s:items()
  if empty(l:items)
    return
  endif
  call remove(l:items, a:line1 - 1, min([a:line2, len(l:items)]) - 1)
  call setqflist([], 'r', {'id': l:id, 'items': l:items,
        \ 'idx': max([1, min([a:line1, len(l:items)])])})
  call cursor(a:line1, 1)
  echo 'Review comments: ' . len(l:items)
endfunction

" Comments as {path, line, start_line?, body}, paths relative to the root
function! s:comments() abort
  let l:prefix = s:prefix()
  let l:comments = []
  for l:item in s:items()
    let l:file = fnamemodify(bufname(l:item.bufnr), ':p')
    let l:comment = {'path': stridx(l:file, l:prefix) == 0 ? l:file[len(l:prefix):] : l:file,
          \ 'line': l:item.lnum, 'body': l:item.text}
    if get(l:item, 'end_lnum', 0) > l:item.lnum
      let l:comment.start_line = l:item.lnum
      let l:comment.line = l:item.end_lnum
    endif
    if l:item.type ==# 'W'
      let l:comment.orphaned = 1
    endif
    call add(l:comments, l:comment)
  endfor
  return l:comments
endfunction

" Public: the comments as {path, line, start_line?, body, orphaned?}, paths
" relative to review#root(), for other plugins (e.g. to send them to an AI
" agent). orphaned: its lines weren't found when it was loaded, so it is at
" its saved line, which may be another one now.
function! review#list() abort
  return s:find_id() ? s:comments() : []
endfunction

" Public: empty the 'Review' list
function! review#clear() abort
  call setqflist([], 'r', {'id': s:list_id(), 'items': [], 'context': ''})
endfunction

" The buffer's lines: the buffer's own if loaded (unsaved edits too), else
" its file's; [] when it has neither
function! s:lines(bufnr) abort
  if bufloaded(a:bufnr)
    return getbufline(a:bufnr, 1, '$')
  endif
  let l:file = fnamemodify(bufname(a:bufnr), ':p')
  return filereadable(l:file) ? readfile(l:file) : []
endfunction

" What the comment on lines first-last is on, to find it again once the
" file changes: {lines, before, after}, {} when the lines aren't there
function! s:anchor(lines, first, last) abort
  let l:first = a:first - 1
  if l:first < 0 || l:first >= len(a:lines)
    return {}
  endif
  let l:last = min([max([a:last, a:first]) - 1, l:first + s:anchor_lines - 1])
  return {'lines': a:lines[l:first : l:last],
        \ 'before': l:first > 0 ? a:lines[max([0, l:first - s:context]) : l:first - 1] : [],
        \ 'after': a:lines[l:last + 1 : l:last + s:context]}
endfunction

" How many of the anchor's lines around it match at index i of lines
function! s:context_score(lines, i, n, anchor) abort
  let l:score = 0
  let l:before = a:anchor.before
  for l:k in range(len(l:before))
    let l:j = a:i - len(l:before) + l:k
    let l:score += l:j >= 0 && l:j < len(a:lines) && a:lines[l:j] ==# l:before[l:k]
  endfor
  let l:after = a:anchor.after
  for l:k in range(len(l:after))
    let l:j = a:i + a:n + l:k
    let l:score += l:j < len(a:lines) && a:lines[l:j] ==# l:after[l:k]
  endfor
  return l:score
endfunction

" The line the anchor's lines start on in lines, 0 when they're gone. Where
" they appear more than once, the one with the most matching lines around
" it, then the nearest to lnum. Leading and trailing white space is ignored,
" so reindenting doesn't lose a comment.
function! s:find(lines, anchor, lnum) abort
  let l:anchor = map(copy(a:anchor), 'map(copy(v:val), "trim(v:val)")')
  let l:want = l:anchor.lines
  let l:n = len(l:want)
  if l:n == 0
    return 0
  endif
  let l:lines = map(copy(a:lines), 'trim(v:val)')
  let l:best = 0
  let l:best_score = 0
  for l:i in range(len(l:lines) - l:n + 1)
    if l:lines[l:i] !=# l:want[0] || l:lines[l:i : l:i + l:n - 1] !=# l:want
      continue
    endif
    " More matching context wins; the distance only breaks ties
    let l:score = s:context_score(l:lines, l:i, l:n, l:anchor) * 1000000
          \ - abs(l:i + 1 - a:lnum)
    if !l:best || l:score > l:best_score
      let l:best = l:i + 1
      let l:best_score = l:score
    endif
  endfor
  return l:best
endfunction

" Moves the loaded comments to where their anchored lines are now (anchors
" lines up with the list, {} for a comment saved without one). One whose
" lines are gone keeps its line, is marked W and keeps its anchor for the
" next save. Returns [moved, not found].
function! s:reanchor(anchors) abort
  let l:items = s:items()
  let l:files = {}
  let l:moved = 0
  let l:lost = 0
  for l:i in range(len(l:items))
    let l:anchor = get(a:anchors, l:i, {})
    if empty(l:anchor)
      continue
    endif
    let l:item = l:items[l:i]
    if !has_key(l:files, l:item.bufnr)
      let l:files[l:item.bufnr] = s:lines(l:item.bufnr)
    endif
    let l:lnum = s:find(l:files[l:item.bufnr], l:anchor, l:item.lnum)
    if !l:lnum
      let l:item.type = 'W'
      let l:item.user_data = {'anchor': l:anchor}
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
  return [l:moved, l:lost]
endfunction

" The given file, else a new save, timestamped so they sort
function! s:save_file(file) abort
  if !empty(a:file)
    return fnamemodify(a:file, ':p')
  endif
  return s:call('save_dir') . '/' . strftime('%Y%m%d-%H%M%S') . '.txt'
endfunction

" The save names (<time>.txt), newest first
function! s:saves() abort
  return reverse(sort(map(glob(s:call('save_dir') . '/*.txt', 1, 1),
        \ 'fnamemodify(v:val, ":t")')))
endfunction

" The given file, else the latest save ('' when there is none). A bare save
" name, as completed, is one of the saves.
function! s:load_file(file) abort
  if index(s:saves(), a:file) >= 0
    return s:call('save_dir') . '/' . a:file
  elseif !empty(a:file)
    return fnamemodify(a:file, ':p')
  endif
  let l:saves = s:saves()
  return empty(l:saves) ? '' : s:call('save_dir') . '/' . l:saves[0]
endfunction

" The saves, newest first; files once the arg looks like a path
function! review#complete_load(lead, cmdline, pos) abort
  if a:lead =~# '[/~.]'
    return getcompletion(a:lead, 'file')
  endif
  return filter(s:saves(), 'stridx(v:val, a:lead) == 0')
        \ + getcompletion(a:lead, 'file')
endfunction

function! review#save(file) abort
  let l:file = s:save_file(a:file)
  let l:items = s:items()
  let l:comments = s:comments()
  let l:files = {}
  let l:lines = []
  let l:anchors = []
  for l:i in range(len(l:comments))
    let l:c = l:comments[l:i]
    let l:item = l:items[l:i]
    let l:body = split(l:c.body, "\n", 1)
    let l:key = l:c.path . ':'
          \ . (has_key(l:c, 'start_line') ? l:c.start_line . '-' : '') . l:c.line
    call add(l:lines, l:key . ': ' . l:body[0])
    call extend(l:lines, map(l:body[1:], '"\t" . v:val'))
    " An orphaned comment keeps the anchor it was loaded with: its lines
    " may come back, and those at its line now aren't its
    let l:anchor = get(get(l:item, 'user_data', {}), 'anchor', {})
    if l:item.type !=# 'W' || empty(l:anchor)
      if !has_key(l:files, l:item.bufnr)
        let l:files[l:item.bufnr] = s:lines(l:item.bufnr)
      endif
      let l:anchor = s:anchor(l:files[l:item.bufnr], l:item.lnum, l:item.end_lnum)
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

" Replaces the 'Review' list with the comments in the file
function! review#load(file) abort
  let l:file = s:load_file(a:file)
  if empty(l:file)
    let l:scope = s:call('scope')
    call s:error('no saved comments' . (empty(l:scope) ? '' : ' for ' . l:scope))
    return
  endif
  if !filereadable(l:file)
    call s:error('no review file ' . fnamemodify(l:file, ':~'))
    return
  endif
  let l:prefix = s:prefix()
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
    " A tab-indented line continues the previous comment
    if l:line[0] ==# "\t" && !empty(l:items)
      let l:items[-1].text .= "\n" . l:line[1:]
      continue
    endif
    " An anchor inline, as saves had them before <file>.anchors
    if l:line =~# '^@anchor '
      continue
    endif
    let l:m = matchlist(l:line, '^\(.\{-}\):\(\d\+\)\%(-\(\d\+\)\)\=: \(.*\)$')
    if empty(l:m)
      continue
    endif
    let l:item = {'filename': l:prefix . l:m[1],
          \ 'lnum': str2nr(l:m[2]), 'text': l:m[4]}
    if !empty(l:m[3])
      let l:item.end_lnum = str2nr(l:m[3])
    endif
    call add(l:items, l:item)
    let l:key = l:m[1] . ':' . l:m[2] . (empty(l:m[3]) ? '' : '-' . l:m[3])
    let l:found = get(l:sidecar, l:key, [])
    call add(l:anchors, empty(l:found) ? {} : remove(l:found, 0))
  endfor
  call setqflist([], 'r', {'id': s:list_id(), 'items': l:items, 'context': ''})
  let [l:moved, l:lost] = s:reanchor(l:anchors)
  call review#open()
  redraw
  echo 'Review comments: ' . len(l:items)
        \ . (l:moved ? ', ' . l:moved . ' moved to where their lines are now' : '')
        \ . (l:lost ? ', ' . l:lost . ' whose lines are gone (W)' : '')
endfunction
