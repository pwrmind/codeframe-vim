let s:frames = {}
let s:base_dir = ''
let s:is_loading = 0

function! codeframe#Enable() abort
    " Устанавливаем базовый каталог для относительных путей
    let s:base_dir = expand('%:p:h')
    call s:Debug('Base directory: ' . s:base_dir)
    
    " Автокоманды
    augroup CodeFrame
        autocmd! * <buffer>
        autocmd BufEnter <buffer> call s:LoadFrames()
        autocmd CursorMoved <buffer> call s:CheckTagLine()
        autocmd BufWritePre <buffer> call s:WriteFrames()
    augroup END
    
    " Загружаем фреймы при активации
    call s:LoadFrames()
endfunction

function! s:Debug(msg)
    echom '[CodeFrame] ' . a:msg
endfunction

function! s:ResolvePath(rel_path) abort
    " Преобразуем относительный путь в абсолютный
    if a:rel_path =~# '^/' || a:rel_path =~? '^[a-z]:\\'
        return a:rel_path
    endif
    return simplify(s:base_dir . '/' . a:rel_path)
endfunction

function! s:LoadFrames() abort
    if s:is_loading | return | endif
    let s:is_loading = 1
    
    call s:Debug('Loading frames for: ' . expand('%'))
    let s:frames = {}
    let current_file = ''
    let lines = getline(1, '$')
    let changed = 0
    
    let i = 1
    while i <= len(lines)
        let line = lines[i-1]
        
        if line =~# '^+++'
            " Обработка нового файла
            let rel_path = substitute(line, '^+++\s*', '', '')
            let abs_path = s:ResolvePath(rel_path)
            let current_file = abs_path
            call s:Debug('Source file: ' . rel_path . ' → ' . abs_path)
            let i += 1
            continue
        endif
        
        if line =~# '^@@ +\d\+,\d\+ @@$'
            " Обработка фрейма
            let match = matchlist(line, '^@@ +\(\d\+\),\(\d\+\) @@$')
            if !empty(match) && !empty(current_file)
                let start_line = str2nr(match[1])
                let line_count = str2nr(match[2])
                
                " Сохраняем информацию о фрейме
                let s:frames[i] = {
                    \ 'file': current_file,
                    \ 'rel_path': rel_path,
                    \ 'start_line': start_line,
                    \ 'line_count': line_count
                    \ }
                
                " Загружаем данные из исходного файла
                let content = []
                if filereadable(current_file)
                    let all_lines = readfile(current_file)
                    if start_line <= len(all_lines)
                        let end_line = start_line + line_count - 1
                        if end_line > len(all_lines)
                            let end_line = len(all_lines)
                        endif
                        let content = all_lines[(start_line-1):(end_line-1)]
                    else
                        let content = ['ERROR: Start line beyond file end']
                    endif
                else
                    let content = ['ERROR: File not found: ' . current_file]
                endif
                
                " Проверяем, совпадает ли текущее содержимое
                let current_content = []
                if i < len(lines)
                    let current_content = lines[i : i + line_count - 1]
                endif
                
                " Обновляем, если содержимое отличается
                if content != current_content
                    call s:Debug('Updating frame at line ' . i . ' with ' . len(content) . ' lines')
                    
                    " Удаляем старое содержимое
                    let end_idx = i + line_count
                    if end_idx > len(lines)
                        let end_idx = len(lines)
                    endif
                    
                    " Заменяем содержимое
                    silent execute (i+1) . ',' . end_idx . 'd _'
                    call append(i, content)
                    
                    " Обновляем список строк
                    let lines = getline(1, '$')
                    let changed = 1
                endif
                
                " Пропускаем строки контента
                let i += len(content) + 1
            else
                let i += 1
            endif
        else
            let i += 1
        endif
    endwhile
    
    if changed
        call s:Debug('Frames updated successfully')
    else
        call s:Debug('No changes needed')
    endif
    
    let s:is_loading = 0
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
    if !has_key(s:frames, lnum)
        call s:Debug('No frame found at line: ' . lnum)
        return
    endif
    
    let frame = s:frames[lnum]
    let new_start = frame.start_line + a:direction
    
    " Проверяем границы файла
    let max_line = 0
    if filereadable(frame.file)
        let max_line = len(readfile(frame.file))
    endif
    
    if new_start < 1
        call s:Debug('Start line cannot be less than 1')
        return
    endif
    
    if max_line > 0 && new_start > max_line
        call s:Debug('Start line beyond file end: ' . new_start . ' > ' . max_line)
        return
    endif
    
    " Обновляем фрейм
    let frame.start_line = new_start
    let s:frames[lnum] = frame
    
    " Обновляем тег
    call setline(lnum, '@@ +' . new_start . ',' . frame.line_count . ' @@')
    
    " Перезагружаем содержимое
    call s:LoadFrames()
    call s:Debug('Frame shifted to: ' . new_start)
endfunction

function! s:WriteFrames() abort
    if s:is_loading | return | endif
    call s:Debug('Saving frames to source files...')
    
    let saved_files = {}
    
    for [tag_line, frame] in items(s:frames)
        " Пропускаем, если файл уже сохранен
        if has_key(saved_files, frame.file)
            continue
        endif
        
        let content_line = tag_line + 1
        let content = getline(content_line, content_line + frame.line_count - 1)
        
        if filereadable(frame.file)
            " Читаем весь файл
            let file_content = readfile(frame.file)
            
            " Обновляем нужный диапазон
            if frame.start_line <= len(file_content)
                let end_idx = frame.start_line + frame.line_count - 1
                if end_idx > len(file_content)
                    let end_idx = len(file_content)
                endif
                
                let file_content[frame.start_line-1 : end_idx-1] = content
            else
                " Если диапазон за пределами файла, дополняем пустыми строками
                if frame.start_line > len(file_content)
                    let file_content += repeat([''], frame.start_line - len(file_content) - 1)
                endif
                let file_content += content
            endif
            
            " Сохраняем изменения
            call writefile(file_content, frame.file)
            call s:Debug('Saved ' . len(content) . ' lines to: ' . frame.file)
            let saved_files[frame.file] = 1
        else
            call s:Debug('File not found, skipping: ' . frame.file)
        endif
    endfor
    
    call s:Debug('All frames saved successfully')
endfunction