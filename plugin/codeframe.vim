let s:frames = {}
let s:current_file = ''

function! codeframe#Enable() abort
    augroup CodeFrame
        autocmd! * <buffer>
        autocmd BufReadPost <buffer> call s:LoadFrames()
        autocmd CursorMoved <buffer> call s:CheckTagLine()
        autocmd BufWritePre <buffer> call s:WriteFrames()
    augroup END

    if expand('%:e') == 'cf'
        call s:Debug('Plugin activated for: ' . expand('%'))
        call s:LoadFrames()
    endif
endfunction

function! s:Debug(msg)
    echom '[CodeFrame] ' . a:msg
endfunction

function! s:LoadFrames() abort
    call s:Debug('Loading frames...')
    let lines = getline(1, '$')
    let s:frames = {}
    let s:current_file = ''
    let i = 1

    while i <= len(lines)
        let line = lines[i-1]
        
        if line =~# '^+++'
            let s:current_file = substitute(line, '^+++\s*', '', '')
            call s:Debug('Found source file: ' . s:current_file)
            let i += 1
            continue
        endif
        
        if line =~# '^@@ +\d\+,\d\+ @@$'
            let match = matchlist(line, '^@@ +\(\d\+\),\(\d\+\) @@$')
            if !empty(match)
                let start_line = str2nr(match[1])
                let line_count = str2nr(match[2])
                call s:Debug('Found frame: ' . s:current_file . ' lines:' . start_line . '-' . (start_line+line_count-1))
                
                if filereadable(s:current_file)
                    " Читаем содержимое исходного файла
                    let content = readfile(s:current_file, '', start_line + line_count)
                    if len(content) >= start_line
                        let frame_lines = content[start_line-1 : start_line + line_count - 2]
                    else
                        let frame_lines = ['ERROR: File too short']
                    endif
                    
                    " Заменяем текущее содержимое фрейма
                    let end_line = i + line_count
                    if end_line > len(lines)
                        let end_line = len(lines)
                    endif
                    
                    silent execute (i+1) . ',' . end_line . 'd _'
                    call append(i, frame_lines)
                    
                    " Сохраняем информацию о фрейме
                    let s:frames[i] = {
                        \ 'file': s:current_file,
                        \ 'start_line': start_line,
                        \ 'line_count': line_count,
                        \ 'content': frame_lines
                        \ }
                    
                    " Обновляем список строк
                    let lines = getline(1, '$')
                    let i += len(frame_lines)
                else
                    call s:Debug('File not readable: ' . s:current_file)
                endif
            endif
        endif
        
        let i += 1
    endwhile
    call s:Debug('Frames loaded successfully')
endfunction

function! s:CheckTagLine() abort
    let line = getline('.')
    if line =~# '^@@ +\d\+,\d\+ @@$'
        call s:Debug('Cursor on frame tag: ' . line)
        nnoremap <buffer> <silent> <S-Up> :call <SID>ShiftFrame(-1)<CR>
        nnoremap <buffer> <silent> <S-Down> :call <SID>ShiftFrame(1)<CR>
    else
        silent! nunmap <buffer> <S-Up>
        silent! nunmap <buffer> <S-Down>
    endif
endfunction

function! s:ShiftFrame(direction) abort
    let lnum = line('.')
    let line = getline(lnum)
    
    if line =~# '^@@ +\d\+,\d\+ @@$'
        let match = matchlist(line, '^@@ +\(\d\+\),\(\d\+\) @@$')
        if !empty(match)
            let start_line = str2nr(match[1])
            let line_count = str2nr(match[2])
            let new_start = start_line + a:direction
            
            if new_start > 0
                " Находим исходный файл для этого фрейма
                let current_file = ''
                let search_line = lnum - 1
                while search_line >= 1
                    let prev_line = getline(search_line)
                    if prev_line =~# '^+++'
                        let current_file = substitute(prev_line, '^+++\s*', '', '')
                        break
                    endif
                    let search_line -= 1
                endwhile
                
                if !empty(current_file) && filereadable(current_file)
                    " Обновляем содержимое фрейма
                    let content = readfile(current_file, '', new_start + line_count)
                    if len(content) >= new_start
                        let frame_lines = content[new_start-1 : new_start + line_count - 2]
                    else
                        let frame_lines = ['ERROR: File too short']
                    endif
                    
                    " Заменяем содержимое фрейма
                    silent execute (lnum+1) . ',' . (lnum+line_count) . 'd _'
                    call append(lnum, frame_lines)
                    
                    " Обновляем тег
                    call setline(lnum, '@@ +' . new_start . ',' . line_count . ' @@')
                    
                    " Обновляем информацию о фрейме
                    let s:frames[lnum] = {
                        \ 'file': current_file,
                        \ 'start_line': new_start,
                        \ 'line_count': line_count,
                        \ 'content': frame_lines
                        \ }
                    
                    call s:Debug('Frame shifted to: ' . new_start)
                endif
            endif
        endif
    endif
endfunction

function! s:WriteFrames() abort
    call s:Debug('Saving frames to source files...')
    for [lnum, frame] in items(s:frames)
        if filereadable(frame.file)
            " Читаем весь исходный файл
            let content = readfile(frame.file)
            let new_content = []
            
            " Получаем актуальное содержимое фрейма
            let frame_lines = getline(lnum+1, lnum+frame.line_count)
            
            " Заменяем блок в исходном файле
            for i in range(len(content))
                if i == frame.start_line - 1
                    let new_content += frame_lines
                    let i += frame.line_count - 1
                else
                    if i < len(content)
                        call add(new_content, content[i])
                    endif
                endif
            endfor
            
            " Если блок выходит за пределы файла
            if frame.start_line > len(content)
                let new_content += repeat([''], frame.start_line - len(content) - 1)
                let new_content += frame_lines
            endif
            
            " Записываем изменения
            call writefile(new_content, frame.file)
            call s:Debug('Saved ' . len(frame_lines) . ' lines to: ' . frame.file)
        else
            call s:Debug('File not writable: ' . frame.file)
        endif
    endfor
    call s:Debug('All frames saved')
endfunction