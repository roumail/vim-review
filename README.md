# vim-review

Review comments in Vim, on a line or a range of a file, collected in their own
quickfix list, saved and loaded back. Other plugins can
read them, e.g. to send them to an AI agent
([vim-prompts](https://github.com/roumail/vim-prompts)' `#comments`) or post
them as a pull request review
([git-extras](https://github.com/roumail/git-extras)' `:CommentsSubmit`).

Comments collect in a quickfix list titled `Review`, so they don't mix with
grep or diff results.

| Command | `<Plug>` mapping | What it does |
| --- | --- | --- |
| `:[range]Comment [text]` | `<Plug>(review-comment)` (normal and visual) | Add a comment on the line or range; prompts unless `text` is given. |
| `:[range]Comment! [text]` | `<Plug>(review-comment-edit)` (normal and visual) | Write the comment in a markdown buffer split below (`g:review_comment_height`, default 10), starting with `text` if given, for longer or multi-line comments. `:w` adds it, writing again updates it, `:q!` before writing drops it. |
| `:Comments` | | Open the `Review` list. |
| `:CommentsSave [file]` | | Write the comments, one per line, as `path:line: comment` or `path:start-end: comment`, the further lines of a multi-line comment after it, tab-indented. Without `file`, each save is a new file named for the time, `<YYYYmmdd-HHMMSS>.txt`, in the save directory. |
| `:CommentsLoad [file]` | | Replace the `Review` list with the comments in the file; without `file`, the latest save. `<Tab>` lists the saves, newest first, then files. |

Paths are relative to the current directory, and saves go in a directory per
current directory under `g:review_dir` (default `~/.vim/review`), unless a
provider says otherwise. With git-extras, paths are relative to the repo root
and saves are per branch in the git dir.

No keys are bound; bind the `<Plug>` mappings yourself, for example:

```vim
nmap <leader>cc <Plug>(review-comment)
xmap <leader>cc <Plug>(review-comment)
```

## For other plugins

| Function | What it does |
| --- | --- |
| `review#list()` | The comments as `{path, line, start_line?, body}`, `start_line` for a range. |
| `review#root()` | The directory those paths are relative to. |
| `review#clear()` | Empty the `Review` list. |
| `review#check()` | Warn when the unsaved comments are from another scope (e.g. branch) than now. |
| `review#use(provider)` | Say where comments go, for a kind of project. |

A provider is a dict of functions, each optional; one that returns empty falls
back to the default:

| Key | Returns | Default |
| --- | --- | --- |
| `root` | The directory comment paths are relative to. | The current directory. |
| `target` | The current buffer as `{'path': ...}` relative to `root`, or `{'error': ...}` saying why it takes no comments. | A file under `root`. |
| `save_dir` | Where saves go. | Under `g:review_dir`, one per `root`. |
| `scope` | What the comments are on, e.g. the branch. Comments left unsaved from another scope warn. | None. |

git-extras' provider is
[`autoload/git_extras/comments.vim`](https://github.com/roumail/git-extras/blob/main/autoload/git_extras/comments.vim).

## Install

No dependencies.

```vim
Plug 'roumail/vim-review'
```
