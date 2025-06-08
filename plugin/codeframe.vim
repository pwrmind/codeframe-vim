" Файл: ~/.vim/plugined/multi_frame.vim

echo 'Определяем глобальные переменные'
let g:frames = []
let g:current_frame = 0

function! LoadFrames()
    echo 'Функция для загрузки файлов и создания фреймов'
    let l:lines = getline(1, '$')
    let l:current_file = ''
    let l:frame = []

    for l:line in l:lines
        if l:line =~ '^+++ '
            echo 'Сохраняем предыдущий фрейм, если он существует'
            if !empty(l:frame)
                call add(g:frames, l:frame)
                let l:frame = []
            endif
            let l:current_file = substitute(l:line, '^+++ ', '', '')
        elseif l:line =~ '^@@ '
            echo 'Сохраняем текущий фрейм'
            if !empty(l:frame)
                call add(g:frames, l:frame)
                let l:frame = []
            endif
            let l:frame = [l:line]
        elseif !empty(l:frame)
            call add(l:frame, l:line)
        endif
    endfor

    echo 'Добавляем последний фрейм'
    if !empty(l:frame)
        call add(g:frames, l:frame)
    endif
endfunction

function! DisplayFrames()
    echo 'Функция для отображения фреймов'
    echo 'Очищаем текущее окно'
    normal! gvgv
    for l:frame in g:frames
        call append(line('$'), l:frame)
        call append(line('$'), '')
    endfor
endfunction

function! ShiftFrame(direction)
    echo 'Функция для смещения фреймов'
    if a:direction == 'up'
        let g:current_frame -= 1
    elseif a:direction == 'down'
        let g:current_frame += 1
    endif
    echo 'Обновляем отображение'
    call DisplayFrames()
endfunction

" Команды для загрузки и отображения фреймов
command! LoadFrames call LoadFrames()
command! DisplayFrames call DisplayFrames()

" Горячие клавиши
nnoremap <S-Up> :call ShiftFrame('up')<CR>
nnoremap <S-Down> :call ShiftFrame('down')<CR>

" Автоматически загружаем фреймы при открытии файла
autocmd BufReadPost * call LoadFrames()
