if exists('g:loaded_codeframe') | finish | endif
let g:loaded_codeframe = 1

command! -nargs=0 CodeFrameEnable call codeframe#Enable()

" Автоматическая активация для .cf файлов
autocmd BufEnter *.cf call codeframe#Enable()