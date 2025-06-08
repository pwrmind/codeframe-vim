" Файл: ~/.vim/plugined/multi_frame.vim

" Определяем глобальные переменные
let g:frames = []
let g:current_frame = 0

" Функция для загрузки файлов и создания фреймов
function! LoadFrames()
    let l:lines = getline(1, '$')
    let l:current_file = ''
    let l:frame = []

    for l:line in l:lines
        if l:line =~ '^+++ '
            " Сохраняем предыдущий фрейм, если он существует
            if !empty(l:frame)
                call add(g:frames, l:frame)
                let l:frame = []
            endif
            let l:current_file = substitute(l:line, '^+++ ', '', '')
        elseif l:line =~ '^@@ '
            " Сохраняем текущий фрейм
            if !empty(l:frame)
                call add(g:frames, l:frame)
                let l:frame = []
            endif
            let l:frame = [l:line]
        elseif !empty(l:frame)
            call add(l:frame, l:line)
        endif
    endfor

    " Добавляем последний фрейм
    if !empty(l:frame)
        call add(g:frames, l:frame)
    endif
endfunction

" Функция для отображения фреймов
function! DisplayFrames()
    " Очищаем текущее окно
    normal! gvgv
    for l:frame in g:frames
        call append(line('$'), l:frame)
        call append(line('$'), '')
    endfor
endfunction

" Функция для смещения фреймов
function! ShiftFrame(direction)
    if a:direction == 'up'
        let g:current_frame -= 1
    elseif a:direction == 'down'
        let g:current_frame += 1
    endif
    " Обновляем отображение
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
