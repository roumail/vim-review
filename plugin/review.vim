" vim-review: review comments on lines and ranges, collected in their own
" quickfix list, saved and loaded back. Other plugins read them with
" review#list() and can say where comments go with review#use() (git-extras
" does, for git work trees). Commands and <Plug> mappings only; no keys are
" bound here.
if exists('g:loaded_review')
  finish
endif
let g:loaded_review = 1

" Comment on the line or range; prompts unless the comment is given. With !,
" write it in a buffer (:w adds it)
command! -bang -range -nargs=* Comment
      \ call review#{<bang>0 ? 'edit' : 'add'}(<line1>, <line2>, <q-args>)
" Open the 'Review' list
command! Comments call review#open()
" Write the comments to a file (default: a new timestamped save) and load
" them back (default: the latest save)
command! -nargs=? -complete=file CommentsSave call review#save(<q-args>)
command! -nargs=? -complete=customlist,review#complete_load CommentsLoad call review#load(<q-args>)

nnoremap <Plug>(review-comment) <Cmd>Comment<CR>
xnoremap <Plug>(review-comment) :Comment<CR>
nnoremap <Plug>(review-comment-edit) <Cmd>Comment!<CR>
xnoremap <Plug>(review-comment-edit) :Comment!<CR>
