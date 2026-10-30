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
| `:[range]Comment [text]` | `<Plug>(review-comment)` (normal and visual), which leaves `:Comment ` on the command line to finish | Add a comment on the line or range; prompts unless `text` is given. Leaving the prompt with `<Esc>` keeps what you typed: `:Comment` or `:CommentDraft` on the same lines goes on from it. |
| `:[range]CommentDraft [text]` | `<Plug>(review-comment-draft)` (normal and visual) | Write the comment in a markdown buffer split below (`g:review_comment_height`, default 10), starting with `text` if given, else with what you left at the `:Comment` prompt on those lines, for longer or multi-line comments. As a git commit message: `:w` saves, closing the buffer (`:wq`, or `:q` after `:w`) adds the comment last saved, and an empty one or `:q!` before any `:w` drops it. Closing it never quits Vim, even with `:only`. |
| `:Comments` | | Open the `Review` list. In it, `dd` deletes the comment on the line (`3dd` three of them) and `d` in visual mode those selected. |
| `:CommentsSave [file]` | | Write the comments, one per line, as `path:line: comment` or `path:start-end: comment`, the further lines of a multi-line comment after it, tab-indented. Its [anchors](#anchors) go in `<file>.anchors` beside it, so the file reads as plain comments. Without `file`, each save is a new file named for the time, `<YYYYmmdd-HHMMSS>.txt`, in the save directory. |
| `:CommentsLoad [file]` | | Replace the `Review` list with the comments in the file, each moved to where its lines are now; without `file`, the latest save. `<Tab>` lists the saves, newest first, then files. |
| `:CommentsClear` | | Empty the `Review` list, as quitting Vim would. Saves are kept, so `:CommentsLoad` brings them back. |

Paths are relative to the current directory, and saves go in a directory per
current directory under `g:review_dir` (default `~/.vim/review`), unless a
provider says otherwise. With git-extras, paths are relative to the repo root
and saves are per branch in the git dir.

## Anchors

While a file is open, its comments move with your edits, as quickfix entries
do. A save can be loaded after the file changed outside Vim, though (a `git
pull`, a rebase, an agent's edit), so each comment is saved with an anchor:
a line of JSON in `<file>.anchors` with its lines (up to 20) and the 2 on either side.

`:CommentsLoad` looks for those lines, ignoring indentation, and moves the
comment to them. Where they appear more than once, it takes the place with
the most matching lines around it, then the nearest to the saved line. A
comment whose lines are gone stays at its saved line, marked `W` in
`:Comments`, and keeps its anchor through later saves, so it is found again if
its lines come back.

To take a comment you're typing to an editor, change `Comment` to
`CommentDraft` on the command line (`<C-b>` goes to its start) and press
Enter: the draft starts with your text. A command line left with `<Esc>` is
in the history, so `:<Up>` gets it back after you look something up.

Apart from `dd` in the `Review` list, no keys are bound; bind the `<Plug>`
mappings yourself, for example:

```vim
nmap <leader>cc <Plug>(review-comment)
xmap <leader>cc <Plug>(review-comment)
```

## For other plugins

| Function | What it does |
| --- | --- |
| `review#list()` | The comments as `{path, line, start_line?, body, orphaned?}`: `start_line` for a range, `orphaned` when its lines weren't found on load. |
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

Requires [vim-draft](https://github.com/roumail/vim-draft): the buffer
`:CommentDraft` writes in.

```vim
Plug 'roumail/vim-draft'
Plug 'roumail/vim-requires'  " optional: the startup warning
Plug 'roumail/vim-review'
```

With [vim-requires](https://github.com/roumail/vim-requires), Vim shows
`vim-review: requires …` at startup when it isn't loaded.
