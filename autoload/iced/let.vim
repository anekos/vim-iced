let s:save_cpo = &cpo
set cpo&vim

function! iced#let#jump_to_let() abort
  let view = winsaveview()
  let reg_save = @@

  try
    if iced#paredit#move_to_current_element_head() == 0
      call winrestview(view)
      return 0
    endif

    while v:true
      let head = strpart(getline('.'), col('.'), 4)
      if head ==# 'let' || head ==# 'let '
        call search('\[')
        break
      endif

      if iced#paredit#move_to_parent_element() == 0
        call winrestview(view)
        return 0
      endif
    endwhile

    return col('.')
  finally
    let @@ = reg_save
  endtry
endfunction

function! iced#let#move_to_let(...) abort
  let view = winsaveview()
  let reg_save = @t

  try
    let form = iced#paredit#get_outer_list_raw()
    if empty(form) | return iced#message#error('not_found') | endif

    let indent = col('.')-1
    let form = iced#util#del_indent(indent, form)
    let name = get(a:, 1, '')
    if empty(name)
      let name = trim(input('Name: '))
    endif
    if empty(name)
      return iced#message#echom('canceled')
    endif

    if iced#let#jump_to_let() == 0
      " 6 means `len('(let [')`
      let form = iced#util#add_indent(len(name)+1+6, form)
      let @t = iced#util#add_indent(
            \ indent, printf("(let [%s %s]\n  %s)", name, form, name))
      silent normal! gv"tp
    else
      let pos = getcurpos()
      let @t = name
      silent normal! gv"tp
      call setpos('.', pos)

      silent normal! vi["ty
      let bindings = @t
      let indent = col('.')-1

      let form = iced#util#add_indent(len(name)+1, form)
      let @t = iced#util#add_indent(
            \ indent, printf("%s\n%s %s", bindings, name, form))
      silent normal! gv"tp
    endif

    let view['lnum'] = view['lnum'] + len(split(form, '\r\?\n'))
  finally
    let @t = reg_save
    call winrestview(view)
  endtry
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
