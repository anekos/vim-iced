let s:suite = themis#suite('iced.nrepl.refactor')
let s:assert = themis#helper('assert')
let s:buf = themis#helper('iced_buffer')
let s:ch = themis#helper('iced_channel')
let s:io = themis#helper('iced_io')

" extract_function {{{
function! s:extract_function_relay(locals, msg) abort
  if a:msg['op'] ==# 'find-used-locals'
    return {'status': ['done'], 'used-locals': a:locals}
  endif
  return {'status': ['done']}
endfunction

function! s:suite.extract_function_test() abort
  call s:ch.mock({'status_value': 'open', 'relay': function('s:extract_function_relay', [['a', 'b']])})
  call s:io.mock({'input': 'extracted'})
  call s:buf.start_dummy(['(foo (bar a b|))'])

  call iced#nrepl#refactor#extract_function()

  call s:assert.equals(s:buf.get_lines(), [
        \ '(defn- extracted [a b]',
        \ '  (bar a b))',
        \ '',
        \ '(foo (extracted a b))',
        \ ])

  call s:buf.stop_dummy()
endfunction

function! s:suite.extract_function_with_no_args_test() abort
  call s:ch.mock({'status_value': 'open', 'relay': function('s:extract_function_relay', [[]])})
  call s:io.mock({'input': 'extracted'})
  call s:buf.start_dummy(['(foo (bar|))'])

  call iced#nrepl#refactor#extract_function()

  call s:assert.equals(s:buf.get_lines(), [
        \ '(defn- extracted []',
        \ '  (bar))',
        \ '',
        \ '(foo (extracted))',
        \ ])

  call s:buf.stop_dummy()
endfunction
" }}}

" clean_ns {{{
function! s:clean_ns_relay(msg) abort
  if a:msg['op'] ==# 'clean-ns'
    return {'status': ['done'], 'ns': '(ns cleaned)'}
  endif
  return {'status': ['done']}
endfunction

function! s:suite.clean_ns_test() abort
  call s:ch.mock({'status_value': 'open', 'relay': funcref('s:clean_ns_relay')})
  call s:buf.start_dummy([
        \ '(ns foo.bar)',
        \ '(baz hello|)',
        \ ])

  call iced#nrepl#refactor#clean_ns()
  call s:assert.true(s:buf.test_curpos([
        \ '(ns cleaned)',
        \ '(baz hello|)',
        \ ]))

  call s:buf.stop_dummy()
endfunction
" }}}

" thread_first/last {{{
function! s:thread_relay(msg) abort
  if a:msg['op'] ==# 'iced-refactor-thread-first'
    return {'status': ['done'], 'code': '(thread first refactored)'}
  elseif a:msg['op'] ==# 'iced-refactor-thread-last'
    return {'status': ['done'], 'code': '(thread last refactored)'}
  endif
  return {'status': ['done']}
endfunction

function! s:suite.thread_first_test() abort
  call s:ch.mock({'status_value': 'open', 'relay': funcref('s:thread_relay')})
  call s:buf.start_dummy(['(foo (bar (baz 1) 2)|)'])
  call iced#nrepl#refactor#thread_first()
  call s:assert.equals(s:buf.get_texts(), '(thread first refactored)')
  call s:buf.stop_dummy()
endfunction

function! s:suite.thread_last_test() abort
  call s:ch.mock({'status_value': 'open', 'relay': funcref('s:thread_relay')})
  call s:buf.start_dummy(['(foo (bar (baz 1) 2)|)'])
  call iced#nrepl#refactor#thread_last()
  call s:assert.equals(s:buf.get_texts(), '(thread last refactored)')
  call s:buf.stop_dummy()
endfunction
" }}}

" add_arity {{{
function! s:add_arity_relay(msg) abort
  if a:msg['op'] ==# 'iced-format-code-with-indents'
    let code = substitute(a:msg['code'], '\s*\r\?\n\s\+', '\n', 'g')
    return {'status': ['done'], 'formatted': code}
  endif
  return {'status': ['done']}
endfunction

function! s:suite.add_arity_defn_test() abort
  call s:ch.mock({'status_value': 'open', 'relay': funcref('s:add_arity_relay')})
  " Single arity
  call s:buf.start_dummy([
        \ '(ns foo.core)',
        \ '(defn foo [bar]',
        \ '  baz|)'])
  call iced#nrepl#refactor#add_arity()
  call s:assert.true(s:buf.test_curpos([
        \ '(ns foo.core)',
        \ '(defn foo',
        \ '      ([|])',
        \ '      ([bar]',
        \ '      baz))']))
  call s:buf.stop_dummy()

  " Multiple arity
  call s:buf.start_dummy([
        \ '(ns foo.core)',
        \ '(defn foo',
        \ '  ([bar]',
        \ '   baz|))'])
  call iced#nrepl#refactor#add_arity()
  call s:assert.true(s:buf.test_curpos([
        \ '(ns foo.core)',
        \ '(defn foo',
        \ '       ([|])',
        \ '       ([bar]',
        \ '       baz))']))
  call s:buf.stop_dummy()
endfunction

function! s:suite.add_arity_with_doc_string_test() abort
  call s:ch.mock({'status_value': 'open', 'relay': funcref('s:add_arity_relay')})
  " Single arity
  call s:buf.start_dummy([
        \ '(ns foo.core)',
        \ '(defn foo',
        \ '  "doc-string"',
        \ '  [bar]',
        \ '  baz|)'])
  call iced#nrepl#refactor#add_arity()
  call s:assert.true(s:buf.test_curpos([
        \ '(ns foo.core)',
        \ '(defn foo',
        \ '      "doc-string"',
        \ '      ([|])',
        \ '      ([bar]',
        \ '      baz))']))
  call s:buf.stop_dummy()

  " Multiple arity
  call s:buf.start_dummy([
        \ '(ns foo.core)',
        \ '(defn foo',
        \ '  "doc-string"',
        \ '  ([bar]',
        \ '   baz|))'])
  call iced#nrepl#refactor#add_arity()
  call s:assert.true(s:buf.test_curpos([
        \ '(ns foo.core)',
        \ '(defn foo',
        \ '       "doc-string"',
        \ '       ([|])',
        \ '       ([bar]',
        \ '       baz))']))
  call s:buf.stop_dummy()
endfunction

function! s:suite.add_arity_with_meta_test() abort
  call s:ch.mock({'status_value': 'open', 'relay': funcref('s:add_arity_relay')})
  " Single arity
  call s:buf.start_dummy([
        \ '(ns foo.core)',
        \ '(defn ^{:bar "baz"}',
        \ '  foo',
        \ '  "doc-string"',
        \ '  [bar]',
        \ '  baz|)'])
  call iced#nrepl#refactor#add_arity()
  call s:assert.true(s:buf.test_curpos([
        \ '(ns foo.core)',
        \ '(defn ^{:bar "baz"}',
        \ '      foo',
        \ '      "doc-string"',
        \ '      ([|])',
        \ '      ([bar]',
        \ '      baz))']))
  call s:buf.stop_dummy()

  " Multiple arity
  call s:buf.start_dummy([
        \ '(ns foo.core)',
        \ '(defn ^{:bar "baz"}',
        \ '  foo',
        \ '  "doc-string"',
        \ '  ([bar]',
        \ '   baz|))'])
  call iced#nrepl#refactor#add_arity()
  call s:assert.true(s:buf.test_curpos([
        \ '(ns foo.core)',
        \ '(defn ^{:bar "baz"}',
        \ '       foo',
        \ '       "doc-string"',
        \ '       ([|])',
        \ '       ([bar]',
        \ '       baz))']))
  call s:buf.stop_dummy()
endfunction

function! s:suite.add_arity_fn_test() abort
  call s:ch.mock({'status_value': 'open', 'relay': funcref('s:add_arity_relay')})
  " Single arity
  call s:buf.start_dummy([
        \ '(ns foo.core)',
        \ '(def foo',
        \ '  (fn [bar] baz|))'])
  call iced#nrepl#refactor#add_arity()
  call s:assert.true(s:buf.test_curpos([
        \ '(ns foo.core)',
        \ '(def foo',
        \ '  (fn',
        \ '             ([|])',
        \ '             ([bar] baz)))']))
  call s:buf.stop_dummy()

  " Multiple arity
  call s:buf.start_dummy([
        \ '(ns foo.core)',
        \ '(def foo',
        \ '  (fn',
        \ '    ([bar] baz|)))',
        \ ])
  call iced#nrepl#refactor#add_arity()
  call s:assert.true(s:buf.test_curpos([
        \ '(ns foo.core)',
        \ '(def foo',
        \ '  (fn',
        \ '               ([|])',
        \ '               ([bar] baz)))']))
  call s:buf.stop_dummy()
endfunction

function! s:suite.add_arity_defmacro_test() abort
  call s:ch.mock({'status_value': 'open', 'relay': funcref('s:add_arity_relay')})
  " Single arity
  call s:buf.start_dummy([
        \ '(ns foo.core)',
        \ '(defmacro foo [bar]',
        \ '  `(baz|))'])
  call iced#nrepl#refactor#add_arity()
  call s:assert.true(s:buf.test_curpos([
        \ '(ns foo.core)',
        \ '(defmacro foo',
        \ '         ([|])',
        \ '         ([bar]',
        \ '         `(baz)))']))
  call s:buf.stop_dummy()

  " Multiple arity
  call s:buf.start_dummy([
        \ '(ns foo.core)',
        \ '(defmacro foo',
        \ '  ([bar]',
        \ '   `(baz|)))'])
  call iced#nrepl#refactor#add_arity()
  call s:assert.true(s:buf.test_curpos([
        \ '(ns foo.core)',
        \ '(defmacro foo',
        \ '          ([|])',
        \ '          ([bar]',
        \ '          `(baz)))']))
  call s:buf.stop_dummy()
endfunction

function! s:suite.add_arity_defmethod_test() abort
  call s:ch.mock({'status_value': 'open', 'relay': funcref('s:add_arity_relay')})
  " Single arity
  call s:buf.start_dummy([
        \ '(ns foo.core)',
        \ '(defmethod foo :bar',
        \ '  [baz]',
        \ '  hello|)'])
  call iced#nrepl#refactor#add_arity()
  call s:assert.true(s:buf.test_curpos([
        \ '(ns foo.core)',
        \ '(defmethod foo :bar',
        \ '        ([|])',
        \ '        ([baz]',
        \ '        hello))']))
  call s:buf.stop_dummy()

  " Multiple arity
  call s:buf.start_dummy([
        \ '(ns foo.core)',
        \ '(defmethod foo :bar',
        \ '  ([baz]',
        \ '   hello|))'])
  call iced#nrepl#refactor#add_arity()
  call s:assert.true(s:buf.test_curpos([
        \ '(ns foo.core)',
        \ '(defmethod foo :bar',
        \ '         ([|])',
        \ '         ([baz]',
        \ '         hello))']))
  call s:buf.stop_dummy()
endfunction
" }}}

" vim:fdm=marker:fdl=0
