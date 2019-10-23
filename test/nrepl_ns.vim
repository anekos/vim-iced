let s:suite  = themis#suite('iced.nrepl.ns')
let s:assert = themis#helper('assert')
let s:ch = themis#helper('iced_channel')
let s:buf = themis#helper('iced_buffer')

function! s:suite.name_by_var_test() abort
  call s:ch.mock({
        \ 'status_value': 'open',
        \ 'relay': {_ -> {'status': ['done'], 'value': '#namespace[foo.bar1]'}}})

  call s:assert.equals(iced#nrepl#ns#name_by_var(), 'foo.bar1')
endfunction

function! s:suite.name_by_buf_test() abort
  call s:buf.start_dummy(['(ns foo.bar2)', '|'])
  call s:assert.equals(iced#nrepl#ns#name_by_buf(), 'foo.bar2')
  call s:buf.stop_dummy()

  call s:buf.start_dummy(['', '(ns', '  foo.bar3', '  (:require [clojure.string :as str|])'])
  call s:assert.equals(iced#nrepl#ns#name_by_buf(), 'foo.bar3')
  call s:buf.stop_dummy()
endfunction

function! s:suite.name_by_buf_with_tag_test() abort
  call s:buf.start_dummy(['(ns ^:tag foo.bar4)', '|'])
  call s:assert.equals(iced#nrepl#ns#name_by_buf(), 'foo.bar4')
  call s:buf.stop_dummy()

  call s:buf.start_dummy(['(ns ^:tag', '  foo.bar5)', '|'])
  call s:assert.equals(iced#nrepl#ns#name_by_buf(), 'foo.bar5')
  call s:buf.stop_dummy()
endfunction

function! s:suite.name_by_buf_with_meta_test() abort
  call s:buf.start_dummy([
        \ ';; comment',
        \ '(ns ^{:me 1',
        \ '      :ta 2}',
        \ '  foo.bar6)',
        \ '|',
        \ ])
  call s:assert.equals(iced#nrepl#ns#name_by_buf(), 'foo.bar6')
  call s:buf.stop_dummy()
endfunction

function! s:suite.name_by_buf_without_ns_form_test() abort
  call s:buf.start_dummy(['(+ 1 2 3)', '|'])
  call s:assert.equals(iced#nrepl#ns#name_by_buf(), '')
  call s:buf.stop_dummy()
endfunction

function! s:suite.name_test() abort
  call s:ch.mock({
        \ 'status_value': 'open',
        \ 'relay': {_ -> {'status': ['done'], 'value': '#namespace[foo.bar7]'}}})

  call s:buf.start_dummy(['(ns foo.bar8)', '|'])
  call s:assert.equals(iced#nrepl#ns#name(), 'foo.bar8')
  call s:buf.stop_dummy()

  call s:buf.start_dummy(['|'])
  call s:assert.equals(iced#nrepl#ns#name(), 'foo.bar7')
  call s:buf.stop_dummy()
endfunction
