
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

function! bitly#convert() abort "{{{

  try
    let url = s:get_visual_selection()
    let bitly_link = bitly#shorten(url)
    exec "normal! gvd"
    exec "normal! i" . bitly_link.id


  catch /ERROR(\(Bitly\|BadConnection\|NotAuthorized\)):/    
    let to_display = maktaba#error#Split(v:exception)[1]
    call maktaba#error#Warn(to_display)

  catch /E474/
    call maktaba#error#Warn(v:exception)

  finally
    normal! `<
  endtry


endfunction "}}}

function! bitly#shorten(url) abort "{{{

  let token = get(g:, 'bitly_access_token', '')

  if empty(token)
    throw maktaba#error#NotAuthorized('OAuth access token missing')
  endif

  let authorization = yuki#string#surround('Authorization: Bearer ' . token, "'")
  let content_type = yuki#string#surround('Content-Type: application/json', "'")
  let request = 'POST'

  let json = { 'long_url': a:url, 'domain': 'bit.ly'}
  let json_string = yuki#string#surround(json_encode(json), "'")

  let cmd = "curl"
  let cmd = join([
        \'curl', 
        \'-H', authorization, 
        \'-H', content_type, 
        \'-X', request,
        \'-d', json_string,
        \s:api_shorten])
"  call Decho(cmd)

  let result = system(cmd)
"  call Decho(result)

  let result = matchstr(result, '\V{\.\*')

"  call Decho(result)

  if result ==# ''
    throw maktaba#error#Message('BadConnection', 'Could not connect to host: %s', s:api_shorten)
  endif

  let json = json_decode(result)

  if has_key(json, 'message') && has_key(json, 'description')
    throw maktaba#error#Message('Bitly', '%s (%s)', json.description, json.message)

  elseif has_key(json, 'message')
    throw maktaba#error#Message('Bitly', '%s', json.message)

  endif

  return json
endfunction "}}}
