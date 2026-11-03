if exists('g:loaded_review')
  finish
endif
let g:loaded_review = 1

" roumail/vim-requires is optional
try
  call roumail_requires#check('vim-review', {
        \ 'roumail/vim-draft': 'g:loaded_roumail_draft',
        \ })
catch /^Vim\%((\a\+)\)\=:E117:/
endtry

" Comment on the line or range; prompts unless the comment is given
command! -range -nargs=* Comment call review#add(<line1>, <line2>, <q-args>)
" The same, written in a buffer (:w saves, closing it adds the comment)
command! -range -nargs=* CommentDraft call review#edit(<line1>, <line2>, <q-args>)
" Open the 'Review' list
command! Comments call review#open()
" Write the comments to a file (default: a new timestamped save) and load
" them back (default: the latest save)
command! -nargs=? -complete=file CommentsSave call review#save(<q-args>)
command! -nargs=? -complete=customlist,review#complete_load CommentsLoad call review#load(<q-args>)
" Empty the 'Review' list; saves are kept
command! CommentsClear call review#clear()

" They leave :Comment on the command line to finish; turning it into
" :CommentDraft takes the text to an editor
nnoremap <Plug>(review-comment) :<C-u>Comment<Space>
xnoremap <Plug>(review-comment) :Comment<Space>
nnoremap <Plug>(review-comment-draft) <Cmd>CommentDraft<CR>
xnoremap <Plug>(review-comment-draft) :CommentDraft<CR>

" c changes a comment in the 'Review' list's window
augroup review
  autocmd!
  autocmd FileType qf nnoremap <buffer> <silent> c
        \ <Cmd>call review#change(line('.'), 'c')<CR>
augroup END
