if exists('g:loaded_codeframe') | finish | endif
let g:loaded_codeframe = 1

command! -nargs=0 CodeFrameEnable call CodeFrame#Enable()