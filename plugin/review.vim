" vim-review: review comments on lines and ranges, collected in their own
" quickfix list, saved and loaded back. Other plugins read them with
" review#list() and can say where comments go with review#use() (git-extras
" does, for git work trees). Commands and <Plug> mappings, and dd to delete
" comments in the 'Review' list's window; no other keys are bound here.
" Requires roumail/vim-draft, for :CommentDraft.
if exists('g:loaded_review')
  finish
endif
let g:loaded_review = 1

" Warns at startup when a required plugin isn't loaded (roumail/vim-requires)
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

" They leave :Comment on the command line to finish, as vim-prompts' :Ai;
" turning it into :CommentDraft takes the text to an editor
nnoremap <Plug>(review-comment) :<C-u>Comment<Space>
xnoremap <Plug>(review-comment) :Comment<Space>
nnoremap <Plug>(review-comment-draft) <Cmd>CommentDraft<CR>
xnoremap <Plug>(review-comment-draft) :CommentDraft<CR>

" dd and visual d delete comments in the 'Review' list's window, c changes one
augroup review
  autocmd!
  autocmd FileType qf nnoremap <buffer> <silent> c
        \ <Cmd>call review#change(line('.'), 'c')<CR>
  autocmd FileType qf nnoremap <buffer> <silent> dd
        \ <Cmd>call review#delete(line('.'), line('.') + v:count1 - 1, v:count1 . 'dd')<CR>
  autocmd FileType qf xnoremap <buffer> <silent> d
        \ :<C-u>call review#delete(line("'<"), line("'>"), 'gvd')<CR>
augroup END
