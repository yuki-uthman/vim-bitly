" bitly - shortening url with bitly within vim
"
" Author: Yuki Yoshimine <yuki.uthman@gmail.com>
" Source: https://github.com/yuki-uthman/vim-bitly


if exists("g:loaded_bitly")
  finish
endif
let g:loaded_bitly = 1

let s:save_cpo = &cpo
set cpo&vim

vnoremap <silent><Plug>(bitly-convert) :call bitly#convert()<CR>

if !exists("g:bitly_no_mappings") || ! g:bitly_no_mappings
  vmap <leader>b <Plug>(bitly-convert)
endif


let &cpo = s:save_cpo
unlet s:save_cpo
