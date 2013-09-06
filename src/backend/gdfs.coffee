# Wrapper around the calls to the Google Drive API
class GoogleDrive
  # Credit: http://stackoverflow.com/questions/9267899/arraybuffer-to-base64-encoded-string
  # Possible faster version: https://gist.github.com/jonleighton/958841
  @_arrayBufferToBase64: (buffer) ->
    binary = ''
    bytes = new Uint8Array(buffer)
    len = bytes.byteLength
    i = 0
    while ++i < len
      binary += String.fromCharCode(bytes[i])
    return window.btoa(binary)

  @_makeBody: (metadata, contentType, data) ->
    boundary = '-------314159265358979323846'
    delimiter = "\r\n--" + boundary + "\r\n"
    close_delim = "\r\n--" + boundary + "--"

    return delimiter +
      'Content-Type: application/json\r\n\r\n' +
      JSON.stringify(metadata) +
      delimiter +
      "Content-Type: #{contentType}\r\n" +
      'Content-Transfer-Encoding: base64\r\n\r\n' +
      data + close_delim

  @writeFile: (buffer, cb) ->
    # TODO: how do we get the file type?
    contentType = fileData.type or 'application/octet-stream'

    metadata = {
      # And the name?
      title: fileData.name
      mimeType: contentType
    }

    body = @_makeBody(metadata, contentType, @_arrayBufferToBase64(buffer))

    request = gapi.client.request({
      path: '/upload/drive/v2/files'
      method: 'POST'
      params: {
        uploadType: 'multipart'
      }
      headers: {
        'Content-Type': "multipart/mixed; boundary=\"#{boundary}\""
      }
      body: body
    })

    unless callback
      callback = (file) -> console.log(file)

    request.execute(callback)

class BrowserFS.File.GDriveFile extends BrowserFS.File.PreloadFile
  sync: (cb) ->
    GoogleDrive.writeFile(@_buffer.buff.buffer, cb)

  close: (cb) -> @sync(cb)

# A BrowserFS backend that stores files in Google Drive
class BrowserFS.FileSystem.GDrive extends BrowserFS.FileSystem
  constructor: (cb) ->
    self = this
    details = {
      client_id: '555024705616.apps.googleusercontent.com'
      scope: 'https://www.googleapis.com/auth/drive'
      immediate: true
    }

    doAuth = (result) ->
      if result and not result.error
        console.debug('Authenticated successfully')
        console.debug(result)

        gapi.client.load('drive', 'v2', ->
          cb(self) if cb
        )
      else
        details.immediate = false
        gapi.auth.authorize(details, doAuth)

    gapi.auth.authorize(details, doAuth)

  getName: -> 'Google Drive'

  @isAvailable: -> true

  isReadOnly: -> false

  supportsSymlinks: -> false

  supportsProps: -> false

  supportsSynch: -> false

  empty: (cb) ->

  rename: (oldPath, newPath, cb) ->

  stat: (path, isLstat, cb) ->

  open: (path, flags, mode, cb) ->

  unlink: (path, cb) ->

  rmdir: (path, cb) ->

  mkdir: (path, mode, cb) ->

  readdir: (path, cb) ->
