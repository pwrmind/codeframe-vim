let s:frames = {}
let s:current_file = ''
let s:canvas_bufnr = -1

function! codeframe#Enable() abort
    " Проверка тегов при перемещении курсора
    augroup CodeFrame
        autocmd! * <buffer>
        autocmd CursorMoved <buffer> call s:CheckTagLine()
        autocmd BufWritePost <buffer> call s:SaveFrameSizes()
    augroup END

    " Инициализация только для .cf файлов
    if expand('%:e') == 'cf'
        let s:canvas_bufnr = bufnr('%')
        let s:frames = {}
        let s:current_file = ''
        call s:ParseCanvas()
    endif
endfunction

function! s:ParseCanvas() abort
    let lines = getline(1, '$')
    
    for idx in range(len(lines))
        let line = lines[idx]
        if line =~# '^+++'
            let s:current_file = substitute(line, '^+++\s*', '', '')
        elseif line =~# '^@@ +\d\+,\d\+ @@$'
            let match = matchlist(line, '^@@ +\(\d\+\),\(\d\+\) @@$')
            if !empty(match)
                let start_line = str2nr(match[1])
                let line_count = str2nr(match[2])
                
                " Проверка существования файла
                if !filereadable(s:current_file)
                    echoerr 'File not found:' s:current_file
                    continue
                endif
                
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
    " Сохраняем текущее окно
    let current_win = winnr()
    
    " Создаём новое окно
    execute 'keepalt belowright split #' . a:frame.bufnr
    execute 'resize ' . a:frame.line_count
    execute 'normal! ' . a:frame.start_line . 'ggzt'
    setlocal scrolloff=0
    setlocal winfixheight
    
    " Возвращаемся к холсту
    execute current_win . 'wincmd w'
endfunction

function! s:CheckTagLine() abort
    let line = getline('.')
    if line =~# '^@@ +\d\+,\d\+ @@$'
        nnoremap <buffer> <silent> <S-Up> :call <SID>ShiftFrame(-1)<CR>
        nnoremap <buffer> <silent> <S-Down> :call <SID>ShiftFrame(1)<CR>
    else
        silent! nunmap <buffer> <S-Up>
        silent! nunmap <buffer> <S-Down>
    endif
endfunction

function! s:ShiftFrame(direction) abort
    let lnum = line('.')
    if has_key(s:frames, lnum)
        let frame = s:frames[lnum]
        let new_start = frame.start_line + a:direction
        
        " Проверка границ файла
        let max_lines = line('$', frame.bufnr)
        if new_start < 1 || new_start > max_lines
            return
        endif
        
        let frame.start_line = new_start
        call s:UpdateFrameDisplay(frame, lnum)
    endif
endfunction

function! s:UpdateFrameDisplay(frame, lnum) abort
    " Обновление тега
    let tag_line = '@@ +' . a:frame.start_line . ',' . a:frame.line_count . ' @@'
    call setline(a:lnum, tag_line)
    
    " Обновление содержимого в окне
    let win_id = bufwinid(a:frame.bufnr)
    if win_id > 0
        call win_execute(win_id, 'normal! ' . a:frame.start_line . 'ggzt')
    endif
endfunction

function! s:SaveFrameSizes() abort
    if expand('%:e') != 'cf' | return | endif

    for [lnum, frame] in items(s:frames)
        let win_id = bufwinid(frame.bufnr)
        if win_id > 0
            let height = winheight(win_id)
            if height != frame.line_count
                let frame.line_count = height
                call setline(lnum, '@@ +' . frame.start_line . ',' . height . ' @@')
            endif
        endif
    endfor
endfunction