let s:frames = {}
let s:current_file = ''
let s:base_dir = ''

function! codeframe#Enable() abort
    " Определяем базовую директорию для относительных путей
    let s:base_dir = expand('%:p:h')
    call s:Debug('Base directory: ' . s:base_dir)
    
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

function! s:ResolvePath(rel_path) abort
    " Преобразуем относительный путь в абсолютный
    if a:rel_path[0] == '/' || a:rel_path =~? '^[a-z]:\\'
        return a:rel_path
    endif
    return simplify(s:base_dir . '/' . a:rel_path)
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
            let rel_path = substitute(line, '^+++\s*', '', '')
            let s:current_file = s:ResolvePath(rel_path)
            call s:Debug('Found source file (relative: ' . rel_path . ' | absolute: ' . s:current_file . ')')
            let i += 1
            continue
        endif
        
        if line =~# '^@@ +\d\+,\d\+ @@$'
            let match = matchlist(line, '^@@ +\(\d\+\),\(\d\+\) @@$')
            if !empty(match)
                let start_line = str2nr(match[1])
                let line_count = str2nr(match[2])
                
                " Проверяем существование файла
                if !filereadable(s:current_file)
                    call s:Debug('File not readable: ' . s:current_file)
                    let i += 1
                    continue
                endif
                
                call s:Debug('Loading frame: ' . s:current_file . ' lines:' . start_line . '-' . (start_line+line_count-1))
                
                " Читаем содержимое исходного файла
                let content = readfile(s:current_file, '', start_line + line_count)
                let frame_lines = []
                
                if len(content) >= start_line
                    let frame_lines = content[start_line-1 : start_line + line_count - 2]
                else
                    let frame_lines = ['ERROR: File too short (has ' . len(content) . ' lines)']
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
                    \ 'rel_path': rel_path,
                    \ 'start_line': start_line,
                    \ 'line_count': line_count,
                    \ 'content': frame_lines
                    \ }
                
                " Обновляем список строк
                let lines = getline(1, '$')
                let i += len(frame_lines) + 1
            else
                let i += 1
            endif
        else
            let i += 1
        endif
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
                let current_rel_path = ''
                let search_line = lnum - 1
                while search_line >= 1
                    let prev_line = getline(search_line)
                    if prev_line =~# '^+++'
                        let current_rel_path = substitute(prev_line, '^+++\s*', '', '')
                        let current_file = s:ResolvePath(current_rel_path)
                        break
                    endif
                    let search_line -= 1
                endwhile
                
                if !empty(current_file) && filereadable(current_file)
                    " Обновляем содержимое фрейма
                    let content = readfile(current_file, '', new_start + line_count)
                    let frame_lines = []
                    
                    if len(content) >= new_start
                        let frame_lines = content[new_start-1 : new_start + line_count - 2]
                    else
                        let frame_lines = ['ERROR: File too short (has ' . len(content) . ' lines)']
                    endif
                    
                    " Заменяем содержимое фрейма
                    silent execute (lnum+1) . ',' . (lnum+line_count) . 'd _'
                    call append(lnum, frame_lines)
                    
                    " Обновляем тег
                    let new_tag = '@@ +' . new_start . ',' . line_count . ' @@'
                    call setline(lnum, new_tag)
                    
                    " Обновляем информацию о фрейме
                    let s:frames[lnum] = {
                        \ 'file': current_file,
                        \ 'rel_path': current_rel_path,
                        \ 'start_line': new_start,
                        \ 'line_count': line_count,
                        \ 'content': frame_lines
                        \ }
                    
                    call s:Debug('Frame shifted to: ' . new_start)
                else
                    call s:Debug('File not readable: ' . current_file)
                endif
            endif
        endif
    endif
endfunction

function! s:WriteFrames() abort
    call s:Debug('Saving frames to source files...')
    let saved_files = {}
    
    for [lnum, frame] in items(s:frames)
        if has_key(saved_files, frame.file)
            continue
        endif
        
        if filereadable(frame.file)
            " Читаем весь исходный файл
            let content = readfile(frame.file)
            let new_content = []
            
            " Получаем актуальное содержимое фрейма
            let frame_lines = getline(lnum+1, lnum+frame.line_count)
            
            " Заменяем блок в исходном файле
            let replaced = 0
            for i in range(len(content))
                if i+1 == frame.start_line
                    let new_content += frame_lines
                    let replaced = 1
                    let i += frame.line_count - 1
                else
                    call add(new_content, content[i])
                endif
            endfor
            
            " Если блок выходит за пределы файла
            if !replaced && frame.start_line > len(content)
                let new_content += repeat([''], frame.start_line - len(content) - 1)
                let new_content += frame_lines
            endif
            
            " Записываем изменения
            call writefile(new_content, frame.file)
            call s:Debug('Saved ' . len(frame_lines) . ' lines to: ' . frame.file)
            let saved_files[frame.file] = 1
        else
            call s:Debug('File not writable: ' . frame.file)
        endif
    endfor
    call s:Debug('All frames saved')
endfunction