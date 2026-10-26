" vim-review: review comments on lines and ranges, collected in their own
" quickfix list, saved and loaded back. Other plugins read them with
" review#list() and can say where comments go with review#use() (git-extras
" does, for git work trees). Commands and <Plug> mappings, and dd to delete
" comments in the 'Review' list's window; no other keys are bound here.
if exists('g:loaded_review')
  finish
endif
let g:loaded_review = 1

" Comment on the line or range; prompts unless the comment is given
command! -range -nargs=* Comment call review#add(<line1>, <line2>, <q-args>)
" The same, written in a buffer (:w adds it)
command! -range -nargs=* CommentDraft call review#edit(<line1>, <line2>, <q-args>)
" Open the 'Review' list
command! Comments call review#open()
" Write the comments to a file (default: a new timestamped save) and load
" them back (default: the latest save)
command! -nargs=? -complete=file CommentsSave call review#save(<q-args>)
command! -nargs=? -complete=customlist,review#complete_load CommentsLoad call review#load(<q-args>)

nnoremap <Plug>(review-comment) <Cmd>Comment<CR>
xnoremap <Plug>(review-comment) :Comment<CR>
nnoremap <Plug>(review-comment-draft) <Cmd>CommentDraft<CR>
xnoremap <Plug>(review-comment-draft) :CommentDraft<CR>

" dd and visual d delete comments in the 'Review' list's window
augroup review
  autocmd!
  autocmd FileType qf nnoremap <buffer> <silent> dd
        \ <Cmd>call review#delete(line('.'), line('.') + v:count1 - 1, v:count1 . 'dd')<CR>
  autocmd FileType qf xnoremap <buffer> <silent> d
        \ :<C-u>call review#delete(line("'<"), line("'>"), 'gvd')<CR>
augroup END
