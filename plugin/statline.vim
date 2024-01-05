" ============================================================================
" File:        statline.vim
" Maintainer:  Miller Medeiros <http://blog.millermedeiros.com/>
" Description: Add useful info to the statusline and basic error checking.
" Last Change: 2011-11-10
" License:     This program is free software. It comes without any warranty,
"              to the extent permitted by applicable law. You can redistribute
"              it and/or modify it under the terms of the Do What The Fuck You
"              Want To Public License, Version 2, as published by Sam Hocevar.
"              See http://sam.zoy.org/wtfpl/COPYING for more details.
" ============================================================================

if exists("g:loaded_statline_plugin")
    finish
endif
let g:loaded_statline_plugin = 1


" always display statusline (iss #3)
set laststatus=2

function! StatlineScrollbar(...)
    let top_line = line("w0")
    let bottom_line = line("w$")
    let current_line = line('.')
    let lines_count = line('$')

    " Default values
    let length = 20
    let tracksymbol = '-'
    let grippersymbol = '#'
    let gripperleftsymbols = []
    let gripperrightsymbols = []
    let part = 'a'

    if a:0 >= 3
      let length = a:1
      let tracksymbol = a:2
      let grippersymbol = a:3
    endif

    if a:0 >= 5 && type(a:4) == 3 && type(a:5) == 3
                \ && len(a:4) == len(a:5) 
        let gripperleftsymbols = a:4
        let gripperrightsymbols = a:5
    endif

    if a:0 >= 6
      let part = a:6
    endif

    let scaling = len(gripperleftsymbols) + 1 

    " Compute gripper position and size as if we have scaling times a:1
    " characters available. Will shrink everything back just before returning 
    let scrollbar_length = str2nr(length) * scaling

    " Gripper positions are 0 based (0..scrollbar_length-1)
    let gripper_position = float2nr((top_line - 1.0) / lines_count 
\       * scrollbar_length)
    let gripper_length = float2nr(ceil((bottom_line - top_line + 1.0)  
\       / lines_count * scrollbar_length)) 

    " Users expect to see the scrollbar in the leftmost position only if we
    " are at the very top of the buffer
    if (top_line > 1) && (gripper_position == 0)
        " Since the top line is not visible shift the gripper by one position
        let gripper_position = 1
        if (gripper_position + gripper_length > scrollbar_length)
            " Shrink the gripper if we end up after the end of the scrollbar 
            let gripper_length = gripper_length - 1
        endif
    endif

    if (bottom_line < lines_count) 
\       && (gripper_position + gripper_length == scrollbar_length)
        " As before, if the last line is not on the screen but the scrollbar
        " seems to indicate so then either move the scrollbar position leftwise
        " by one position or decrease its length
        if gripper_position > 0
            let gripper_position = gripper_position - 1
        else
            let gripper_length = gripper_length - 1
        endif
    endif

    " Shrink everything back to the range [0, a:1)
    let gripper_position = 1.0 * gripper_position / scaling
    let gripper_length = 1.0 * gripper_length / scaling
    let scrollbar_length = 1.0 * scrollbar_length / scaling

    " The left of the gripper is broken in 3 parts.  The left and right are
    " fractionals in the range [0, len(a:4)). 
    let gripper_length_left = ceil(gripper_position) - gripper_position
    " Hackish rounding errors workaround. If `gripper_length
    " - gripper_lenght_left` is 0.9999.. we force it to 1 before rounding it
    let gripper_length_middle = floor(round((gripper_length 
                \ - gripper_length_left)*100.0)/100.0)
    let gripper_length_right = gripper_length - gripper_length_left 
                \ - gripper_length_middle

    " Time to assemble the actual scrollbar
    let scrollbar = ''
    if part != 'm' && part != 'r'
        let scrollbar .= repeat(tracksymbol, float2nr(floor(gripper_position)))

        let grippersymbol_index = float2nr(round(gripper_length_left * scaling))
        if grippersymbol_index != 0
            let scrollbar .= gripperleftsymbols[grippersymbol_index - 1]
        endif
    endif
    
    if part != 'l' && part != 'r'
        let scrollbar .= repeat(grippersymbol, float2nr(gripper_length_middle)) 
    endif

    if part != 'l' && part != 'm'
        let grippersymbol_index = float2nr(round(gripper_length_right * scaling))
        if grippersymbol_index != 0
            let scrollbar .= gripperrightsymbols[grippersymbol_index - 1]
        endif
        let scrollbar .= repeat(tracksymbol, float2nr(scrollbar_length 
                    \ - ceil(gripper_position + gripper_length)))
    endif

    return scrollbar
endfunction

" ====== colors ======

" using link instead of named highlight group inside the statusline to make it
" easier to customize, reseting the User[n] highlight will remove the link.
" Another benefit is that colors will adapt to colorscheme.

"filename
hi default link User1 Identifier
" flags
hi default link User2 Statement
" errors
hi default link User3 Error
" fugitive
hi default link User4 Special



" ====== basic info ======

" ---- number of buffers : buffer number ----

function! StatlineBufCount()
    if !exists("s:statline_n_buffers")
        let s:statline_n_buffers = len(filter(range(1,bufnr('$')), 'buflisted(v:val)'))
    endif
    return s:statline_n_buffers
endfunction

if !exists('g:statline_show_n_buffers')
    let g:statline_show_n_buffers = 1
endif

if g:statline_show_n_buffers
    set statusline=[%{StatlineBufCount()}\:%n]\ %<
    " only calculate buffers after adding/removing buffers
    augroup statline_nbuf
        autocmd!
        autocmd BufAdd,BufDelete * unlet! s:statline_n_buffers
    augroup END
else
    set statusline=[%n]\ %<
endif


" ---- filename (relative or tail) ----

if exists('g:statline_filename_relative')
    set statusline+=%1*[%f]%*
else
    set statusline+=%1*[%t]%*
endif


" ---- flags ----

" (h:help:[help], w:window:[Preview], m:modified:[+][-], r:readonly:[RO])
set statusline+=%2*%h%w%m%r%*


" ---- filetype ----

set statusline+=\ %y


" ---- file format → file encoding ----

if &encoding == 'utf-8'
    let g:statline_encoding_separator = '→'
else
    let g:statline_encoding_separator = ':'
endif

if !exists('g:statline_show_encoding')
    let g:statline_show_encoding = 1
endif
if !exists('g:statline_no_encoding_string')
    let g:statline_no_encoding_string = 'No Encoding'
endif
if g:statline_show_encoding
    set statusline+=[%{&ff}%{g:statline_encoding_separator}%{strlen(&fenc)?&fenc:g:statline_no_encoding_string}]
endif


" ---- separation between left/right aligned items ----

set statusline+=%=


" ---- current line and column ----

" (-:left align, 14:minwid, l:line, L:nLines, c:column)
set statusline+=%-14(\ L%l/%L:C%c\ %)


" ----  scroll percent ----

set statusline+=%P

set statusline+=\ [%{StatlineScrollbar(16,'⠀','⠿')}]\ 


" ---- code of character under cursor ----

if !exists('g:statline_show_charcode')
    let g:statline_show_charcode = 0
endif
if g:statline_show_charcode
    " (b:num, B:hex)
    set statusline+=%9(\ \%b/0x\%B%)
endif



" ====== plugins ======


" ---- RVM ----

if !exists('g:statline_rvm')
    let g:statline_rvm = 0
endif
if g:statline_rvm
    set statusline+=%{exists('g:loaded_rvm')?rvm#statusline():''}
endif


" ---- rbenv ----

if !exists('g:statline_rbenv')
    let g:statline_rbenv = 0
endif
if g:statline_rbenv
    set statusline+=%{exists('g:loaded_rbenv')?rbenv#statusline():''}
endif


" ---- Fugitive ----

if !exists('g:statline_fugitive')
    let g:statline_fugitive = 0
endif
if g:statline_fugitive
    set statusline+=%4*%{exists('g:loaded_fugitive')?fugitive#statusline():''}%*
endif


" ---- Syntastic errors ----

if !exists('g:statline_syntastic')
    let g:statline_syntastic = 1
endif
if g:statline_syntastic
    set statusline+=\ %3*%{exists('g:loaded_syntastic_plugin')?SyntasticStatuslineFlag():''}%*
endif



" ====== custom errors ======


" based on @scrooloose whitespace flags
" http://got-ravings.blogspot.com/2008/10/vim-pr0n-statusline-whitespace-flags.html


" ---- mixed indenting ----

if !exists('g:statline_mixed_indent')
    let g:statline_mixed_indent = 1
endif

if !exists('g:statline_mixed_indent_string')
    let g:statline_mixed_indent_string = '[mix]'
endif

"return '[&et]' if &et is set wrong
"return '[mixed-indenting]' if spaces and tabs are used to indent
"return an empty string if everything is fine
function! StatlineTabWarning()
    if !exists("b:statline_indent_warning")
        let b:statline_indent_warning = ''

        if !&modifiable
            return b:statline_indent_warning
        endif

        let tabs = search('^\t', 'nw') != 0

        "find spaces that arent used as alignment in the first indent column
        let spaces = search('^ \{' . &ts . ',}[^\t]', 'nw') != 0

        if tabs && spaces
            let b:statline_indent_warning = g:statline_mixed_indent_string
        elseif (spaces && !&et) || (tabs && &et)
            let b:statline_indent_warning = '[&et]'
        endif
    endif
    return b:statline_indent_warning
endfunction

if g:statline_mixed_indent
    set statusline+=%3*%{StatlineTabWarning()}%*

    " recalculate when idle and after writing
    augroup statline_indent
        autocmd!
        autocmd cursorhold,bufwritepost * unlet! b:statline_indent_warning
    augroup END
endif


" --- trailing white space ---

if !exists('g:statline_trailing_space')
    let g:statline_trailing_space = 1
endif

function! StatlineTrailingSpaceWarning()
    if !exists("b:statline_trailing_space_warning")
        if search('\s\+$', 'nw') != 0
            let b:statline_trailing_space_warning = '[\s]'
        else
            let b:statline_trailing_space_warning = ''
        endif
    endif
    return b:statline_trailing_space_warning
endfunction

if g:statline_trailing_space
    set statusline+=%3*%{StatlineTrailingSpaceWarning()}%*

    " recalculate when idle, and after saving
    augroup statline_trail
        autocmd!
        autocmd cursorhold,bufwritepost * unlet! b:statline_trailing_space_warning
    augroup END
endif
