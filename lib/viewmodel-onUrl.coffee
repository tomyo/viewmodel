isArray = (obj) -> obj instanceof Array or Array.isArray(obj)

((history) ->
  pushState = history.pushState
  replaceState = history.replaceState

  if (pushState)
    history.pushState = (state, title, url) ->
      if typeof history.onstatechange is 'function'
        history.onstatechange state, title, url
      pushState.apply history, arguments
    history.replaceState = (state, title, url) ->
      if typeof history.onstatechange is 'function'
        history.onstatechange state, title, url
      replaceState.apply history, arguments
  else
    history.pushState = ->
    history.replaceState = ->
  return
) window.history

parseUri = (str) ->
  o = parseUri.options
  m = o.parser[(if o.strictMode then "strict" else "loose")].exec(str)
  uri = {}
  i = 14
  uri[o.key[i]] = m[i] or ""  while i--
  uri[o.q.name] = {}
  uri[o.key[12]].replace o.q.parser, ($0, $1, $2) ->
    uri[o.q.name][$1] = $2  if $1
    return

  uri

parseUri.options =
  strictMode: false
  key: [
    "source"
    "protocol"
    "authority"
    "userInfo"
    "user"
    "password"
    "host"
    "port"
    "relative"
    "path"
    "directory"
    "file"
    "query"
    "anchor"
  ]
  q:
    name: "queryKey"
    parser: /(?:^|&)([^&=]*)=?([^&]*)/g

  parser:
    strict: /^(?:([^:\/?#]+):)?(?:\/\/((?:(([^:@]*)(?::([^:@]*))?)?@)?([^:\/?#]*)(?::(\d*))?))?((((?:[^?#\/]*\/)*)([^?#]*))(?:\?([^#]*))?(?:#(.*))?)/
    loose: /^(?:(?![^:@]+:[^:@\/]*@)([^:\/?#.]+):)?(?:\/\/)?((?:(([^:@]*)(?::([^:@]*))?)?@)?([^:\/?#]*)(?::(\d*))?)(((\/(?:[^?#](?![^?#\/]*\.[^?#\/.]+(?:[?#]|$)))*\/?)?([^?#\/]*))(?:\?([^#]*))?(?:#(.*))?)/

getUrl = (target = document.URL) -> parseUri(target)

updateQueryString = (key, value, url) ->
  if !url
    url = window.location.href
  re = new RegExp('([?&])' + key + '=.*?(&|#|$)(.*)', 'gi')
  hash = undefined
  if re.test(url)
    if typeof value != 'undefined' and value != null
      url.replace re, '$1' + key + '=' + value + '$2$3'
    else
      hash = url.split('#')
      url = hash[0].replace(re, '$1$3').replace(/(&|\?)$/, '')
      if typeof hash[1] != 'undefined' and hash[1] != null
        url += '#' + hash[1]
      url
  else
    if typeof value != 'undefined' and value != null
      separator = if url.indexOf('?') != -1 then '&' else '?'
      hash = url.split('#')
      url = hash[0] + separator + key + '=' + value
      if typeof hash[1] != 'undefined' and hash[1] != null
        url += '#' + hash[1]
      url
    else
      url

getSavedData = (url = document.URL) ->
  urlData = getUrl(url).queryKey.data
  return if not urlData
  dataString = LZString.decompressFromEncodedURIComponent(urlData)
  obj = {}
  try
    obj = JSON.parse(dataString)
  finally
    return obj

ViewModel.saveUrl = (viewmodel) ->
  viewmodel.templateInstance.autorun (c) ->
    ViewModel.check '@saveUrl', viewmodel
    vmHash = viewmodel.vmHash()
    url = window.location.href
    savedData = getSavedData() or {}
    fields = if isArray(viewmodel.onUrl()) then viewmodel.onUrl() else [viewmodel.onUrl()]
    data = viewmodel.data(fields)
    savedData[vmHash] = data
    dataString = JSON.stringify savedData
    dataCompressed = LZString.compressToEncodedURIComponent dataString
    url = updateQueryString "data", dataCompressed, url
    window.history.pushState(null, null, url) if not c.firstRun and document.URL isnt url

ViewModel.loadUrl = (viewmodel) ->
  updateFromUrl = (state, title, url = document.URL) ->
    data = getSavedData(url)
    return if not data
    vmHash = viewmodel.vmHash()
    savedData = data[vmHash]
    if savedData
      viewmodel.load savedData
  window.onpopstate = window.history.onstatechange = updateFromUrl
  updateFromUrl()