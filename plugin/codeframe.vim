" Глобальные переменные для хранения состояний
let s:frames = {}
let s:current_file = ''
let s:canvas_bufnr = -1

function! codeframe#Enable() abort
    " Проверка тегов при перемещении курсора
    augroup codeframe
        autocmd!
        autocmd CursorMoved * call s:CheckTagLine()
        autocmd BufWritePost * call s:SaveFrameSizes()
    augroup END

    " Инициализация холста
    if expand('%:e') == 'ccv'
        let s:canvas_bufnr = bufnr('%')
        call s:ParseCanvas()
    endif
endfunction

function! s:ParseCanvas() abort
    let lines = getline(1, '$')
    let current_file = ''
    let frame_start = 0

    for idx in range(len(lines))
        let line = lines[idx]
        if line =~# '^+++'
            let s:current_file = substitute(line, '^+++\s*', '', '')
        elseif line =~# '^@@ +\d\+,\d\+ @@$'
            let match = matchlist(line, '^@@ +\(\d\+\),\(\d\+\) @@$')
            if !empty(match)
                let start_line = str2nr(match[1])
                let line_count = str2nr(match[2])
                let frame_info = {
                    \ 'file': s:current_file,
                    \ 'start_line': start_line,
                    \ 'line_count': line_count,
                    \ 'bufnr': bufnr(s:current_file, 1)
                    \ }
                let s:frames[idx+1] = frame_info
                call s:CreateFrameWindow(frame_info)
            endif
        endif
    endfor
endfunction

function! s:CreateFrameWindow(frame) abort
    " Создание окна фрейма
    execute 'split #' . a:frame.bufnr
    execute 'resize ' . a:frame.line_count
    execute 'normal! ' . a:frame.start_line . 'ggzt'
    setlocal scrolloff=0
    wincmd p
endfunction

function! s:CheckTagLine() abort
    " Активация горячих клавиш только на тегах
    let line = getline('.')
    if line =~# '^@@ +\d\+,\d\+ @@$'
        nnoremap <buffer> <silent> <S-Up> :call <SID>ShiftFrame(-1)<CR>
        nnoremap <buffer> <silent> <S-Down> :call <SID>ShiftFrame(1)<CR>
    else
        silent! unmap <buffer> <S-Up>
        silent! unmap <buffer> <S-Down>
    endif
endfunction

function! s:ShiftFrame(direction) abort
    " Смещение фрейма
    let lnum = line('.')
    if has_key(s:frames, lnum)
        let frame = s:frames[lnum]
        let new_start = frame.start_line + a:direction
        if new_start > 0
            let frame.start_line = new_start
            call s:UpdateFrameDisplay(frame, lnum)
        endif
    endif
endfunction

function! s:UpdateFrameDisplay(frame, lnum) abort
    " Обновление отображения фрейма
    let content = getbufline(a:frame.bufnr, a:frame.start_line, a:frame.start_line + a:frame.line_count - 1)
    let tag_line = '@@ +' . a:frame.start_line . ',' . a:frame.line_count . ' @@'
    call setline(a:lnum, tag_line)
    call setline(a:lnum+1, content)
endfunction

function! s:SaveFrameSizes() abort
    " Сохранение размеров фреймов
    if expand('%:e') != 'ccv' | return | endif

    for [lnum, frame] in items(s:frames)
        let winid = bufwinid(frame.bufnr)
        if winid != -1
            let frame.line_count = winheight(winid)
            call setline(lnum, '@@ +' . frame.start_line . ',' . frame.line_count . ' @@')
        endif
    endfor
endfunction