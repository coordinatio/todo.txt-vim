" File:        autoload/todo.vim
" Description: Todo.txt sorting plugin
" Author:      David Beniamine <david@beniamine.net>, Peter (fretep) <githib.5678@9ox.net>
" Licence:     Vim licence
" Website:     http://github.com/dbeniamine/todo.txt.vim

" These two variables are parameters for the successive calls the vim sort
"   '' means no flags
"   '! i' means reverse and ignore case
"   for more information on flags, see :help sort
if (! exists("g:Todo_txt_first_level_sort_mode"))
    let g:Todo_txt_first_level_sort_mode='i'
endif
if (! exists("g:Todo_txt_second_level_sort_mode"))
    let g:Todo_txt_second_level_sort_mode='i'
endif
if (! exists("g:Todo_txt_third_level_sort_mode"))
    let g:Todo_txt_third_level_sort_mode='i'
endif


" Functions {{{1


function! todo#GetCurpos()
    if exists("*getcurpos")
        return getcurpos()
    endif
        return getpos('.')
endfunction

function! todo#PrioritizeIncrease()
    " A (P) stub is not a priority: raising it would turn the marker into (Q)
    " and the stub would stop being a stub.
    if todo#IsStub(getline('.'))
        return
    endif
    normal! 0f)h
endfunction

function! todo#PrioritizeDecrease()
    " Same as todo#PrioritizeIncrease(): the marker must stay (P).
    if todo#IsStub(getline('.'))
        return
    endif
    normal! 0f)h
endfunction

function! todo#PrioritizeAdd (priority)
    let oldpos=todo#GetCurpos()
    let line=getline('.')
    if line !~ '^([A-F])'
        :call todo#PrioritizeAddAction(a:priority)
        let oldpos[2]+=4
    else
        exec ':s/^([A-F])/('.a:priority.')/'
    endif
    call setpos('.',oldpos)
endfunction

function! todo#PrioritizeAddAction (priority)
    execute "normal! mq0i(".a:priority.") \<esc>`q"
    execute "delmarks q"
endfunction

function! todo#RemovePriority()
    :s/^(\w)\s\+//ge
endfunction

function! todo#PrependDate()
    if (getline(".") =~ '\v^\(')
        execute "normal! 0f)a\<space>\<esc>l\"=strftime(\"%Y-%m-%d\")\<esc>P"
    else
        normal! I=strftime("%Y-%m-%d ")
    endif
endfunction

function todo#SaveRegisters()
    let s:last_search=@/
endfunction

function todo#RestoreRegisters()
    let @/=s:last_search
endfunction

function! todo#ToggleMarkAsDone(status)
    call todo#SaveRegisters()
    if (getline(".") =~ '\C^x\s*\d\{4\}')
        :call todo#UnMarkAsDone(a:status)
    else
        :call todo#MarkAsDone(a:status)
    endif
    call todo#RestoreRegisters()
endfunction

function! todo#FixFormat()
    " Remove heading space
    silent! %s/\C^\s*//
    " Remove priority from done tasks
    silent! %s/\C^x (\([A-Z]\)) \(.*\)/x \2 pri:\1/
endfunction

function! todo#UnMarkAsDone(status)
    if a:status==''
        let pat=''
    else
        let pat=' '.a:status
    endif
    exec ':s/\C^x\s*\d\{4}-\d\{1,2}-\d\{1,2}'.pat.'\s*//g'
    silent s/\C\(.*\) pri:\([A-Z]\)/(\2) \1/e
endfunction

" Drop the in-progress tag. A preceding space goes with it; a tag at the
" start of the line takes the following space instead. substitute() rather
" than :s, so this stays safe inside :global.
function! s:WithoutActiveTag(line) abort
    let l:line = substitute(a:line, '\s\+\<active:1\>', '', 'g')
    return substitute(l:line, '\<active:1\>\s*', '', '')
endfunction

function! todo#ToggleActive() abort
    if getline('.') =~# '\C^x\s'
        return
    endif
    let l:line = getline('.')
    if l:line =~# '\<active:1\>'
        call setline('.', s:WithoutActiveTag(l:line))
    elseif l:line =~# '\S'
        call setline('.', l:line . ' active:1')
    else
        call setline('.', 'active:1')
    endif
endfunction

" Set while todo#MarkAllAsDone() runs its :global, see that function.
let s:marking_all = 0

function! todo#MarkAsDone(status)
    let l:line = getline('.')
    " A (P) stub is not a task: it is never completed and never reaches
    " done.txt. Only its instances are.
    if todo#IsStub(l:line)
        return
    endif
    " Before the recurrence copy, so the next occurrence is not still in progress.
    let l:stripped = s:WithoutActiveTag(l:line)
    if l:stripped !=# l:line
        call setline('.', l:stripped)
    endif
    " Stamp last: before the line is closed: the period of a series is counted
    " from the actual completion, and the stub scan below must already see it.
    call todo#UpdateStubLast(todo#TagValue(l:stripped, 'rid'), strftime('%Y-%m-%d'))
    call todo#CreateNewRecurrence(1)
    if get(g:, 'TodoTxtStripDoneItemPriority', 0)
        exec ':s/\C^(\([A-Z]\))\(.*\)/\2/e'
    else
        exec ':s/\C^(\([A-Z]\))\(.*\)/\2 pri:\1/e'
    endif
    if a:status!=''
        exec 'normal! I'.a:status.' '
    endif
    call todo#PrependDate()
    if (getline(".") =~ '^ ')
        normal! gIx
    else
        normal! Ix 
    endif
    " Inside :global an inserted line shifts the traversal, so a batch scans the
    " stubs once, after every line has been closed (todo#MarkAllAsDone()).
    if !s:marking_all
        call todo#MaterializeStubs()
    endif
endfunction

function! todo#MarkAllAsDone()
    let s:marking_all = 1
    try
        :g!/^x /:call todo#MarkAsDone('')
    finally
        let s:marking_all = 0
    endtry
    call todo#MaterializeStubs()
endfunction

function! s:AppendToFile(file, lines)
    let l:lines = []

    " Place existing tasks in done.txt at the beggining of the list.
    if filereadable(a:file)
        call extend(l:lines, readfile(a:file))
    endif

    " Append new completed tasks to the list.
    call extend(l:lines, a:lines)

    " Write to file.
    call writefile(l:lines, a:file)
endfunction

function! todo#RemoveCompleted()
    " Check if we can write to done.txt before proceeding.
    let l:target_dir = expand('%:p:h')
    if exists("g:TodoTxtForceDoneName")
        let l:done=g:TodoTxtForceDoneName
    else
        let l:currentfile=expand('%:t')

        if l:currentfile =~ '[Tt]oday.txt'
            let l:done=substitute(substitute(l:currentfile,'today','done-today',''),'Today','Done-Today','')
        else
            let l:done=substitute(substitute(l:currentfile,'todo','done',''),'Todo','Done','')
        endif
    endif
    let l:done_file = l:target_dir.'/'.l:done
    echo "Writing to ".l:done_file
    if !filewritable(l:done_file) && !filewritable(l:target_dir)
        echoerr "Can't write to file '".l:done_file."'"
        return
    endif

    let l:completed = []
    :g/^x /call add(l:completed, getline(line(".")))|d
    call s:AppendToFile(l:done_file, l:completed)
endfunction

function! todo#Sort(type)
    " vim :sort is usually stable
    " we sort first on contexts, then on projects and then on priority
    let g:Todo_fold_char='x'
    let oldcursor=todo#GetCurpos()
    if(a:type != "")
        exec ':sort /.\{-}\ze'.a:type.'/'
        " Stubs are not sorted with the tasks, they go back to their tail.
        call s:ParkStubs()
    elseif expand('%')=~'[Dd]one.*.txt'
        " FIXME: Put some unit tests around this, and fix case sensitivity if ignorecase is set.
        silent! %s/\(x\s*\d\{4}\)-\(\d\{2}\)-\(\d\{2}\)/\1\2\3/g
        sort n /^x\s*/
        silent! %s/\(x\s*\d\{4}\)\(\d\{2}\)/\1-\2-/g
    else
        silent normal gg
        let l:first=search('^\s*x')
        if  l:first != 0
            sort /^./r
            " at this point done tasks are at the end
            let l:first=search('^\s*x')
            let l:last=search('^\s*x','b')
            let l:diff=l:last-l:first+1
            " Cut the done lines
            silent execute ':'.l:first.'d a '.l:diff
        endif
        silent sort /@[a-zA-Z]*/ r
        silent sort /+[a-zA-Z]*/ r
        silent sort /\v\([A-Z]\)/ r
        "Now tasks without priority are at beggining, move them to the end
        silent normal gg
        let l:firstP=search('^\s*([A-Z])', 'cn')
        if  l:firstP > 1
            let num=l:firstP-1
            " Sort normal
            silent execute ':1 d b'.num
            silent normal G"bp
        endif
        if l:first != 0
            silent normal G"ap
            silent execute ':'.l:first.','.l:last.'sort /@[a-zA-Z]*/ r'
            silent execute ':'.l:first.','.l:last.'sort /+[a-zA-Z]*/ r'
            silent execute ':'.l:first.','.l:last.'sort /\v([A-Z])/ r'
        endif
        " Last step: collect the (P) stubs again at the tail of the active
        " tasks, the sorts above put them wherever their tags sent them.
        call s:ParkStubs()
    endif
    call setpos('.', oldcursor)
endfunction

" Move every (P) stub to the place it belongs: after all the ordinary tasks
" and right before the x block, at the end of the buffer when nothing is
" completed yet. The stubs keep their relative order. Called after a sort has
" already done its own ordering, so it only has to undo the scattering.
function! s:ParkStubs() abort
    let l:lines = getline(1, '$')
    let l:stubs = filter(copy(l:lines), 'todo#IsStub(v:val)')
    if empty(l:stubs)
        return
    endif
    let l:kept = filter(copy(l:lines), '!todo#IsStub(v:val)')
    call extend(l:kept, l:stubs, s:StubParkIndex(l:kept))
    call s:SetBufferLines(l:kept)
endfunction

" Index in a:lines the stubs are inserted at: right before the x block, or at
" the end of the buffer when nothing is completed. A sort on a single tag does
" not keep the completed lines together, and a stub must never end up above an
" ordinary task, so a completed line with a task below it parks the stubs last.
function! s:StubParkIndex(lines) abort
    let l:at = len(a:lines)
    for l:i in range(len(a:lines))
        if s:IsDone(a:lines[l:i])
            let l:at = l:i
            break
        endif
    endfor
    for l:i in range(l:at, len(a:lines) - 1)
        if !s:IsDone(a:lines[l:i])
            return len(a:lines)
        endif
    endfor
    return l:at
endfunction

function! todo#SortDue()
    " Check how many lines have a due:date on them
    let l:tasksWithDueDate = 0
    silent! %global/\v\c<due:\d{4}-\d{2}-\d{2}>/let l:tasksWithDueDate += 1
    if l:tasksWithDueDate == 0
        " No tasks with a due:date: No need to modify the buffer at all
        " Also means we don't need to cater for no matches on searches below
        return
    endif
    " FIXME: There is a small chance that due:\d{8} might legitimately exist in the buffer
    " We modify due:yyyy-mm-dd to yyyymmdd which would then mean we would alter the buffer
    " in an unexpected way, altering user data. Not sure how to deal with this at the moment.
    " I'm going to throw an exception, and if this is a problem we can revisit.
    silent %global/\v\c<due:\d{8}>/throw "Text matching 'due:\\d\\{8\\}' exists in the buffer, this function cannot sort your buffer"
    " Turn the due:date from due:yyyy-mm-dd to due:yyyymmdd so we can do a numeric sort
    silent! %substitute/\v<(due:\d{4})\-(\d{2})\-(\d{2})>/\1\2\3/ei
    " Sort all the lines with due: by numeric yyyymmdd, they will end up in ascending order at the bottom of the buffer
    sort in /\v\c<due:\ze\d{8}>/
    " Determine the line number of the first task with a due:date
    let l:firstLineWithDue = line("$") - l:tasksWithDueDate + 1
    " Put the sorted lines at the beginning of the file
    if l:firstLineWithDue > 1
        " ...but only if the whole file didn't get sorted.
        execute "silent " . l:firstLineWithDue . ",$move 0"
    endif
    " Change the due:yyyymmdd back to due:yyyy-mm-dd.
    silent! %substitute/\v<(due:\d{4})(\d{2})(\d{2})>/\1-\2-\3/ei
    silent global/\C^x /move$
    " Let's check a global for a user preference on the cursor position.
    if exists("g:TodoTxtSortDueDateCursorPos")
        if g:TodoTxtSortDueDateCursorPos ==? "top"
            normal gg
        elseif g:TodoTxtSortDueDateCursorPos ==? "lastdue" || g:TodoTxtSortDueDateCursorPos ==? "notoverdue"
            silent normal G
            " Sorry for the crazy RegExp. The next command should put cursor at at the top of the completed tasks,
            " or the bottom of the buffer. This is done by searching backwards for any line not starting with
            " "x " (x, space) which is important to distinguish from "xample task" for instance, which the more
            " simple "^[^x]" would match. More info: ":help /\@!". Be sure to enforce case sensitivity on "x".
            :silent! ?\v\C^(x )@!?+1
            let l:overduePat = todo#GetDateRegexForPastDates()
            let l:lastwrapscan = &wrapscan
            set nowrapscan
            try
                if g:TodoTxtSortDueDateCursorPos ==? "lastdue"
                    " This searches backwards for the last due task
                    :?\v\c<due:\d{4}\-\d{2}\-\d{2}>
                    " Try a forward search in case the last line of the buffer was a due:date task, don't match done
                    " Be sure to enforce case sensitivity on "x" while allowing mixed case on "due:"
                    :silent! /\v\C^(x )@!&.*<[dD][uU][eE]:\d{4}\-\d{2}\-\d{2}>
                elseif g:TodoTxtSortDueDateCursorPos ==? "notoverdue"
                    " This searches backwards for the last overdue task, and positions the cursor on the following line
                    execute ":?\\v\\c<due:" . l:overduePat . ">?+1"
                endif
            catch
                " Might fail if there are no active (or overdue) due:date tasks. Requires nowrapscan
                " This code path always means we want to be at the top of the buffer
                normal gg
            finally
                let &wrapscan = l:lastwrapscan
            endtry
        elseif g:TodoTxtSortDueDateCursorPos ==? "bottom"
            silent normal G
        endif
    else
        " Default: Top of the document
        normal gg
    endif
    " TODO: add time sorting (YYYY-MM-DD HH:MM)
endfunction

" This is a Hierarchical sort designed for todo.txt todo lists, however it
" might be used for other files types
" At the first level, lines are sorted by the word right after the first
" occurence of a:symbol, there must be no space between the symbol and the
" word. At the second level, the same kind of sort is done based on
" a:symbolsub, is a:symbol==' ', the second sort doesn't occurs
" Therefore, according to todo.txt syntaxt, if
"   a:symbol is a '+' it sort by the first project
"   a:symbol is an '@' it sort by the first context
" The last level of sort is done directly on the line, so according to
" todo.txt syntax, it means by priority. This sort is done if and only if the
" las argument is not 0
function! todo#HierarchicalSort(symbol, symbolsub, dolastsort)
    if v:statusmsg =~ '--No lines in buffer--'
        "Empty buffer do nothing
        return
    endif
    let g:Todo_fold_char=a:symbol
    "if the sort modes doesn't start by '!' it must start with a space
    let l:sortmode=Todo_txt_InsertSpaceIfNeeded(g:Todo_txt_first_level_sort_mode)
    let l:sortmodesub=Todo_txt_InsertSpaceIfNeeded(g:Todo_txt_second_level_sort_mode)
    let l:sortmodefinal=Todo_txt_InsertSpaceIfNeeded(g:Todo_txt_third_level_sort_mode)

    " Count the number of lines
    let l:position= todo#GetCurpos()
    execute "silent normal G"
    let l:linecount=getpos(".")[1]
    if(exists("g:Todo_txt_debug"))
        echo "Linescount: ".l:linecount
    endif
    execute "silent normal gg"

    " Get all the groups names
    let l:groups=GetGroups(a:symbol,1,l:linecount)
    if(exists("g:Todo_txt_debug"))
        echo "Groups: "
        echo l:groups
        echo 'execute sort'.l:sortmode.' /.\{-}\ze'.a:symbol.'/'
    endif
    " Sort by groups
    execute 'sort'.l:sortmode.' /.\{-}\ze'.a:symbol.'/'
    for l:g in l:groups
        let l:pat=a:symbol.l:g.'.*$'
        if(exists("g:Todo_txt_debug"))
            echo l:pat
        endif
        normal gg
        " Find the beginning of the group
        let l:groupBegin=search(l:pat,'c')
        " Find the end of the group
        let l:groupEnd=search(l:pat,'b')

        " I'm too lazy to sort groups of one line
        if(l:groupEnd==l:groupBegin)
            continue
        endif
        if a:dolastsort
            if( a:symbolsub!='')
                " Sort by subgroups
                let l:subgroups=GetGroups(a:symbolsub,l:groupBegin,l:groupEnd)
                " Go before the first line of the group
                " Sort the group using the second symbol
                for l:sg in l:subgroups
                    normal gg
                    let l:pat=a:symbol.l:g.'.*'.a:symbolsub.l:sg.'.*$\|'.a:symbolsub.l:sg.'.*'.a:symbol.l:g.'.*$'
                    " Find the beginning of the subgroup
                    let l:subgroupBegin=search(l:pat,'c')
                    " Find the end of the subgroup
                    let l:subgroupEnd=search(l:pat,'b')
                    " Sort by priority
                    execute l:subgroupBegin.','.l:subgroupEnd.'sort'.l:sortmodefinal
                endfor
            else
                " Sort by priority
                if(exists("g:Todo_txt_debug"))
                    echo 'execute '.l:groupBegin.','.l:groupEnd.'sort'.l:sortmodefinal
                endif
                execute l:groupBegin.','.l:groupEnd.'sort'.l:sortmodefinal
            endif
        endif
    endfor
    " Stubs are parked, not grouped: a (P) line carries the same +project and
    " @context tags as its instances, but it must not end up inside a group.
    call s:ParkStubs()
    " Restore the cursor position
    call setpos('.', position)
endfunction

" Returns the list of groups starting by a:symbol between lines a:begin and
" a:end
function! GetGroups(symbol,begin, end)
    let l:curline=a:begin
    let l:groups=[]
    while l:curline <= a:end
        let l:curproj=strpart(matchstr(getline(l:curline),a:symbol.'\S*'),len(a:symbol))
        if l:curproj != "" && index(l:groups,l:curproj) == -1
            let l:groups=add(l:groups , l:curproj)
        endif
        let l:curline += 1
    endwhile
    return l:groups
endfunction

" Insert a space if needed (the first char isn't '!' or ' ') in front of 
" sort parameters
function! Todo_txt_InsertSpaceIfNeeded(str)
    let l:c=strpart(a:str,1,1)
    if( l:c != '!' && l:c !=' ')
        return " ".a:str
    endif
    retur a:str
endfunction

" function todo#CreateNewRecurrence {{{2
function! todo#CreateNewRecurrence(triggerOnNonStrict)
    " Given a line with a rec:timespan, create a new task based off the
    " recurrence and move the recurring tasks due:date to the next occurrence.
    "
    " This is implemented by a few other systems, so we will try to be as
    " compatible as possible with the existing specifications.
    "
    " Other example implementations:
    "   <http://swiftodoapp.com/>
    "   <https://github.com/bram85/todo.txt-tools/wiki/Recurrence>
    "

    let l:currentline = getline('.')

    " Don't operate on complete tasks
    if l:currentline =~# '^x '
        return
    endif

    let l:rec_date_rex = '\v\c(^|\s)rec:(\+)?(\d+)([dwmy])(\s|$)'
    let l:rec_parts = matchlist(l:currentline, l:rec_date_rex)
    " Don't operate on tasks without a valid "rec:" keyword.
    if empty(l:rec_parts)
        " If a "rec:" keyword exists, but it didn't match our expectations, warn
        " the user, and abort whatever is happening otherwise a recurring task
        " might be marked complete without a new recurrence being created.
        if l:currentline =~? '\v\c(^|\s)rec:'
            throw "Recurrence pattern is invalid. Aborting operation."
        endif
        return
    endif

    " Operations like postponing a task should not trigger the task to be
    " duplicated, non-strict mode allows the changing of the due date.
    let l:is_strict = l:rec_parts[2] ==# "+"
    if ! a:triggerOnNonStrict && ! l:is_strict
        return
    endif

    let l:units = str2nr(l:rec_parts[3])
    if l:units < 1
        let l:units = 1
    endif
    let l:unit_type = l:rec_parts[4]
    " If we had a space on both sides of the "rec:" that we are removing, then
    " we need to insert a space, otherwise, not.
    if l:rec_parts[1] ==# ' ' && l:rec_parts[5] ==# ' '
        let l:replace_string = ' '
    else
        let l:replace_string = ''
    endif

    " New task should have the rec: keyword stripped
    let l:newline = substitute(l:currentline, l:rec_date_rex, l:replace_string, '')
    " Insert above current line
    let l:new_task_line_num = line('.')
    if append(l:new_task_line_num - 1, l:newline) != 0
        throw "Failed at append line"
    endif

    " At this point, we need to change the due date of the recurring task.
    " Modes:
    "       Strict mode:        From the existing due date
    "       Non-Strict mode:    From the current date
    " So, we don't need to do anything for strict mode. Non-strict mode requires
    " setting the current date.
    if l:is_strict
        call todo#ChangeDueDate(l:units, l:unit_type, '')
    else
        call todo#ChangeDueDate(l:units, l:unit_type, strftime('%Y-%m-%d'))
    endif

    " Move onto the copied task
    call cursor(l:new_task_line_num, col('.'))
    if l:new_task_line_num != line('.')
        throw "Failed to move cursor"
    endif
endfunction

" function todo#ChangeDueDate {{{2
function! todo#ChangeDueDate(units, unit_type, from_reference)
    " Change the due:date on the current line by a number of days, months or
    " years
    "
    " units             The number of unit_type to add or subtract, integer
    "                   values only
    " unit_type         May be one of 'd' (days), 'm' (months) or 'y' (years),
    "                   as handled by todo#DateAdd
    " from_reference    Allows passing a different date to base the calculation
    "                   on, ignoring the existing due date in the line. Leave as
    "                   an empty string to use the due:date in the line,
    "                   otherwise a date as a string in the form "YYYY-MM-DD".

    let l:currentline = getline('.')

    " Don't operate on complete tasks
    if l:currentline =~# '^x '
        return
    endif

    let l:dueDateRex = '\v\c(^|\s)due:\zs\d{4}\-\d{2}\-\d{2}\ze(\s|$)'

    let l:duedate = matchstr(l:currentline, l:dueDateRex)
    if l:duedate ==# ''
        " No due date on current line, then add the due date as an offset from
        " current date. I.e. a v:count of 1 is due tomorrow, etc
        if l:currentline =~? '\v\c(^|\s)due:'
            " Has an invalid due: keyword, so don't add another, and don't
            " change the line
            return
        endif
        let l:duedate = strftime('%Y-%m-%d')
        let l:currentline .= ' due:' . l:duedate
    endif
    " If a valid reference has been passed, let's use it.
    if a:from_reference =~# '\v^\d{4}\-\d{2}\-\d{2}$'
        let l:duedate = a:from_reference
    endif

    let l:duedate = todo#DateStringAdd(l:duedate, v:count1 * a:units, a:unit_type)

    if setline('.', substitute(l:currentline, l:dueDateRex, l:duedate, '')) != 0
        throw "Failed to set line"
    endif
endfunction "}}}

" Periodic and deferred tasks {{{1
"
" A (P) line is not a priority and not a task either: it is a stub parked at
" the end of the active tasks. It only says when a task has to come back into
" the (B) list. Two kinds of stub:
"   (P) Pay the internet +home every:1m last:2026-09-01 rid:a1b2   repeat
"   (P) Book a dentist +health show:2026-10-14                     once
" The tags are deliberately not named rec:: todo#CreateNewRecurrence() copies
" the line right away, a stub waits for its own moment and leaves the copying
" to todo#MaterializeStubs().

let s:done_re = '\v\C^x\s'
" Role markers are recognised with an optional creation date in front, as
" everywhere else in the plugin: "2017-09-01 (A) ...".
let s:priority_re = '\v\C^(\d{4}-\d{2}-\d{2}\s+)?\(\zs[A-Z]\ze\)\s'
let s:stub_re = '\v\C^(\d{4}-\d{2}-\d{2}\s+)?\(P\)\s'
let s:date_re = '\v\C^\d{4}-\d{2}-\d{2}$'
let s:period_re = '\v\C^\s*(\d+)\s*([dwmyDWMY])\s*$'
" Two series created in the same second still need two different rids.
let s:rid_counter = 0

function! s:IsDone(line) abort
    return a:line =~# s:done_re
endfunction

function! s:IsTask(line) abort
    " Only an unfinished, non-stub line can be an open instance of a series.
    return a:line =~# '\S' && !s:IsDone(a:line) && !todo#IsStub(a:line)
endfunction

function! s:Priority(line) abort
    return matchstr(a:line, s:priority_re)
endfunction

function! todo#IsStub(line) abort
    return a:line =~# s:stub_re
endfunction

function! s:ValidDate(date) abort
    return a:date =~# s:date_re
endfunction

function! todo#TagValue(line, tag) abort
    " Whole word, so "notevery:1m" is not an every: tag.
    return matchstr(a:line, '\v\C(^|\s)' . a:tag . ':\zs\S*')
endfunction

function! s:SetTag(line, key, value) abort
    let l:tag = a:key . ':' . a:value
    if todo#TagValue(a:line, a:key) !=# ''
        return substitute(a:line, '\v\C(^|\s)' . a:key . ':\S*', '\1' . l:tag, '')
    endif
    " Keep the documented order every: last: rid: when adding last:. \zs leaves
    " the space in front of rid: out of the replaced text, so no \1 here. A
    " (^|\s) group in front of \zs silently fails to match, hence \s only.
    if a:key ==# 'last' && a:line =~# '\v\C\srid:'
        return substitute(a:line, '\v\C\s\zsrid:', l:tag . ' rid:', '')
    endif
    return a:line . ' ' . l:tag
endfunction

function! s:StubBody(line) abort
    " What the stub and its instances have in common: the wording, projects,
    " contexts and ordinary tags. Priority, creation date, service tags and
    " active:1 belong to one concrete line and are re-added by the caller.
    let l:body = s:WithoutActiveTag(a:line)
    let l:body = substitute(l:body, '\v\C^\s*(\d{4}-\d{2}-\d{2}\s+)?\([A-Z]\)\s+', '', '')
    let l:body = substitute(l:body, '\v\C^\s*\([A-Z]\)\s+\d{4}-\d{2}-\d{2}\s+', '', '')
    let l:body = substitute(l:body, '\v\C^\s*\d{4}-\d{2}-\d{2}\s+', '', '')
    " A removed tag takes a preceding space with it, like s:WithoutActiveTag().
    let l:body = substitute(l:body, '\v\C\s+<%(every|last|show|rid):\S*', '', 'g')
    let l:body = substitute(l:body, '\v\C^<%(every|last|show|rid):\S*\s*', '', 'g')
    return substitute(l:body, '\v\s+$', '', 'g')
endfunction

" Build a stub out of a task line. a:tags is a list like ['every:1m', 'rid:a1b2']
" or ['show:2026-10-14'], written in the order given.
function! todo#MakeStub(line, tags) abort
    let l:body = s:StubBody(a:line)
    let l:stub = l:body ==# '' ? '(P)' : '(P) ' . l:body
    return empty(a:tags) ? l:stub : l:stub . ' ' . join(a:tags, ' ')
endfunction

" The single open instance of a stub: the stub text as a (B) task created
" today, with the same rid: so the stub still recognises its instance.
function! todo#MakeTask(stub, date) abort
    let l:task = '(B)'
    if s:ValidDate(a:date)
        let l:task .= ' ' . a:date
    endif
    let l:body = s:StubBody(a:stub)
    if l:body !=# ''
        let l:task .= ' ' . l:body
    endif
    let l:rid = todo#TagValue(a:stub, 'rid')
    return l:rid ==# '' ? l:task : l:task . ' rid:' . l:rid
endfunction

function! todo#ParsePeriod(period) abort
    " Same units as the existing date arithmetic: Nd, Nw, Nm, Ny.
    let l:parts = matchlist(a:period, s:period_re)
    if empty(l:parts) || str2nr(l:parts[1]) < 1
        return []
    endif
    return [str2nr(l:parts[1]), tolower(l:parts[2])]
endfunction

function! s:RidTaken(rid) abort
    for l:lnum in range(1, line('$'))
        if todo#TagValue(getline(l:lnum), 'rid') ==# a:rid
            return 1
        endif
    endfor
    return 0
endfunction

function! todo#NewRid() abort
    " A rid only has to be unique inside one file. The clock gives the value,
    " s:rid_counter keeps two series made in the same second apart, and the
    " loop catches a clash with a rid already in the buffer.
    let l:seed = localtime()
    let l:rid = tolower(printf('%04x', l:seed % 0x10000))
    while s:RidTaken(l:rid)
        let s:rid_counter += 1
        let l:rid = tolower(printf('%04x', (l:seed + s:rid_counter) % 0x10000))
    endwhile
    return l:rid
endfunction

function! s:FirstDoneLine() abort
    for l:lnum in range(1, line('$'))
        if s:IsDone(getline(l:lnum))
            return l:lnum
        endif
    endfor
    return 0
endfunction

" Stubs live after the ordinary tasks and right before the x block, at the end
" of the buffer when nothing is completed yet.
function! s:ParkLine() abort
    let l:done = s:FirstDoneLine()
    return l:done > 0 ? l:done : line('$') + 1
endfunction

" Where a task returning to the (B) list goes: before the first (B) task, or
" after the last (A) when there is none, or at the very top of the file.
" Returns the index in a:lines to insert at, so the list order is kept.
function! s:TaskInsertIndex(lines) abort
    let l:first_b = -1
    let l:last_a = -1
    for l:i in range(len(a:lines))
        let l:line = a:lines[l:i]
        if !s:IsTask(l:line)
            continue
        endif
        let l:priority = s:Priority(l:line)
        if l:priority ==# 'B' && l:first_b < 0
            let l:first_b = l:i
        elseif l:priority ==# 'A'
            let l:last_a = l:i
        endif
    endfor
    if l:first_b >= 0
        return l:first_b
    endif
    return l:last_a >= 0 ? l:last_a + 1 : 0
endfunction

function! todo#TaskInsertLine() abort
    return s:TaskInsertIndex(getline(1, '$')) + 1
endfunction

function! s:DateReached(date, today) abort
    " ISO dates sort as strings, no need to parse them.
    return s:ValidDate(a:date) && a:date <=# a:today
endfunction

" Is this stub ready to put a task back into the (B) list? Whether an open
" instance already exists is a question about the whole buffer and is checked
" separately by todo#MaterializeStubs().
function! todo#StubDue(stub, today) abort
    if !todo#IsStub(a:stub)
        return 0
    endif
    let l:show = todo#TagValue(a:stub, 'show')
    if l:show !=# ''
        return s:DateReached(l:show, a:today)
    endif
    let l:period = todo#ParsePeriod(todo#TagValue(a:stub, 'every'))
    if empty(l:period)
        return 0
    endif
    " Without last: the first instance is still open, there is nothing to count
    " the period from yet.
    let l:last = todo#TagValue(a:stub, 'last')
    if !s:ValidDate(l:last)
        return 0
    endif
    return s:DateReached(todo#DateStringAdd(l:last, l:period[0], l:period[1]), a:today)
endfunction

function! todo#HasOpenInstance(rid) abort
    if a:rid ==# ''
        return 0
    endif
    for l:lnum in range(1, line('$'))
        let l:line = getline(l:lnum)
        if s:IsTask(l:line) && todo#TagValue(l:line, 'rid') ==# a:rid
            return 1
        endif
    endfor
    return 0
endfunction

function! todo#UpdateStubLast(rid, date) abort
    if a:rid ==# '' || !s:ValidDate(a:date)
        return 0
    endif
    for l:lnum in range(1, line('$'))
        let l:line = getline(l:lnum)
        if todo#IsStub(l:line) && todo#TagValue(l:line, 'rid') ==# a:rid
            " setline(), not :s: this runs inside the :global of MarkAllAsDone.
            call setline(l:lnum, s:SetTag(l:line, 'last', a:date))
            return 1
        endif
    endfor
    return 0
endfunction

function! s:SetBufferLines(lines) abort
    let l:count = line('$')
    call setline(1, a:lines)
    if l:count > len(a:lines)
        call s:DeleteLines(len(a:lines) + 1, l:count)
    endif
endfunction

function! s:DeleteLines(first, last) abort
    if exists('*deletebufline')
        call deletebufline(bufnr('%'), a:first, a:last)
    else
        silent execute a:first . ',' . a:last . 'delete _'
    endif
endfunction

" Walk the (P) stubs and put back every task whose moment has come. Returns the
" number of tasks inserted. Called once per completion, and once after a whole
" todo#MarkAllAsDone() batch, never from inside its :global.
function! todo#MaterializeStubs() abort
    let l:today = strftime('%Y-%m-%d')
    let l:lines = getline(1, '$')
    let l:block = []
    let l:drop = {}
    for l:i in range(len(l:lines))
        let l:line = l:lines[l:i]
        if !todo#IsStub(l:line) || !todo#StubDue(l:line, l:today)
            continue
        endif
        if todo#TagValue(l:line, 'show') !=# ''
            " A one-shot stub becomes the task itself, the stub disappears.
            let l:drop[l:i] = 1
        else
            let l:rid = todo#TagValue(l:line, 'rid')
            " Never a second open instance, and an overdue period does not
            " pile up: the next countdown starts from the real completion.
            if l:rid !=# '' && todo#HasOpenInstance(l:rid)
                continue
            endif
        endif
        " Stubs due at once go back as one block, in their own order.
        call add(l:block, todo#MakeTask(l:line, l:today))
    endfor
    if empty(l:block)
        return 0
    endif
    let l:kept = []
    let l:moved = []
    for l:i in range(len(l:lines))
        call add(l:moved, has_key(l:drop, l:i) ? -1 : len(l:kept))
        if !has_key(l:drop, l:i)
            call add(l:kept, l:lines[l:i])
        endif
    endfor
    let l:at = s:TaskInsertIndex(l:kept)
    for l:line in reverse(copy(l:block))
        call insert(l:kept, l:line, l:at)
    endfor
    call s:SetBufferLines(l:kept)
    " Keep the cursor on the line it was on, the block above may have moved it.
    call cursor(s:AnchorLine(l:moved, l:at, len(l:block), line('.') - 1) + 1, col('.'))
    return len(l:block)
endfunction

" New index of the line the cursor was on, or the closest surviving one.
function! s:AnchorLine(moved, at, added, anchor) abort
    let l:i = min([a:anchor, len(a:moved) - 1])
    while l:i >= 0 && a:moved[l:i] < 0
        let l:i -= 1
    endwhile
    if l:i < 0
        return a:at
    endif
    let l:new = a:moved[l:i]
    return l:new >= a:at ? l:new + a:added : l:new
endfunction

" Make the current line the open instance of a repeat series and park its (P)
" stub at the end. On a line that already belongs to a series only every:
" changes: there must stay exactly one stub and one open instance.
function! todo#RepeatTask(period) abort
    let l:period = todo#ParsePeriod(a:period)
    if empty(l:period)
        return s:Error('invalid period, expected something like 2w, 10d, 1m or 1y')
    endif
    let l:lnum = line('.')
    let l:line = getline(l:lnum)
    if l:line !~# '\S' || s:IsDone(l:line)
        return 0
    endif
    let l:every = l:period[0] . l:period[1]
    if todo#IsStub(l:line)
        if todo#TagValue(l:line, 'show') !=# ''
            return s:Error('a one-shot (P) line has no period to change')
        endif
        call setline(l:lnum, s:SetTag(l:line, 'every', l:every))
        return 1
    endif
    let l:rid = todo#TagValue(l:line, 'rid')
    if l:rid !=# ''
        for l:stub in range(1, line('$'))
            if todo#IsStub(getline(l:stub)) && todo#TagValue(getline(l:stub), 'rid') ==# l:rid
                call setline(l:stub, s:SetTag(getline(l:stub), 'every', l:every))
                return 1
            endif
        endfor
    endif
    let l:rid = todo#NewRid()
    call setline(l:lnum, s:SetTag(l:line, 'rid', l:rid))
    call append(s:ParkLine() - 1, todo#MakeStub(getline(l:lnum), ['every:' . l:every, 'rid:' . l:rid]))
    return 1
endfunction

" Park the current line as a one-shot (P) stub: it leaves the working list and
" comes back on its own, as a (B) task, on the day asked for.
function! todo#ShowTaskLater(when) abort
    let l:date = s:ParseWhen(a:when)
    if l:date ==# ''
        return s:Error('invalid date, expected an interval like 2w or a date like 2026-10-14')
    endif
    let l:lnum = line('.')
    let l:line = getline(l:lnum)
    if l:line !~# '\S' || s:IsDone(l:line)
        return 0
    endif
    if todo#IsStub(l:line) || todo#TagValue(l:line, 'rid') !=# ''
        return s:Error('this line already belongs to a repeat series')
    endif
    let l:stub = todo#MakeStub(l:line, ['show:' . l:date])
    let l:park = s:ParkLine()
    call append(l:park - 1, l:stub)
    if l:lnum >= l:park
        let l:lnum += 1
    endif
    call s:DeleteLines(l:lnum, l:lnum)
    call cursor(min([l:lnum, line('$')]), 1)
    return 1
endfunction

function! s:ParseWhen(when) abort
    if s:ValidDate(a:when)
        return a:when
    endif
    let l:period = todo#ParsePeriod(a:when)
    if empty(l:period)
        return ''
    endif
    return todo#DateStringAdd(strftime('%Y-%m-%d'), l:period[0], l:period[1])
endfunction

function! s:Error(message) abort
    echohl ErrorMsg
    echomsg 'Todo.txt: ' . a:message
    echohl None
    return 0
endfunction

" <LocalLeader>r. Thin on purpose: everything that can be tested lives in
" todo#RepeatTask() and todo#ShowTaskLater().
function! todo#RepeatDialog() abort
    let l:line = getline('.')
    if l:line !~# '\S' || s:IsDone(l:line)
        return
    endif
    let l:mode = inputlist(['Repeat this task:',
                \ '1. after every completion (every:)',
                \ '2. once, later (show:)'])
    if l:mode < 1 || l:mode > 2
        return
    endif
    let l:prompt = l:mode == 1 ? 'Every (2w, 10d, 1m, 1y): ' : 'Show at (2w or 2026-10-14): '
    let l:answer = substitute(input(l:prompt), '\v^\s+|\s+$', '', 'g')
    " An empty answer cancels and leaves the file alone.
    if l:answer ==# ''
        return
    endif
    if l:mode == 1
        call todo#RepeatTask(l:answer)
    else
        call todo#ShowTaskLater(l:answer)
    endif
endfunction

" General date calculation functions {{{1

" function todo#GetDaysInMonth {{{2
function! todo#GetDaysInMonth(month, year)
    " Given a month and year, returns the number of days in the month, taking
    " leap years into consideration.

    if index([1, 3, 5, 7, 8, 10, 12], a:month) >= 0
        return 31
    elseif index([4, 6, 9, 11], a:month) >= 0
        return 30
    else
        " February, leap year fun.
        if a:year % 4 != 0
            return 28
        elseif a:year % 100 != 0
            return 29
        elseif a:year % 400 != 0
            return 28
        else
            return 29
        endif
    endif
endfunction

" function todo#DateAdd {{{2
function! todo#DateAdd(year, month, day, units, unit_type)
    " Add or subtract days, months or years from a date
    "
    " Date must be passed in components of year, month and day, all integers
    " units is the number of unit_type to add or subtract, integer values only
    " unit_type may be one of:
    "   d       days
    "   w       weeks, 7 days
    "   m       months, keeps the day of the month static except in the case
    "           that the day is the last day in the month or the day is higher
    "           than the number of days in the resultant month, where the result
    "           will stick to the end of the month. Examples:
    "               2017-01-15 +1m 2017-02-15 +1m 2017-03-15 +1m 2017-04-15
    "               2017-01-31 +1m 2017-02-28 +1m 2017-03-31 +1m 2017-04-30
    "               2017-01-30 +1m 2017-02-28 +1m 2017-03-31
    "               2017-01-30 +2m 2017-03-30
    "   y       years, 12 months


    " It is my understanding that VIM does not have date math functionality
    " built in. Given we only have to deal with dates, and not times, it isn't
    " all that scary to roll our own - we just need to watch out for leap years.

    " Check and clean up input
    if index(["d", "D", "w", "W", "m", "M", "y", "Y"], a:unit_type) < 0
        throw 'Invalid unit "'. a:unit_type . '" passed to todo#DateAdd()'
    endif

    let l:d = str2nr(a:day)
    let l:m = str2nr(a:month)
    let l:y = str2nr(a:year)
    let l:i = str2nr(a:units)

    " Years can be handled simply as 12 x months, weeks as 7 x days
    if a:unit_type ==? "y"
        let l:utype = "m"
        let l:i = l:i * 12
    elseif a:unit_type ==? "w"
        let l:utype = "d"
        let l:i = l:i * 7
    else
        let l:utype = a:unit_type
    endif

    " Check and clean up input
    if l:m < 1
        if l:m == 0
            let l:m = str2nr(strftime('%m'))
        else
            let l:m = 1
        endif
    endif
    if l:m > 12
        if l:i < 0 && l:utype ==? "m"
            " Subtracting an invalid (high) month
            " See comments for passing a high day below. Same reason for this.
            let l:m = 13
        else
            let l:m = 12
        endif
    endif
    if l:y < 1900           " See end of function for rationale
        if l:y == 0
            let l:y = str2nr(strftime('%Y'))
        else
            let l:y = 1900
        endif
    endif

    " Grab number of days in the month specified
    let l:daysInMonth = todo#GetDaysInMonth(l:m, l:y)

    " Check and clean up input
    if l:d < 1
        if l:d == 0
            let l:d = str2nr(strftime('%d'))
        else
            let l:d = 1
        endif
    endif
    " Allow passing a high day, this allows subtraction to be more sane when
    " the day is out of bounds, i.e. 2017-04-80 should probably come out as
    " 2017-04-30 not 2017-04-29. Addition deals with days being out of
    " bounds (high) fine, and if days are untouched, out of bounds user
    " input is caught at the end of the function.
    " if l:d > l:daysInMonth
    "     let l:d = l:daysInMonth
    " endif

    if l:utype ==? "d"
        " Adding DAYS
        while l:i > 0
            let l:d += 1
            if l:d > l:daysInMonth
                let l:d = 1
                let l:m += 1
                if l:m > 12
                    let l:m = 1
                    let l:y += 1
                endif
                let l:daysInMonth = todo#GetDaysInMonth(l:m, l:y)
            endif
            let l:i -= 1
        endwhile
        " Subtracting DAYS
        while l:i < 0
            let l:d -= 1
            if l:d < 1
                let l:m -= 1
                if l:m < 1
                    if l:y > 1900
                        let l:m = 12
                        let l:y -= 1
                    else
                        let l:d = 1
                        let l:m = 1
                        break
                    endif
                endif
                let l:daysInMonth = todo#GetDaysInMonth(l:m, l:y)
                let l:d = l:daysInMonth
            endif
            let l:i += 1
        endwhile
    elseif l:utype ==? "m"
        if l:d >= l:daysInMonth
            let l:wasLastDayOfMonth = 1
        else
            let l:wasLastDayOfMonth = 0
        endif
        " Adding MONTHS
        while l:i > 0
            let l:m += 1
            if l:m > 12
                let l:m = 1
                let l:y += 1
            endif
            let l:i -= 1
        endwhile
        " Subtracting MONTHS
        while l:i < 0
            let l:m -= 1
            if l:m < 1
                if l:y > 1900
                    let l:m = 12
                    let l:y -= 1
                else
                    let l:m = 1
                endif
            endif
            let l:i += 1
        endwhile
        let l:daysInMonth = todo#GetDaysInMonth(l:m, l:y)
        if l:wasLastDayOfMonth
            let l:d = l:daysInMonth
        endif
    endif

    " Enforce some limits beyond which, I don't want to support.
    if l:y < 1900
        " Seeing as the date is going to be converted back to a string, dates
        " less that 1000 are bound to cause bugs. Given this is an app for tasks
        " you are doing in the here and now, I'm not supporting way back in the
        " past.
        let l:y = 1900
        let l:daysInMonth = todo#GetDaysInMonth(l:m, l:y)
    endif
    " If we mess with the year (just above), or the user passes a day higher
    " than the month, catch it here.
    if l:d > l:daysInMonth
        let l:d = l:daysInMonth
    endif
    return [l:y, l:m, l:d]
endfunction

" function todo#DateStringAdd {{{2
function! todo#DateStringAdd(date, units, unit_type)
    " A very thin overload of todo#DateAdd() that takes and returns the date as
    " a string rather than in [year, month, day] component form.
    "
    " Date must be passed in "YYYY-MM-DD" format, and is returned in this form
    " also.

    let [l:year, l:month, l:day] = todo#ParseDate(a:date)
    let [l:year, l:month, l:day] = todo#DateAdd(l:year, l:month, l:day, a:units, a:unit_type)
    let l:resulting_date = printf('%04d', l:year) . '-' . printf('%02d', l:month) . '-' . printf('%02d', l:day)
    return l:resulting_date
endfunction

" function todo#ParseDate {{{2
function! todo#ParseDate(datestring)
    " Given a date as a string in the format "YYYY-MM-DD", split the date into a
    " list [year, month, day]
    "
    " Does not check if the date is valid other than being digits. Will throw an
    " exception if the text does not match the expected date format.

    if a:datestring !~? '\v^(\d{4})\-(\d{2})\-(\d{2})$'
        throw "Invalid date passed '" . a:datestring . "'."
    endif
    let l:year = str2nr(strpart(a:datestring, 0, 4))
    let l:month = str2nr(strpart(a:datestring, 5, 2))
    let l:day = str2nr(strpart(a:datestring, 8, 2))
    return [l:year, l:month, l:day]
endfunction "}}}

" Completion {{{1

" Simple keyword completion on all buffers {{{2
function! TodoKeywordComplete(base)
    " Search for matches
    let res = []
    for bufnr in range(1,bufnr('$'))
        let lines=getbufline(bufnr,1,"$")
        for line in lines
            if line =~ a:base
                " init temporary item
                let item={}
                let item.word=substitute(line,'.*\('.a:base.'\S*\).*','\1',"")
                call add(res,item)
            endif
        endfor
    endfor
    return res
endfunction

" Convert an item to the completion format and add it to the completion list
fun! TodoAddToCompletionList(list,item,opp)
    " Create the definitive item
    let resitem={}
    let resitem.word=a:item.word
    let resitem.info=a:opp=='+'?"Projects":"Contexts"
    let resitem.info.=": ".join(a:item.related, ", ")
                \."\nBuffers: ".join(a:item.buffers, ", ")
    call add(a:list,resitem)
endfun

fun! TodoCopyTempItem(item)
    let ret={}
    let ret.word=a:item.word
    if has_key(a:item, "related")
        let ret.related=[a:item.related]
    else
        let ret.related=[]
    endif
    let ret.buffers=[a:item.buffers]
    return ret
endfun

" Intelligent completion for projects and Contexts {{{2
fun! todo#Complete(findstart, base)
    if a:findstart
        let line = getline('.')
        let start = col('.') - 1
        while start > 0 && line[start - 1] !~ '\s'
            let start -= 1
        endwhile
        return start
    else
        if a:base !~ '^+' && a:base !~ '^@'
            return TodoKeywordComplete(a:base)
        endif
        " Opposite sign
        let opp=a:base=~'+'?'@':'+'
        " Search for matchs
        let res = []
        for bufnr in range(1,bufnr('$'))
            let lines=getbufline(bufnr,1,"$")
            for line in lines
                if line =~ " ".a:base
                    " init temporary item
                    let item={}
                    let item.word=substitute(line,'.*\('.a:base.'\S*\).*','\1',"")
                    let item.buffers=bufname(bufnr)
                    if line =~ '.*\s\('.opp.'\S\S*\).*'
                        let item.related=substitute(line,'.*\s\('.opp.'\S\S*\).*','\1',"")
                    endif
                    call add(res,item)
                endif
            endfor
        endfor
        call sort(res)
        " Here all results are sorted in res, but we need to merge them
        let ret=[]
        if res != []
            let curitem=TodoCopyTempItem(res[0])
            for it in res
                if curitem.word==it.word
                    " Merge results
                    if has_key(it, "related") && index(curitem.related,it.related) <0
                        call add(curitem.related,it.related)
                    endif
                    if index(curitem.buffers,it.buffers) <0
                        call add(curitem.buffers,it.buffers)
                    endif
                else
                    " Add to list
                    call TodoAddToCompletionList(ret,curitem,opp)
                    " Init new item from it
                    let curitem=TodoCopyTempItem(it)
                endif
            endfor
            " Don't forget to add the list item
            call TodoAddToCompletionList(ret,curitem,opp)
        endif
        return ret
    endif
endfun

" Highlight {{{1
"
" Role colors follow the active colorscheme. g:Todo_txt_highlight overrides
" individual roles; everything else is applied with "default" so a colorscheme
" can define the same groups itself.

let s:owned_groups = {}

function! todo#ResetHighlightOwnership() abort
    let s:owned_groups = {}
endfunction

function! todo#ApplyHighlight() abort
    if !exists('s:todo_txt_hl_aucmd')
        augroup TodoTxtHighlight
            autocmd!
            autocmd ColorSchemePre * call todo#ResetHighlightOwnership()
            autocmd ColorScheme * call todo#ApplyHighlight()
        augroup END
        let s:todo_txt_hl_aucmd = 1
    endif

    let l:cfg = get(g:, 'Todo_txt_highlight', {})
    if type(l:cfg) != type({})
        echohl ErrorMsg
        echomsg 'Todo.txt: g:Todo_txt_highlight must be a Dictionary'
        echohl None
        let l:cfg = {}
    endif
    let l:inbox_italic = get(l:cfg, 'InboxItalic', 1)
    let l:roles = {
                \ 'A': ['TodoPriorityA'],
                \ 'AMark': ['TodoPriorityAMark'],
                \ 'B': ['TodoPriorityB'],
                \ 'Active': ['TodoActive'],
                \ 'Done': ['TodoDone'],
                \ 'Inbox': ['TodoInbox'],
                \ 'Other': s:OtherPriorityGroups(),
                \ 'Periodic': ['TodoPeriodic'],
                \ }
    " Identifier is the default foreground in github_light, so (B) would match
    " inbox text. Function is a separate hue there (and in most schemes).
    " Active is a fixed lime-yellow field: several tasks can be in progress
    " at once, and the whole line has to read as black on that background.
    let l:defaults = {
                \ 'A': 'Constant',
                \ 'AMark': 'Todo',
                \ 'B': 'Function',
                \ 'Other': 'Type',
                \ 'Inbox': 'Underlined',
                \ 'Done': 'Comment',
                \ 'Periodic': 'Comment',
                \ 'Active': {
                \   'guifg': '#000000',
                \   'guibg': '#D7FF00',
                \   'ctermfg': 16,
                \   'ctermbg': 190,
                \ },
                \ }

    for l:role in keys(l:defaults)
        let l:forced = has_key(l:cfg, l:role)
        let l:spec = l:forced ? l:cfg[l:role] : l:defaults[l:role]
        let l:italic = l:role ==# 'Inbox' && l:inbox_italic
        for l:group in l:roles[l:role]
            call s:ApplyHighlightSpec(l:group, l:spec, l:forced, l:italic, l:role)
        endfor
    endfor

    for [l:group, l:target] in [
                \ ['TodoKey', 'Special'],
                \ ['TodoDate', 'PreProc'],
                \ ['TodoProject', 'Special'],
                \ ['TodoContext', 'Special'],
                \ ['TodoDueToday', 'Todo'],
                \ ['TodoOverDueDate', 'Error'],
                \ ['TodoThresholdDate', 'Comment'],
                \ ]
        execute 'highlight default link ' . l:group . ' ' . l:target
    endfor
endfunction

function! s:OtherPriorityGroups() abort
    if !exists('s:todo_other_groups')
        let s:todo_other_groups = []
        for l:code in range(char2nr('C'), char2nr('Z'))
            " P is the parked stub role, it is highlighted on its own.
            if l:code == char2nr('P')
                continue
            endif
            call add(s:todo_other_groups, 'TodoPriority' . nr2char(l:code))
        endfor
    endif
    return s:todo_other_groups
endfunction

function! s:ApplyHighlightSpec(group, spec, forced, italic, role) abort
    if type(a:spec) == type('')
        call s:ApplyLink(a:group, a:spec, a:forced, a:italic)
    elseif type(a:spec) == type({})
        call s:ApplyAttrs(a:group, a:spec, a:forced, a:italic)
    else
        echohl ErrorMsg
        echomsg 'Todo.txt: g:Todo_txt_highlight.' . a:role . ' must be a group name or a Dictionary'
        echohl None
    endif
endfunction

function! s:SkipHighlight(group, forced) abort
    return !a:forced && s:HighlightDefined(a:group) && !get(s:owned_groups, a:group, 0)
endfunction

function! s:ApplyLink(group, target, forced, italic) abort
    if s:SkipHighlight(a:group, a:forced)
        return
    endif
    if a:italic
        call s:CopyHighlight(a:group, a:target, 1)
    elseif a:forced || get(s:owned_groups, a:group, 0)
        " highlight! link keeps previous attributes in Neovim.
        call s:ForceLink(a:group, a:target)
    else
        execute 'highlight default link ' . a:group . ' ' . a:target
    endif
    let s:owned_groups[a:group] = 1
endfunction

function! s:ForceLink(group, target) abort
    execute 'highlight clear ' . a:group
    execute 'highlight link ' . a:group . ' ' . a:target
endfunction

function! s:ApplyAttrs(group, spec, forced, italic) abort
    if s:SkipHighlight(a:group, a:forced)
        return
    endif
    let l:parts = ['highlight', a:group]
    for l:key in ['term', 'ctermfg', 'ctermbg', 'guifg', 'guibg', 'guisp']
        if has_key(a:spec, l:key)
            call add(l:parts, l:key . '=' . s:HlArg(a:spec[l:key]))
        endif
    endfor
    let l:gui = has_key(a:spec, 'gui') ? s:HlArg(a:spec.gui) : ''
    let l:cterm = has_key(a:spec, 'cterm') ? s:HlArg(a:spec.cterm) : ''
    if a:italic && !has_key(a:spec, 'gui') && !has_key(a:spec, 'cterm')
        let l:gui = s:AddAttr(l:gui, 'italic')
        let l:cterm = s:AddAttr(l:cterm, 'italic')
    endif
    if l:gui !=# ''
        call add(l:parts, 'gui=' . l:gui)
    endif
    if l:cterm !=# ''
        call add(l:parts, 'cterm=' . l:cterm)
    endif
    if len(l:parts) > 2
        execute 'highlight clear ' . a:group
        execute join(l:parts, ' ')
        let s:owned_groups[a:group] = 1
    endif
endfunction

function! s:CopyHighlight(group, target, italic) abort
    let l:id = synIDtrans(hlID(a:target))
    if l:id == 0
        call s:ForceLink(a:group, a:target)
        return
    endif
    execute 'highlight clear ' . a:group
    let l:parts = ['highlight', a:group]
    let l:guifg = synIDattr(l:id, 'fg', 'gui')
    let l:guibg = synIDattr(l:id, 'bg', 'gui')
    let l:guisp = synIDattr(l:id, 'sp', 'gui')
    let l:ctermfg = synIDattr(l:id, 'fg', 'cterm')
    let l:ctermbg = synIDattr(l:id, 'bg', 'cterm')
    if l:guifg !=# ''
        call add(l:parts, 'guifg=' . l:guifg)
    endif
    if l:guibg !=# ''
        call add(l:parts, 'guibg=' . l:guibg)
    endif
    if l:guisp !=# ''
        call add(l:parts, 'guisp=' . l:guisp)
    endif
    if l:ctermfg !=# ''
        call add(l:parts, 'ctermfg=' . l:ctermfg)
    endif
    if l:ctermbg !=# ''
        call add(l:parts, 'ctermbg=' . l:ctermbg)
    endif
    let l:gui = s:AttrString(l:id, 'gui')
    let l:cterm = s:AttrString(l:id, 'cterm')
    let l:term = s:AttrString(l:id, 'term')
    if a:italic
        let l:gui = s:AddAttr(l:gui, 'italic')
        let l:cterm = s:AddAttr(l:cterm, 'italic')
    endif
    if l:term !=# ''
        call add(l:parts, 'term=' . l:term)
    endif
    if l:gui !=# ''
        call add(l:parts, 'gui=' . l:gui)
    endif
    if l:cterm !=# ''
        call add(l:parts, 'cterm=' . l:cterm)
    endif
    if len(l:parts) == 2
        call s:ForceLink(a:group, a:target)
        return
    endif
    execute join(l:parts, ' ')
endfunction

function! s:AttrString(id, mode) abort
    let l:names = ['bold', 'underline', 'undercurl', 'reverse', 'inverse', 'italic', 'standout']
    let l:on = []
    for l:name in l:names
        if synIDattr(a:id, l:name, a:mode) ==# '1'
            call add(l:on, l:name)
        endif
    endfor
    return join(l:on, ',')
endfunction

function! s:AddAttr(attrs, name) abort
    if a:attrs ==# '' || a:attrs ==# 'NONE'
        return a:name
    endif
    if a:attrs =~# '\<' . a:name . '\>'
        return a:attrs
    endif
    return a:attrs . ',' . a:name
endfunction

function! s:HlArg(val) abort
    return type(a:val) == type(0) ? string(a:val) : a:val
endfunction

function! s:HighlightDefined(group) abort
    redir => l:out
    silent! execute 'highlight ' . a:group
    redir END
    if l:out =~# 'not found' || l:out =~# 'No highlight groups' || l:out =~# 'xxx cleared'
        return 0
    endif
    return l:out =~# 'xxx'
endfunction

" vim: tabstop=4 shiftwidth=4 softtabstop=4 expandtab foldmethod=marker
