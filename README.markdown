**This repository is only a mirror, all developpment happens at [gitlab](https://gitlab.com/dbeniamine/todo.txt-vim)**

# Todo.txt-vim

        #####                                                #     #
          #    ####  #####   ####     ##### #    # #####     #     # # #    #
          #   #    # #    # #    #      #    #  #    #       #     # # ##  ##
          #   #    # #    # #    #      #     ##     #   ### #     # # # ## #
          #   #    # #    # #    #      #     ##     #        #   #  # #    #
          #   #    # #    # #    # ##   #    #  #    #         # #   # #    #
          #    ####  #####   ####  ##   #   #    #   #          #    # #    #

                        Efficient Todo.txt management in vim

## Table of Contents

1. [Release notes](#release-notes)
2. [Introduction](#introduction)
    1. [Todo.txt rules](#todo.txt-rules)
    2. [Why this Fork ?](#Why-this-fork)
    3. [Installation](#installation)
3. [TodoTxt Files](#todotxt-files)
4. [Completion](#completion)
5. [Hierarchical Sort](#hierarchical-sort)
6. [Recurrence](#recurrence)
7. [Periodic and deferred tasks](#periodic-and-deferred-tasks)
8. [Mappings](#mappings)
    1. [Sort](#sort)
    2. [Priorities](#priorities)
    3. [Dates](#dates)
    4. [Done](#done)
    5. [In progress](#in-progress)
    6. [Repeat and defer](#repeat-and-defer)
9. [Highlighting](#highlighting)

## Release notes

+   V0.8.1 Incorporates yet another Fretep work : highlighting for tasks due today.

+   v0.8 Incorporates Fretep's work on overdue dates (PR#13 and PR#16) which
removes python dependency, allow to control the cursor position after a sort by
todo (see (sort)[#sort] and/or issue #15) and fixes bug when sorting a file
containing only lines with due:date (issue #14).

+   v0.7.6 Incorporates [Sietse's work](https://github.com/sietse/todo.txt-vim/commit/57d45200c8b033d31c9191ee0eb0711c801cdb1d) to make cancel and mark as done mapping repeatable using [vim-repeat](https://github.com/tpope/vim-repeat).
+   v0.7.5 Incorporates [Fievel's work](https://github.com/fievel/todo.txt-vim/commit/0863e1434e9a89ace06c4856b6cb32ba9906e3de) to make overduedates work on python3.
+   v0.7.4 includes the overduedate support from Guilherme Victal (see pull

    [request #45 on freitass version](https://github.com/freitass/todo.txt-vim/pull/45)),
    it highlight dates in overdue tasks as an Error. It depends on a
    Python library, however, and as such will only be able to work if your version
    of Vim was compiled with the `+python` option (as most common versions do).
 
    If your Vim installation does **not** have Python support, this plugin **will work just fine** but this feature will be disabled.


+   Since v0.7.3, `TodoComplete` is replaced by `todo#Complete`, you might need to update your vimrc (see [completion](#completion)).

## Introduction

Todo.txt-vim is a plugin to manage todo.txt files it was initially designed by
[Freitass](https://github.com/freitass/todo.txt-vim) then forked and improved
by David Beniamine.

### Todo.txt rules

Todo.txt is a standard human readable todo notes file defined [here](http://todotxt.com):

"The todo.txt format is a simple set of
[rules](https://github.com/todotxt/todotxt/)
that make todo.txt both human and machine-readable. The format supports
priorities, creation and completion dates, projects and contexts. That's
all you need to be productive. See an example Todo.txt file":

    (A) Call Mom @Phone +Family
    (A) Schedule annual checkup +Health
    (B) Outline chapter 5 +FamilyNovel @Computer
    (C) Add cover sheets @ComputerOffice +FamilyTPSReports
    Plan backyard herb garden @ComputerHome
    Pick up milk @ComputerGroceryStore
    Research self-publishing services +FamilyNovel @ComputerComputer
    x Download Todo.txt mobile app @ComputerPhone

### Why this fork ?

This plugin is a fork of [freitass
todo.txt-vim](https://github.com/freitass/todo.txt-vim). It add several cool
functionalities including:

+ [Hierarchical sort](#hierarchical-sort)
+ [A completion function](#completion)
+ [A proper handling of due dates](#dates)
+ [A Flexible file naming](#todotxt-files).
+ Syntax Highlight for couples key:value.
+ `<LocalLeader>x` is a toggle which allow you to unmark a task as done.
+ `<LocalLeader>C` Toggle Mark a task cancelled
+ If the current buffer is a done.txt file, the basic sort sorts on
  completion date.
+ ...

### Installation

Todo.txt-vim is a filetype plugin, make sure that your vimrc contains :

```vim
syntax on
filetype plugin on
```

#### Vizardry

If you have [Vizardry](https://github.com/dbeniamine/vizardry) installed,
you can run from vim:

    :Invoke -u dbeniamine todo.txt-vim

#### Pathogen install

    git clone https://github.com/dbeniamine/todo.txt-vim.git ~/.vim/bundle/todo.txt-vim

Then from vim: `:Helptags` to update the doc

#### Quick install

        git clone https://github.com/dbeniamine/todo.txt-vim.git
        cd todo.txt-vim
        cp -r ./* ~/.vim


If you want the help installed, run `:helptags ~/.vim/doc` inside vim after
having copied the files.  Then you will be able to get the commands help with:
`:h todo.txt`

## TodoTxt Files

This plugin provides flexible file naming for todo.txt, all the following
names are recognized as todo:

    YYYY-MM-[Tt]odo.txt
    YYYY-MM-DD[Tt]odo.txt
    [Tt]odo-YYYY-MM.txt
    [Tt]odo-YYYY-MM-DD.txt
    [Tt]odo.txt
    [Tt]oday.txt

And obviously the same are recognize as done:

    YYYY-MM-[Dd]one.txt
    YYYY-MM-DD[Dd]one.txt
    [Dd]one-YYYY-MM.txt
    [Dd]one-YYYY-MM-DD.txt
    [Dd]one.txt
    [Dd]one-[Tt]oday.txt

Moreover, `<LocalLeader>D` moves the task under the cursor to the done.txt
file corresponding to the current todo.txt, aka if you are editing
2015-07-07-todo.txt, the done file will be 2015-07-07-done.txt. If you don't
like this behavior, you can set the default done.txt name:

    let g:TodoTxtForceDoneName='done.txt'

## Completion

This plugin provides a nice complete function for project and context, to use
it add the following lines to your vimrc:

    " Use todo#Complete as the omni complete function for todo files
    au filetype todo setlocal omnifunc=todo#Complete

You can also start automatically the completion when entering '+' or '@' by
adding the next lines to your vimrc:

    " Auto complete projects
    au filetype todo imap <buffer> + +<C-X><C-O>

    " Auto complete contexts
    au filetype todo imap <buffer> @ @<C-X><C-O>


The `todo#Complete` function is designed to complete projects (starting by `+`)
and context (starting by `@`). If you use it on a regular word, it will do a
normal keyword completion (on all buffers).

If you try to complete a project, it will propose all projects in all open
buffers and for each of them, it will show their context and the name of the
buffers in which they appears in the preview window. It does the same thing
for context except that it gives in the preview the list of projects existing
in each existing contexts.

If you don't want the preview window to open when performing completion, add the
following lines to your vimrc:

    au filetype todo setlocal completeopt-=preview

If you would like the preview window to open even if there is only one match for
a completion, then add the following lines to your vimrc:

    au filetype todo setlocal completeopt+=menuone


## Hierarchical sort

This fork provides a hierarchical sorting function designed to do by project
and/or by context sorts and a priority sort.

`<LocalLeader>sc` : Sort the file by context then by priority
`<LocalLeader>scp` : Sort the file by context, project then by priority
`<LocalLeader>sp` : Sort the file by project then by priority
`<LocalLeader>spc` : Sort the file by project, context then by priority

The user can give argument for the two calls to vim sort function by changing
the following variables:

    g:Todo_txt_first_level_sort_mode
    g:Todo_txt_second_level_sort_mode

Defaults values are:


    g:Todo_txt_first_level_sort_mode="i"
    g:Todo_txt_second_level_sort_mode="i"


For more information on the available flags see `help :sort`

## Recurrence

By adding a `rec:` tag to your task, when you complete (`<LocalLeader>x`) or
postpone (`<LocalLeader>p`) the task, a new recurrence will be created due after
the specified amount of time.

The format is:
    `rec:[+][count][d|w|m|y]`

Where:
    d = days, w = weeks, m = months, y = years
    The optional `+` specifies strict recurrence (see below)

Examples:
    *   `rec:2w` - Recurs two weeks after the task is completed.
    *   `rec:3d` - Recurs three days after the task is completed.
    *   `rec:+1w` - Recurs one week from the due date (strict)

This is a non-standard but widely adopted keyword.

`rec:` copies the task as soon as you complete it. The `(P)` stubs below are a
different mechanism: they wait for their own moment.

## Periodic and deferred tasks

In this fork `(P)` is not a priority. A `(P)` line is a *stub*, parked at the
end of the active tasks, just before the `x ` block. You never do a stub: it
only says when the task has to come back into the `(B)` next actions list.

    (P) Pay the internet +home every:1m last:2026-09-01 rid:a1b2
    (P) Book a dentist appointment +health show:2026-10-14

The first one repeats, the second one is lifted once and then disappears. A
repeating stub has exactly one open instance among the ordinary tasks:

    (B) Pay the internet +home rid:a1b2

+ `every:` is the period of a repeating stub: `Nd`, `Nw`, `Nm` or `Ny`, the
  same units as the existing date arithmetic.
+ `last:` is the completion date of the latest instance. It is absent until the
  first instance is closed, and while it is missing no new instance is created.
+ `rid:` links an instance to its stub.
+ `show:` is the absolute date a one-shot stub is lifted on. The dialog accepts
  an interval counted from today (`2w`) or a date (`2026-10-14`).

The tags are deliberately not called `rec:`, so the existing behavior of
`rec:` on `<LocalLeader>x` and `<LocalLeader>p` is unchanged. The two
mechanisms must not be combined on one line: a `rec:` copy retains the
`rid:`, so it is a permanently open instance and the stub could never spawn
again. Repeat mode is therefore refused on a `rec:` line. Deferring one is
allowed: the lifted task then behaves the way `rec:` always did.

`<LocalLeader>r` asks two questions: repeat after every completion, or show
once later; then the interval, or the date for the one-shot case.

+ Repeat: the current line stays the open instance and gains `rid:`, and a
  `(P)` stub is appended at the end. On a line that already belongs to a
  series, or on its stub, the dialog only changes `every:`.
+ One shot: the current line leaves the working list, rewritten as `(P)` with
  `show:` and moved to the end.

An empty answer cancels. Completed and empty lines are left alone. Repeat mode
is refused on a one-shot `(P)` line and on a `rec:` line, one-shot mode on a
line that already belongs to a series. A date is refused unless it is a real
calendar day: `2026-99-99` would park a stub that can never come due.

Nothing happens when the file is opened. The check runs whenever a task
is completed, be it `<LocalLeader>x`, the `<LocalLeader>X` batch,
the `<LocalLeader>C` cancel or a `todo#MarkAsDone()` call; it never marks
a `(P)` line done and never lets one reach `done.txt`. It stamps `last:`
with today on the stub of the line being closed, then scans the stubs.
A stub whose moment has come gives one task: the stub text
without `every:`/`last:`/`show:`/`(P)`, with priority `(B)`, the same `rid:`
and today as creation date, projects and contexts kept. It is placed
at the start of the `(B)` list: before the first `(B)` task,
after the last `(A)` when there is no `(B)`, otherwise at the top
of the file. A due `show:` stub becomes that same `(B)` task and disappears.

A repeating stub rolls its `due:` forward by `every:` until the date
is no longer in the past, so an instance is never born overdue; a `due:`
more than a few thousand periods stale is dropped instead of kept.
The rolled date is written back onto the stub, so the stub and its instance
carry the same `due:`, and the next spawn rolls one period from there
instead of replaying the history of the series. A capped roll writes the
partially rolled date back: every capped spawn advances the stub by the cap,
so a stale series converges over a few spawns instead of re-paying the full
roll forever. A one-shot stub
has no period to roll by and keeps the `due:` as written, even a past one:
both dates were set knowingly, and seeing that the task is overdue is useful.

A second open instance is never created while one with the same `rid:` is
unfinished, and an overdue period does not pile up: the next countdown starts
from the actual completion. Stubs due at once are inserted as one block, in
their own order. `<LocalLeader>X` scans once after the whole batch. The cursor
stays on the line you just closed.

Cancelling (`<LocalLeader>C`) stamps `last:` too: it goes through the same
completion path, and the series continues. This is deliberate: if cancelling
did not stamp, cancelling the first instance would leave the stub without
`last:` at all, the period would have nothing to count from, and the series
would die silently.

Sorting parks the `(P)` lines at the tail of the active tasks, and
`<LocalLeader>j` / `<LocalLeader>k` do nothing on a stub.

## Mappings

By default todo-txt.vim sets all the mappings described in this section. To
prevent this behavior, add the following line to your vimrc

   let g:Todo_txt_do_not_map=1



`<LocalLeader>` is \  by default, so ̀`<LocaLeader>-s` means you type \s

### Sort

+ `<LocalLeader>s` : Sort the file by priority
+ `<LocalLeader>s+` : Sort the file on `+Projects`
+ `<LocalLeader>s@` : Sort the file on `@Contexts`
+ `<LocalLeader>sc` : Sort the file by context then by priority
+ `<LocalLeader>scp` : Sort the file by context, project then by priority
+ `<LocalLeader>sp` : Sort the file by project then by priority
+ `<LocalLeader>spc` : Sort the file by project, context then by priority
+ `<LocalLeader>sd` : Sort the file on due dates. Entries with a due date appear
sorted by at the beginning of the file, completed tasks are moved to the bottom and
the rest of the file is not modified.

When you sort by due dates, at the end of the sort, your cursor will be placed
at the top of the file. This behavior can be set with the following global
variable :

    let g:TodoTxtSortDueDateCursorPos = "top"

Possible values are :

+ `top` (default): The first line of the buffer, i.e. your most outstanding task
+ `lastdue`: The last task with a due:date set
+ `notoverdue`: The first task that is not overdue (requires #13)
+ `bottom`: The last line of the buffer

### Priorities

+ `<LocalLeader>j` : Lower the priority of the current line
+ `<LocalLeader>k` : Increase the priority of the current line
+ `<LocalLeader>a` : Add the priority (A) to the current line
+ `<LocalLeader>b` : Add the priority (B) to the current line
+ `<LocalLeader>c` : Add the priority (C) to the current line

`<LocalLeader>j` and `<LocalLeader>k` do nothing on a `(P)` line: a stub is not
a priority, and cycling the letter would turn the marker into `(O)` or `(Q)`.

### Dates

+ `<LocalLeader>d` : Insert the current date
+ `<LocalLeader>p` : Postpone the due date (accepts a count)
+ `<LocalLeader>P` : Decrement the due date (accepts a count)
+ `date<tab>`  : (Insert mode) Insert the current date
+ `due:`  : (Insert mode) Insert `due:` followed by the current date
+ `DUE:`  : (Insert mode) Insert `DUE:` followed by the current date

If you would like the creation date (today) prefixed on new lines, add the
following to your vimrc:

    let g:Todo_txt_prefix_creation_date=1

With insert mode maps on, typing `date<Tab>` or `due:` can feel like glitches
This is because vim wait for mappings before inserting the words to the buffer.
To prevent the glitches, abbreviations can be used instead of mappings.
To turn it on, add the following to your vimrc:

    let g:TodoTxtUseAbbrevInsertMode=1

Abbreviations uses word separator to expand the abbreviations, thus `<Tab>`
is unavailable on abbreviations. Turning abbreviations mode will change
`date<Tab>` mapping into `date:`. The resulting abbreviations would be: 

+    `date:`  : (Insert mode) Insert the current date
+    `due:`  : (Insert mode) Insert `due:` followed by the current date
+    `DUE:`  : (Insert mode) Insert `DUE:` followed by the current date


### Done


+ `<LocalLeader>x` : Toggle mark task as done (inserts or remove current
+ date as completion date)
+ `<LocalLeader>C` : Toggle mark task cancelled
+ `<LocalLeader>X` : Mark all tasks as completed
+ `<LocalLeader>D` : Move completed tasks to done file, see [TodoTxt
Files](#todotxt-files)

When you mark an item with a priority as done, it is assigned a priority tag
like `pri:A` so that the priority can be restored if the item is toggled back
to undone. If you don't want the tags showing up in your done file, you can
disable this behavior by setting the following global variable:

    let g:TodoTxtStripDoneItemPriority=1

A `(P)` line is never marked done, neither by `<LocalLeader>x` nor by
`<LocalLeader>X`, and never reaches the done file. Completing a task is what
triggers the periodic check instead, see
[Periodic and deferred tasks](#periodic-and-deferred-tasks).

### In progress

+ `<LocalLeader>w` : Toggle the `active:1` tag on the current line

The tag is todo.txt `key:value` metadata for work happening now. Several lines
may carry it at once, and it does not change the line's priority. A completed
line is left unchanged. Marking a line done removes the tag; toggling it back
to undone does not restore the tag.

### Repeat and defer

+ `<LocalLeader>r` : Repeat the current task after every completion, or park it
  as a one-shot `(P)` line shown again later

The dialog asks for the mode, then for the interval (`2w`, `10d`, `1m`, `1y`)
or, for the one-shot case, a date. An empty answer cancels. See
[Periodic and deferred tasks](#periodic-and-deferred-tasks).

### Format

+ `<LocalLeader>ff` : Try to fix todo.txt format

## Highlighting

Lines are colored by role, using highlight groups from the active colorscheme:

+ `(A)` is the watch list: work already started that you keep an eye on. Only the `(A)` mark uses `Todo` (the bright flag). The rest of the line uses `Constant`.
+ `(B)` is the list of next actions, drawn with `Function`.
+ `(C)`–`(Z)` are formulated tasks outside those two lists, drawn with `Type`. `P` is not one of them.
+ `(P)` is a periodic stub, not a priority. The whole line is dim, drawn with `Comment` (`TodoPeriodic`), so it does not look like a task you could do. `active:1` and completed lines still take precedence.
+ A line with no priority is an inbox item: not a task yet. It uses `Underlined` and italics.
+ A completed line (`x ...`) uses `Comment` for the whole line, so projects, contexts and dates fade with it.
+ A line with `active:1` is in progress, on top of its existing role. The whole line is black text on a lime-yellow background (`TodoActive`). A completed line stays `Comment` even if the tag is still there.

Priorities are recognized after an optional creation date (`2017-09-01 (A) ...`).

Override colors with `g:Todo_txt_highlight`. A value is a highlight group name or a dictionary of attributes (`guifg`, `guibg`, `ctermfg`, `ctermbg`, `gui`, `cterm`). Keys you omit keep the default. `InboxItalic` (default 1) adds italics on top of the inbox color. The `Periodic` key (default `Comment`) sets the color of `(P)` stubs.

```vim
let g:Todo_txt_highlight = {
  \ 'AMark': {'guifg': '#ffcc00', 'ctermfg': '220', 'gui': 'bold', 'cterm': 'bold'},
  \ 'Active': {'guifg': '#000000', 'guibg': '#D7FF00'},
  \ }
```

A colorscheme can define `TodoPriorityA` and the other `Todo*` groups itself. Those definitions stay unless the same key is set in `g:Todo_txt_highlight`.

## Fold

Todo.txt files can be folded by projects or context (see `:help fold`), by
default they are foldable by context, to use project fold :

    let g:Todo_fold_char='+'
