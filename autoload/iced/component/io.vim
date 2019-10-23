let s:save_cpo = &cpoptions
set cpoptions&vim

let s:V = vital#iced#new()
let s:M = s:V.import('Vim.Message')
let s:io = {}

function! s:io.input(...) abort
  return call(function('input'), a:000)
endfunction

function! s:io.echomsg(hl, text) abort
  call s:M.echomsg(a:hl, a:text)
endfunction

function! iced#di#io#build(container) abort
  return s:io
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
