let s:save_cpo = &cpoptions
set cpoptions&vim

function! iced#status() abort
  if !iced#nrepl#is_connected()
    return 'not connected'
  endif

  if iced#nrepl#is_evaluating()
    return 'evaluating'
  else
    let k = iced#nrepl#current_session_key()
    if iced#nrepl#cljs_session() ==# ''
      return toupper(k)
    else
      return (k ==# 'clj') ? 'CLJ(cljs)' : 'CLJS(clj)'
    endif
  endif
endfunction

function! s:json_resp(resp) abort
  try
    let resp = copy(a:resp)
    if has_key(a:resp, 'value')
      let value = a:resp['value']
      let value = (stridx(value, '"') == 0) ? json_decode(value) : value
      let resp['value'] = json_decode(value)
    endif
    return resp
  catch
    return {}
  endtry
endfunction

function! s:callback(callback, resp) abort
  return a:callback(s:json_resp(a:resp))
endfunction

function! iced#eval_and_read(code, ...) abort
  let msg = {
      \ 'id': iced#nrepl#id(),
      \ 'op': 'eval',
      \ 'code': printf('(do (require ''iced.alias.json) (iced.alias.json/write-str %s))', a:code),
      \ 'session': iced#nrepl#clj_session(),
      \ }
  let Callback = get(a:, 1, '')
  if type(Callback) == v:t_func
    " HACK: let msg['callback'] = {resp -> Callback(s:json_resp(resp))}
    "       This code will fail when calculating coverage by covimerage.
    let msg['callback'] = function('s:callback', [Callback])

    call iced#nrepl#send(msg)
    return v:true
  else
    return s:json_resp(iced#nrepl#sync#send(msg))
  endif
endfunction

function! iced#selector(config) abort
  call iced#system#get('selector').select(a:config)
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
