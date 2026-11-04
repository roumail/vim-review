# vim-review

The format review comments are kept in, as files, for the plugins that write
and read them: [fugitive-extras](https://github.com/roumail/fugitive-extras)
saves and loads your comments in it, and
[vim-prompts](https://github.com/roumail/vim-prompts) has the agent write its
comments in it. It has no commands.

```
src/app.py:12: could you check the None case here?
src/app.py:20-24: is this loop needed?
	It seems to repeat line 8.
```

One comment per line, `path:line: text` or `path:start-end: text`, the
further lines of a multi-line comment after it, tab-indented. Paths are
relative to a root the plugin using it decides (fugitive-extras: the work
tree).

## Functions

A comment is `{path, start, end, body}`: `start` and `end` are the first and
last line, the same for a single line, and `body` has its lines joined by
newlines.

| Function | What it does |
| --- | --- |
| `review#read(file)` | The comments in `file` as `{comments, skipped}`: `skipped` counts the non-blank lines that aren't in the format, which are left out. |
| `review#write(file, comments)` | Write `comments` to `file`, replacing it. |

## Install

```vim
Plug 'roumail/vim-review'
```

## Tests

```sh
vim -Nu NONE -i NONE -Es -S test/run.vim
```
