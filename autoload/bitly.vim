
let s:api_shorten          = 'https://api-ssl.bitly.com/v4/shorten'

function! s:get_visual_selection() "{{{
  let [l:lnum1, l:col1] = getpos("'<")[1:2]
  let [l:lnum2, l:col2] = getpos("'>")[1:2]
  if &selection !=# 'inclusive'
    let l:col2 -= 1
  endif
  let l:lines = getline(l:lnum1, l:lnum2)
  if !empty(l:lines)
    let l:lines[-1] = l:lines[-1][: l:col2 - 1]
    let l:lines[0] = l:lines[0][l:col1 - 1 : ]
  endif
  return join(l:lines, "\n")
endfunction "}}}

function! s:on_stdout(id, data, event) abort "{{{

  if a:data == ['']
    return
  endif


  let [lnum1, col1] = getpos("'<")[1:2]
  let [lnum2, col2] = getpos("'>")[1:2]


  let json = json_decode(a:data[0])

  if has_key(json, 'id')
    let bufnr = 0
    let start_row = lnum1 - 1
    let end_row = lnum2 - 1

    let start_col = col1 - 1
    let end_col = col2 - 1

    call nvim_buf_set_text(bufnr,start_row,start_col,end_row,end_col, [json.id])
    redraw

  elseif has_key(json, 'message') && has_key(json, 'description')
    call maktaba#error#Warn('%s (%s)', json.description, json.message)

  elseif has_key(json, 'message')
    call maktaba#error#Warn('%s', json.message)

  else
    call maktaba#error#Warn('Unknown error has occured')

  endif


endfunction "}}}

function! s:sync_job(cmd) abort
    let result = system(a:cmd)

    let result = matchstr(result, '\V{\.\*')

    if result ==# ''
      call maktaba#error#Warn('Could not connect to host: %s', s:api_shorten)
      return
    endif

    let json = json_decode(result)

    if has_key(json, 'message') && has_key(json, 'description')
      call maktaba#error#Warn('%s (%s)', json.description, json.message)
      return

    elseif has_key(json, 'message')
      call maktaba#error#Warn('%s', json.message)
      return

    endif

    exec "normal! gvd"
    exec "normal! i" . json.id

endfunction

function! s:get_user_config() abort
  let to_return = {}
  let token = get(g:, 'bitly_access_token', '')

  if empty(token)
    throw maktaba#error#NotAuthorized('OAuth access token is required.')
  endif

  let to_return.token = token

  return to_return
endfunction

function! s:get_cmd(url, token) abort
    let authorization = yuki#string#surround('Authorization: Bearer ' . a:token, "'")
    let content_type = yuki#string#surround('Content-Type: application/json', "'")
    let request = 'POST'

    let json = { 'long_url': a:url, 'domain': 'bit.ly'}
    let json_string = yuki#string#surround(json_encode(json), "'")

    let cmd = "curl"
    let cmd = join([
          \'curl', 
          \'--silent', 
          \'-H', authorization, 
          \'-H', content_type, 
          \'-X', request,
          \'-d', json_string,
          \s:api_shorten])
    return cmd
endfunction

function! bitly#convert() abort "{{{

  let url = s:get_visual_selection()

  try
    let user_config = s:get_user_config()

    let cmd = s:get_cmd(url, user_config.token)

    if has('nvim')
      call jobstart(cmd, 
            \{
            \'on_stdout': function('s:on_stdout'),
            \}
            \)
    else
      call s:sync_job(cmd)

    endif



  catch /ERROR(NotAuthorized)/
    let warning = maktaba#error#Split(v:exception)[0]
    call maktaba#error#Warn(warning)

  finally
    normal! `<

  endtry

endfunction "}}}
