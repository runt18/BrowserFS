# Wraps a callback with a setImmediate call.
# @param [Function] cb The callback to wrap.
# @param [Number] numArgs The number of arguments that the callback takes.
# @return [Function] The wrapped callback.
wrapCb = (cb, numArgs) ->
  if typeof cb != 'function'
    throw new BrowserFS.ApiError BrowserFS.ApiError.INVALID_PARAM, 'Callback must be a function.'
  if typeof window.__numWaiting is undefined
    window.__numWaiting = 0
  window.__numWaiting++
  # We could use `arguments`, but Function.call/apply is expensive. And we only
  # need to handle 1-3 arguments
  switch numArgs
    when 1
      return (arg1) -> setImmediate -> window.__numWaiting--; cb arg1
    when 2
      return (arg1, arg2) -> setImmediate -> window.__numWaiting--; cb arg1, arg2
    when 3
      return (arg1, arg2, arg3) -> setImmediate -> window.__numWaiting--; cb arg1, arg2, arg3
    else
      throw new Error 'Invalid invocation of wrapCb.'

# Checks if the fd is valid.
# @param [BrowserFS.File] fd A file descriptor (in BrowserFS, it's a File object)
# @return [Boolean, BrowserFS.ApiError] Returns `true` if the FD is OK,
#   otherwise returns an ApiError.
checkFd = (fd, async=true) ->
  unless fd instanceof BrowserFS.File
    if async
      return new BrowserFS.ApiError BrowserFS.ApiError.INVALID_PARAM, 'Invalid file descriptor.'
    else
      throw new BrowserFS.ApiError BrowserFS.ApiError.INVALID_PARAM, 'Invalid file descriptor.'
  return true

# The default callback is a NOP.
nopCb = ->

# The node frontend to all filesystems.
# This layer handles:
#
# * Sanity checking inputs.
# * Normalizing paths.
# * Resetting stack depth for asynchronous operations which may not go through
#   the browser by wrapping all input callbacks using `setImmediate`.
# * Performing the requested operation through the filesystem or the file
#   descriptor, as appropriate.
# * Handling optional arguments and setting default arguments.
# @see http://nodejs.org/api/fs.html
class BrowserFS.node.fs
  @_initialize: (rootFS) =>
    unless rootFS.constructor.isAvailable()
      throw new BrowserFS.ApiError BrowserFS.ApiError.INVALID_PARAM, 'Tried to instantiate BrowserFS with an unavailable file system.'
    @root = rootFS

  # converts Date or number to a fractional UNIX timestamp
  # Grabbed from NodeJS sources (lib/fs.js)
  @_toUnixTimestamp: (time) =>
    if typeof time is 'number'
      return time
    if time instanceof Date
      return time.getTime()/1000
    throw new Error "Cannot parse time: #{time}"

  # **NONSTANDARD**: Grab the FileSystem instance that backs this API.
  # @return [BrowserFS.FileSystem | null] Returns null if the file system has
  #   not been initialized.
  @getRootFS: => if @root then @root else null

  @_canonicalizePath: (p) =>
    # Node doesn't allow null characters in paths.
    if p.indexOf('\u0000') >= 0
      throw new BrowserFS.ApiError BrowserFS.ApiError.INVALID_PARAM, 'Path must be a string without null bytes.'
    # Empty string stays empty.
    return p if p is ''
    return BrowserFS.node.path.resolve p

  # FILE OR DIRECTORY METHODS

  # Asynchronous rename. No arguments other than a possible exception are given
  # to the completion callback.
  # @param [String] oldPath
  # @param [String] newPath
  # @param [Function(BrowserFS.ApiError)] callback
  @rename: (oldPath, newPath, callback=nopCb) =>
    try
      newCb = wrapCb callback, 1
      oldPath = @_canonicalizePath oldPath
      newPath = @_canonicalizePath newPath
      @root.rename oldPath, newPath, newCb
    catch e
      newCb e
  # Synchronous rename.
  # @param [String] oldPath
  # @param [String] newPath
  @renameSync: (oldPath, newPath) =>
    oldPath = @_canonicalizePath oldPath
    newPath = @_canonicalizePath newPath
    @root.renameSync oldPath, newPath
  # Test whether or not the given path exists by checking with the file system.
  # Then call the callback argument with either true or false.
  # @example Sample invocation
  #   fs.exists('/etc/passwd', function (exists) {
  #     util.debug(exists ? "it's there" : "no passwd!");
  #   });
  # @param [String] path
  # @param [Function(Boolean)] callback
  @exists: (path, callback=nopCb) =>
    try
      newCb = wrapCb callback, 1
      path = @_canonicalizePath path
      @root.exists path, newCb
    catch e
      # Doesn't return an error. If something bad happens, we assume it just
      # doesn't exist.
      newCb false
  # Test whether or not the given path exists by checking with the file system.
  # @param [String] path
  # @return [boolean]
  @existsSync: (path) =>
    try
      path = @_canonicalizePath path
      @root.existsSync path
    catch e
      # Doesn't return an error. If something bad happens, we assume it just
      # doesn't exist.
      false
  # Asynchronous `stat`.
  # @param [String] path
  # @param [Function(BrowserFS.ApiError, BrowserFS.node.fs.Stats)] callback
  @stat: (path, callback=nopCb) =>
    try
      newCb = wrapCb callback, 2
      path = @_canonicalizePath path
      @root.stat path, false, newCb
    catch e
      newCb e
  # Synchronous `stat`.
  # @param [String] path
  # @return [BrowserFS.node.fs.Stats]
  @statSync: (path) =>
    path = @_canonicalizePath path
    @root.statSync path, false
  # Asynchronous `lstat`.
  # `lstat()` is identical to `stat()`, except that if path is a symbolic link,
  # then the link itself is stat-ed, not the file that it refers to.
  # @param [String] path
  # @param [Function(BrowserFS.ApiError, BrowserFS.node.fs.Stats)] callback
  @lstat: (path, callback=nopCb) =>
    try
      newCb = wrapCb callback, 2
      path = @_canonicalizePath path
      @root.stat path, true, newCb
    catch e
      newCb e
  # Synchronous `lstat`.
  # `lstat()` is identical to `stat()`, except that if path is a symbolic link,
  # then the link itself is stat-ed, not the file that it refers to.
  # @param [String] path
  # @return [BrowserFS.node.fs.Stats]
  @lstatSync: (path) =>
    path = @_canonicalizePath path
    @root.statSync path, true

  # FILE-ONLY METHODS

  # Asynchronous `truncate`.
  # @param [String] path
  # @param [Number] len
  # @param [Function(BrowserFS.ApiError)] callback
  @truncate: (path, len, callback=nopCb) =>
    try
      if typeof len is 'function'
        callback = len
        len = 0
      newCb = wrapCb callback, 1
      path = @_canonicalizePath path
      @root.truncate path, len, newCb
    catch e
      newCb e
  # Synchronous `truncate`.
  # @param [String] path
  # @param [Number] len
  @truncateSync: (path, len=0) =>
    path = @_canonicalizePath path
    @root.truncateSync path, len,
  # Asynchronous `unlink`.
  # @param [String] path
  # @param [Function(BrowserFS.ApiError)] callback
  @unlink: (path, callback=nopCb) =>
    try
      newCb = wrapCb callback, 1
      path = @_canonicalizePath path
      @root.unlink path, newCb
    catch e
      newCb e
  # Synchronous `unlink`.
  # @param [String] path
  @unlinkSync: (path) =>
    path = @_canonicalizePath path
    @root.unlinkSync path
  # Asynchronous file open.
  # Exclusive mode ensures that path is newly created.
  #
  # `flags` can be:
  #
  # * `'r'` - Open file for reading. An exception occurs if the file does not exist.
  # * `'r+'` - Open file for reading and writing. An exception occurs if the file does not exist.
  # * `'rs'` - Open file for reading in synchronous mode. Instructs the filesystem to not cache writes.
  # * `'rs+'` - Open file for reading and writing, and opens the file in synchronous mode.
  # * `'w'` - Open file for writing. The file is created (if it does not exist) or truncated (if it exists).
  # * `'wx'` - Like 'w' but opens the file in exclusive mode.
  # * `'w+'` - Open file for reading and writing. The file is created (if it does not exist) or truncated (if it exists).
  # * `'wx+'` - Like 'w+' but opens the file in exclusive mode.
  # * `'a'` - Open file for appending. The file is created if it does not exist.
  # * `'ax'` - Like 'a' but opens the file in exclusive mode.
  # * `'a+'` - Open file for reading and appending. The file is created if it does not exist.
  # * `'ax+'` - Like 'a+' but opens the file in exclusive mode.
  #
  # @see http://www.manpagez.com/man/2/open/
  # @param [String] path
  # @param [String] flags
  # @param [Number?] mode defaults to `0644`
  # @param [Function(BrowserFS.ApiError, BrowserFS.File)] callback
  @open: (path, flags, mode, callback=nopCb) =>
    try
      if typeof mode is 'function'
        callback = mode
        mode = 0o644
      newCb = wrapCb callback, 2
      path = @_canonicalizePath path
      flags = BrowserFS.FileMode.getFileMode flags
      @root.open path, flags, mode, newCb
    catch e
      newCb e
  # Synchronous file open.
  # @see http://www.manpagez.com/man/2/open/
  # @param [String] path
  # @param [String] flags
  # @param [Number?] mode defaults to `0644`
  # @return [BrowserFS.File]
  @openSync: (path, flags, mode=0o644) =>
    path = @_canonicalizePath path
    flags = BrowserFS.FileMode.getFileMode flags
    @root.openSync path, flags, mode

  # Asynchronously reads the entire contents of a file.
  # @example Usage example
  #   fs.readFile('/etc/passwd', function (err, data) {
  #     if (err) throw err;
  #     console.log(data);
  #   });
  # @param [String] filename
  # @param [Object?] options
  # @option options [String] encoding The string encoding for the file contents. Defaults to `null`.
  # @option options [String] flag Defaults to `'r'`.
  # @param [Function(BrowserFS.ApiError, String | BrowserFS.node.Buffer)] callback If no encoding is specified, then the raw buffer is returned.
  @readFile: (filename, options, callback=nopCb) =>
    try
      if typeof options is 'function'
        callback = options
        options = {}
      else if typeof options is 'string'
        options = {encoding: options}
      # Only `filename` and `data` specified
      if options is undefined then options = {}
      if options.encoding is undefined then options.encoding = null
      unless options.flag? then options.flag = 'r'
      newCb = wrapCb callback, 2
      filename = @_canonicalizePath filename
      flags = BrowserFS.FileMode.getFileMode options.flag
      unless flags.isReadable()
        return newCb new BrowserFS.ApiError BrowserFS.ApiError.INVALID_PARAM, 'Flag passed to readFile must allow for reading.'
      @root.readFile filename, options.encoding, flags, newCb
    catch e
      newCb e
  # Synchronously reads the entire contents of a file.
  # @param [String] filename
  # @param [Object?] options
  # @option options [String] encoding The string encoding for the file contents. Defaults to `null`.
  # @option options [String] flag Defaults to `'r'`.
  # @return [String | BrowserFS.node.Buffer]
  @readFileSync: (filename, options={}) =>
    if typeof options is 'string'
      options = {encoding: options}
    # Only `filename` and `data` specified
    if options is undefined then options = {}
    if options.encoding is undefined then options.encoding = null
    unless options.flag? then options.flag = 'r'
    filename = @_canonicalizePath filename
    flags = BrowserFS.FileMode.getFileMode options.flag
    unless flags.isReadable()
      throw new BrowserFS.ApiError BrowserFS.ApiError.INVALID_PARAM, 'Flag passed to readFile must allow for reading.'
    @root.readFileSync filename, options.encoding, flags

  # Asynchronously writes data to a file, replacing the file if it already
  # exists.
  #
  # The encoding option is ignored if data is a buffer.
  #
  # @example Usage example
  #   fs.writeFile('message.txt', 'Hello Node', function (err) {
  #     if (err) throw err;
  #     console.log('It\'s saved!');
  #   });
  # @param [String] filename
  # @param [String | BrowserFS.node.Buffer] data
  # @param [Object?] options
  # @option options [String] encoding Defaults to `'utf8'`.
  # @option options [Number] mode Defaults to `0644`.
  # @option options [String] flag Defaults to `'w'`.
  # @param [Function(BrowserFS.ApiError)] callback
  @writeFile: (filename, data, options={}, callback=nopCb) =>
    try
      if typeof options is 'function'
        callback = options
        options = {}
      else if typeof options is 'string'
        options = {encoding: options}
      # Only `filename` and `data` specified
      if options is undefined then options = {}
      if options.encoding is undefined then options.encoding = 'utf8'
      unless options.flag? then options.flag = 'w'
      unless options.mode? then options.mode = 0o644
      newCb = wrapCb callback, 1
      filename = @_canonicalizePath filename
      flags = BrowserFS.FileMode.getFileMode options.flag
      unless flags.isWriteable()
        return newCb new BrowserFS.ApiError BrowserFS.ApiError.INVALID_PARAM, 'Flag passed to writeFile must allow for writing.'
      @root.writeFile filename, data, options.encoding, flags, options.mode, newCb
    catch e
      newCb e

  # Synchronously writes data to a file, replacing the file if it already
  # exists.
  #
  # The encoding option is ignored if data is a buffer.
  # @param [String] filename
  # @param [String | BrowserFS.node.Buffer] data
  # @param [Object?] options
  # @option options [String] encoding Defaults to `'utf8'`.
  # @option options [Number] mode Defaults to `0644`.
  # @option options [String] flag Defaults to `'w'`.
  @writeFileSync: (filename, data, options={}) =>
    if typeof options is 'string'
      options = {encoding: options}
    # Only `filename` and `data` specified
    if options is undefined then options = {}
    if options.encoding is undefined then options.encoding = 'utf8'
    unless options.flag? then options.flag = 'w'
    unless options.mode? then options.mode = 0o644
    filename = @_canonicalizePath filename
    flags = BrowserFS.FileMode.getFileMode options.flag
    unless flags.isWriteable()
      throw new BrowserFS.ApiError BrowserFS.ApiError.INVALID_PARAM, 'Flag passed to writeFile must allow for writing.'
    @root.writeFileSync filename, data, options.encoding, flags, options.mode

  # Asynchronously append data to a file, creating the file if it not yet
  # exists.
  #
  # @example Usage example
  #   fs.appendFile('message.txt', 'data to append', function (err) {
  #     if (err) throw err;
  #     console.log('The "data to append" was appended to file!');
  #   });
  # @param [String] filename
  # @param [String | BrowserFS.node.Buffer] data
  # @param [Object?] options
  # @option options [String] encoding Defaults to `'utf8'`.
  # @option options [Number] mode Defaults to `0644`.
  # @option options [String] flag Defaults to `'a'`.
  # @param [Function(BrowserFS.ApiError)] callback
  @appendFile: (filename, data, options, callback=nopCb) =>
    try
      if typeof options is 'function'
        callback = options
        options = {}
      else if typeof options is 'string'
        options = {encoding: options}
      # Only `filename` and `data` specified
      if options is undefined then options = {}
      if options.encoding is undefined then options.encoding = 'utf8'
      unless options.flag? then options.flag = 'a'
      unless options.mode? then options.mode = 0o644
      newCb = wrapCb callback, 1
      filename = @_canonicalizePath filename
      flags = BrowserFS.FileMode.getFileMode options.flag
      unless flags.isAppendable()
        return newCb new BrowserFS.ApiError BrowserFS.ApiError.INVALID_PARAM, 'Flag passed to appendFile must allow for appending.'
      @root.appendFile filename, data, options.encoding, flags, options.mode, newCb
    catch e
      newCb e

  # Asynchronously append data to a file, creating the file if it not yet
  # exists.
  #
  # @example Usage example
  #   fs.appendFile('message.txt', 'data to append', function (err) {
  #     if (err) throw err;
  #     console.log('The "data to append" was appended to file!');
  #   });
  # @param [String] filename
  # @param [String | BrowserFS.node.Buffer] data
  # @param [Object?] options
  # @option options [String] encoding Defaults to `'utf8'`.
  # @option options [Number] mode Defaults to `0644`.
  # @option options [String] flag Defaults to `'a'`.
  @appendFileSync: (filename, data, options={}) =>
    if typeof options is 'string'
      options = {encoding: options}
    # Only `filename` and `data` specified
    if options is undefined then options = {}
    if options.encoding is undefined then options.encoding = 'utf8'
    unless options.flag? then options.flag = 'a'
    unless options.mode? then options.mode = 0o644
    filename = @_canonicalizePath filename
    flags = BrowserFS.FileMode.getFileMode options.flag
    unless flags.isAppendable()
      throw new BrowserFS.ApiError BrowserFS.ApiError.INVALID_PARAM, 'Flag passed to appendFile must allow for appending.'
    @root.appendFileSync filename, data, options.encoding, flags, options.mode

  # FILE DESCRIPTOR METHODS

  # Asynchronous `fstat`.
  # `fstat()` is identical to `stat()`, except that the file to be stat-ed is
  # specified by the file descriptor `fd`.
  # @param [BrowserFS.File] fd
  # @param [Function(BrowserFS.ApiError, BrowserFS.node.fs.Stats)] callback
  @fstat: (fd, callback=nopCb) ->
    try
      newCb = wrapCb callback, 2
      fdChk = checkFd fd
      return newCb fdChk unless fdChk
      fd.stat newCb
    catch e
      newCb e
  # Synchronous `fstat`.
  # `fstat()` is identical to `stat()`, except that the file to be stat-ed is
  # specified by the file descriptor `fd`.
  # @param [BrowserFS.File] fd
  # @return [BrowserFS.node.fs.Stats]
  @fstatSync: (fd) ->
    checkFd fd, false
    return fd.statSync()
  # Asynchronous close.
  # @param [BrowserFS.File] fd
  # @param [Function(BrowserFS.ApiError)] callback
  @close: (fd, callback=nopCb) ->
    try
      newCb = wrapCb callback, 1
      fdChk = checkFd fd
      return newCb fdChk unless fdChk
      fd.close newCb
    catch e
      newCb e
  # Synchronous close.
  # @param [BrowserFS.File] fd
  @closeSync: (fd) ->
    checkFd fd, false
    return fd.closeSync()
  # Asynchronous ftruncate.
  # @param [BrowserFS.File] fd
  # @param [Number] len
  # @param [Function(BrowserFS.ApiError)] callback
  @ftruncate: (fd, len, callback=nopCb) ->
    try
      if typeof len is 'function'
        callback = len
        len = 0
      newCb = wrapCb callback, 1
      fdChk = checkFd fd
      unless fdChk then return newCb fdChk
      fd.truncate len, newCb
    catch e
      newCb e
  # Synchronous ftruncate.
  # @param [BrowserFS.File] fd
  # @param [Number] len
  @ftruncateSync: (fd, len=0) ->
    checkFd fd, false
    return fd.truncateSync len
  # Asynchronous fsync.
  # @param [BrowserFS.File] fd
  # @param [Function(BrowserFS.ApiError)] callback
  @fsync: (fd, callback=nopCb) ->
    try
      newCb = wrapCb callback, 1
      fdChk = checkFd fd
      unless fdChk then return newCb fdChk
      fd.sync newCb
    catch e
      newCb e
  # Synchronous fsync.
  # @param [BrowserFS.File] fd
  @fsyncSync: (fd) ->
    checkFd fd, false
    return fd.syncSync()
  # Asynchronous fdatasync.
  # @param [BrowserFS.File] fd
  # @param [Function(BrowserFS.ApiError)] callback
  @fdatasync: (fd, callback=nopCb) ->
    try
      newCb = wrapCb callback, 1
      fdChk = checkFd fd
      unless fdChk then return newCb fdChk
      fd.datasync newCb
    catch e
      newCb e
  # Synchronous fdatasync.
  # @param [BrowserFS.File] fd
  @fdatasyncSync: (fd) ->
    checkFd fd, false
    fd.datasyncSync()
    return
  # Write buffer to the file specified by `fd`.
  # Note that it is unsafe to use fs.write multiple times on the same file
  # without waiting for the callback.
  # @param [BrowserFS.File] fd
  # @param [BrowserFS.node.Buffer] buffer Buffer containing the data to write to
  #   the file.
  # @param [Number] offset Offset in the buffer to start reading data from.
  # @param [Number] length The amount of bytes to write to the file.
  # @param [Number] position Offset from the beginning of the file where this
  #   data should be written. If position is null, the data will be written at
  #   the current position.
  # @param [Function(BrowserFS.ApiError, Number, BrowserFS.node.Buffer)]
  #   callback The number specifies the number of bytes written into the file.
  @write: (fd, buffer, offset, length, position, callback) ->
    try
      # Alternate calling convention: Pass in a string w/ encoding to write to
      # the file.
      if typeof buffer is 'string'
        if typeof position is 'function'
          callback = position
          encoding = length
          position = offset
          offset = 0
        buffer = new Buffer buffer, encoding
        length = buffer.length

      unless callback?
        callback = position
        position = fd.getPos()
      newCb = wrapCb callback, 3
      fdChk = checkFd fd
      unless fdChk then return newCb fdChk
      unless position? then position = fd.getPos()
      fd.write buffer, offset, length, position, newCb
    catch e
      newCb e
  # Write buffer to the file specified by `fd`.
  # Note that it is unsafe to use fs.write multiple times on the same file
  # without waiting for it to return.
  # @param [BrowserFS.File] fd
  # @param [BrowserFS.node.Buffer] buffer Buffer containing the data to write to
  #   the file.
  # @param [Number] offset Offset in the buffer to start reading data from.
  # @param [Number] length The amount of bytes to write to the file.
  # @param [Number] position Offset from the beginning of the file where this
  #   data should be written. If position is null, the data will be written at
  #   the current position.
  # @return [Number]
  @writeSync: (fd, buffer, offset, length, position) ->
    # Alternate calling convention: Pass in a string w/ encoding to write to
    # the file.
    if typeof buffer is 'string'
      if typeof length is 'string'
        encoding = length
      else if typeof offset is 'string'
        encoding = offset
      else if typeof offset is 'number'
        position = offset
      offset = 0
      buffer = new Buffer buffer, encoding
      length = buffer.length

    checkFd fd, false
    unless position? then position = fd.getPos()
    return fd.writeSync buffer, offset, length, position
  # Read data from the file specified by `fd`.
  # @param [BrowserFS.File] fd
  # @param [BrowserFS.node.Buffer] buffer The buffer that the data will be
  #   written to.
  # @param [Number] offset The offset within the buffer where writing will
  #   start.
  # @param [Number] length An integer specifying the number of bytes to read.
  # @param [Number] position An integer specifying where to begin reading from
  #   in the file. If position is null, data will be read from the current file
  #   position.
  # @param [Function(BrowserFS.ApiError, Number, BrowserFS.node.Buffer)]
  #   callback The number is the number of bytes read
  @read: (fd, buffer, offset, length, position, callback=nopCb) ->
    try
      # Undocumented alternative function:
      # (fd, length, position, encoding, function(err, str, bytesRead))
      if typeof buffer is 'number' and typeof offset is 'number' and typeof length is 'string' and typeof position is 'function'
        callback = position
        position = offset
        offset = 0
        encoding = length
        length = buffer
        buffer = new BrowserFS.node.Buffer length
        # XXX: Inefficient.
        # Wrap the cb so we shelter upper layers of the API from these
        # shenanigans.
        newCb = wrapCb(((err, bytesRead, buf) ->
          if err then return oldNewCb err
          callback err, buf.toString(encoding), bytesRead
        ), 3)
      else
        newCb = wrapCb callback, 3
      fdChk = checkFd fd
      unless fdChk then return newCb fdChk
      unless position? then position = fd.getPos()
      fd.read buffer, offset, length, position, newCb
    catch e
      newCb e
  # Read data from the file specified by `fd`.
  # @param [BrowserFS.File] fd
  # @param [BrowserFS.node.Buffer] buffer The buffer that the data will be
  #   written to.
  # @param [Number] offset The offset within the buffer where writing will
  #   start.
  # @param [Number] length An integer specifying the number of bytes to read.
  # @param [Number] position An integer specifying where to begin reading from
  #   in the file. If position is null, data will be read from the current file
  #   position.
  # @return [Number]
  @readSync: (fd, buffer, offset, length, position) ->
    # Undocumented alternative function:
    # (fd, length, position, encoding, function(err, str, bytesRead))
    shenanigans = false
    if typeof buffer is 'number' and typeof offset is 'number' and typeof length is 'string'
      position = offset
      offset = 0
      encoding = length
      length = buffer
      buffer = new BrowserFS.node.Buffer length
      shenanigans = true
    checkFd fd, false
    unless position? then position = fd.getPos()
    rv = fd.readSync buffer, offset, length, position
    unless shenanigans
      return rv
    else
      return [buffer.toString(encoding), rv]
  # Asynchronous `fchown`.
  # @param [BrowserFS.File] fd
  # @param [Number] uid
  # @param [Number] gid
  # @param [Function(BrowserFS.ApiError)] callback
  @fchown: (fd, uid, gid, callback=nopCb) ->
    try
      newCb = wrapCb callback, 1
      fdChk = checkFd fd
      unless fdChk then return newCb fdChk
      fd.chown uid, gid, newCb
    catch e
      newCb e
  # Synchronous `fchown`.
  # @param [BrowserFS.File] fd
  # @param [Number] uid
  # @param [Number] gid
  @fchownSync: (fd, uid, gid) ->
    checkFd fd, false
    fd.chownSync uid, gid
  # Asynchronous `fchmod`.
  # @param [BrowserFS.File] fd
  # @param [Number] mode
  # @param [Function(BrowserFS.ApiError)] callback
  @fchmod: (fd, mode, callback=nopCb) ->
    try
      newCb = wrapCb callback, 1
      if typeof mode is 'string'
        mode = parseInt(mode, 8)
      fdChk = checkFd fd
      unless fdChk then return newCb fdChk
      fd.chmod mode, newCb
    catch e
      newCb e
  # Synchronous `fchmod`.
  # @param [BrowserFS.File] fd
  # @param [Number] mode
  @fchmodSync: (fd, mode) ->
    if typeof mode is 'string'
      mode = parseInt(mode, 8)
    checkFd fd, false
    fd.chmodSync mode
  # Change the file timestamps of a file referenced by the supplied file
  # descriptor.
  # @param [BrowserFS.File] fd
  # @param [Date] atime
  # @param [Date] mtime
  # @param [Function(BrowserFS.ApiError)] callback
  @futimes: (fd, atime, mtime, callback=nopCb) ->
    try
      newCb = wrapCb callback, 1
      fdChk = checkFd fd
      if typeof atime is 'number'
        atime = new Date atime*1000
      if typeof mtime is 'number'
        mtime = new Date mtime*1000
      unless fdChk then return newCb fdChk
      fd.utimes atime, mtime, newCb
    catch e
      newCb e
  # Change the file timestamps of a file referenced by the supplied file
  # descriptor.
  # @param [BrowserFS.File] fd
  # @param [Date] atime
  # @param [Date] mtime
  @futimesSync: (fd, atime, mtime) ->
    checkFd fd, false
    if typeof atime is 'number'
      atime = new Date atime*1000
    if typeof mtime is 'number'
      mtime = new Date mtime*1000
    fd.utimesSync atime, mtime

  # DIRECTORY-ONLY METHODS

  # Asynchronous `rmdir`.
  # @param [String] path
  # @param [Function(BrowserFS.ApiError)] callback
  @rmdir: (path, callback=nopCb) =>
    try
      newCb = wrapCb callback, 1
      path = @_canonicalizePath path
      BrowserFS.node.fs.root.rmdir path, newCb
    catch e
      newCb e
  # Synchronous `rmdir`.
  # @param [String] path
  @rmdirSync: (path) =>
    path = @_canonicalizePath path
    BrowserFS.node.fs.root.rmdirSync path
  # Asynchronous `mkdir`.
  # @param [String] path
  # @param [Number?] mode defaults to `0777`
  # @param [Function(BrowserFS.ApiError)] callback
  @mkdir: (path, mode, callback=nopCb) =>
    try
      if typeof mode is 'function'
        callback = mode
        mode = 0o777
      newCb = wrapCb callback, 1
      path = @_canonicalizePath path
      BrowserFS.node.fs.root.mkdir path, mode, newCb
    catch e
      newCb e
  # Synchronous `mkdir`.
  # @param [String] path
  # @param [Number?] mode defaults to `0777`
  @mkdirSync: (path, mode=0o777) =>
    path = @_canonicalizePath path
    BrowserFS.node.fs.root.mkdirSync path, mode

  # Asynchronous `readdir`. Reads the contents of a directory.
  # The callback gets two arguments `(err, files)` where `files` is an array of
  # the names of the files in the directory excluding `'.'` and `'..'`.
  # @param [String] path
  # @param [Function(BrowserFS.ApiError, String[])] callback
  @readdir: (path, callback=nopCb) =>
    try
      newCb = wrapCb callback, 2
      path = @_canonicalizePath path
      @root.readdir path, newCb
    catch e
      newCb e
  # Synchronous `readdir`. Reads the contents of a directory.
  # @param [String] path
  # @return [String[]]
  @readdirSync: (path) =>
    path = @_canonicalizePath path
    @root.readdirSync path

  # SYMLINK METHODS

  # Asynchronous `link`.
  # @param [String] srcpath
  # @param [String] dstpath
  # @param [Function(BrowserFS.ApiError)] callback
  @link: (srcpath, dstpath, callback=nopCb) =>
    try
      newCb = wrapCb callback, 1
      srcpath = @_canonicalizePath srcpath
      dstpath = @_canonicalizePath dstpath
      @root.link srcpath, dstpath, newCb
    catch e
      newCb e
  # Synchronous `link`.
  # @param [String] srcpath
  # @param [String] dstpath
  @linkSync: (srcpath, dstpath) =>
    srcpath = @_canonicalizePath srcpath
    dstpath = @_canonicalizePath dstpath
    @root.linkSync srcpath, dstpath
  # Asynchronous `symlink`.
  # @param [String] srcpath
  # @param [String] dstpath
  # @param [String?] type can be either `'dir'` or `'file'` (default is `'file'`)
  # @param [Function(BrowserFS.ApiError)] callback
  @symlink: (srcpath, dstpath, type, callback=nopCb) =>
    try
      if typeof type is 'function'
        callback = type
        type = 'file'
      newCb = wrapCb callback, 1
      if type isnt 'file' and type isnt 'dir'
        return newCb new BrowserFS.ApiError BrowserFS.ApiError.INVALID_PARAM, "Invalid type: #{type}"
      srcpath = @_canonicalizePath srcpath
      dstpath = @_canonicalizePath dstpath
      @root.symlink srcpath, dstpath, type, newCb
    catch e
      newCb e
  # Synchronous `symlink`.
  # @param [String] srcpath
  # @param [String] dstpath
  # @param [String?] type can be either `'dir'` or `'file'` (default is `'file'`)
  @symlink: (srcpath, dstpath, type='file') =>
    if type isnt 'file' and type isnt 'dir'
      throw new BrowserFS.ApiError BrowserFS.ApiError.INVALID_PARAM, "Invalid type: #{type}"
    srcpath = @_canonicalizePath srcpath
    dstpath = @_canonicalizePath dstpath
    @root.symlinkSync srcpath, dstpath, type

  # Asynchronous readlink.
  # @param [String] path
  # @param [Function(BrowserFS.ApiError, String)] callback
  @readlink: (path, callback=nopCb) =>
    try
      newCb = wrapCb callback, 2
      path = @_canonicalizePath path
      @root.readlink path, newCb
    catch e
      newCb e
  # Synchronous readlink.
  # @param [String] path
  # @return [String]
  @readlinkSync: (path) =>
    path = @_canonicalizePath path
    @root.readlinkSync path

  # PROPERTY OPERATIONS

  # Asynchronous `chown`.
  # @param [String] path
  # @param [Number] uid
  # @param [Number] gid
  # @param [Function(BrowserFS.ApiError)] callback
  @chown: (path, uid, gid, callback=nopCb) =>
    try
      newCb = wrapCb callback, 1
      path = @_canonicalizePath path
      @root.chown path, false, uid, gid, newCb
    catch e
      newCb e
  # Synchronous `chown`.
  # @param [String] path
  # @param [Number] uid
  # @param [Number] gid
  @chownSync: (path, uid, gid) =>
    path = @_canonicalizePath path
    @root.chownSync path, false, uid, gid
  # Asynchronous `lchown`.
  # @param [String] path
  # @param [Number] uid
  # @param [Number] gid
  # @param [Function(BrowserFS.ApiError)] callback
  @lchown: (path, uid, gid, callback=nopCb) =>
    try
      newCb = wrapCb callback, 1
      path = @_canonicalizePath path
      @root.chown path, true, uid, gid, newCb
    catch e
      newCb e
  # Synchronous `lchown`.
  # @param [String] path
  # @param [Number] uid
  # @param [Number] gid
  @lchownSync: (path, uid, gid) =>
    path = @_canonicalizePath path
    @root.chownSync path, true, uid, gid
  # Asynchronous `chmod`.
  # @param [String] path
  # @param [Number] mode
  # @param [Function(BrowserFS.ApiError)] callback
  @chmod: (path, mode, callback=nopCb) =>
    try
      newCb = wrapCb callback, 1
      if typeof mode is 'string'
        mode = parseInt(mode, 8)
      path = @_canonicalizePath path
      @root.chmod path, false, mode, newCb
    catch e
      newCb e
  # Synchronous `chmod`.
  # @param [String] path
  # @param [Number] mode
  @chmodSync: (path, mode) =>
    if typeof mode is 'string'
      mode = parseInt(mode, 8)
    path = @_canonicalizePath path
    @root.chmodSync path, false, mode
  # Asynchronous `lchmod`.
  # @param [String] path
  # @param [Number] mode
  # @param [Function(BrowserFS.ApiError)] callback
  @lchmod: (path, mode, callback=nopCb) =>
    try
      newCb = wrapCb callback, 1
      if typeof mode is 'string'
        mode = parseInt(mode, 8)
      path = @_canonicalizePath path
      @root.chmod path, true, mode, newCb
    catch e
      newCb e
  # Synchronous `lchmod`.
  # @param [String] path
  # @param [Number] mode
  @lchmodSync: (path, mode) =>
    path = @_canonicalizePath path
    if typeof mode is 'string'
      mode = parseInt(mode, 8)
    @root.chmodSync path, true, mode
  # Change file timestamps of the file referenced by the supplied path.
  # @param [String] path
  # @param [Date] atime
  # @param [Date] mtime
  # @param [Function(BrowserFS.ApiError)] callback
  @utimes: (path, atime, mtime, callback=nopCb) =>
    try
      newCb = wrapCb callback, 1
      path = @_canonicalizePath path
      if typeof atime is 'number'
        atime = new Date atime*1000
      if typeof mtime is 'number'
        mtime = new Date mtime*1000
      @root.utimes path, atime, mtime, newCb
    catch e
      newCb e
  # Change file timestamps of the file referenced by the supplied path.
  # @param [String] path
  # @param [Date] atime
  # @param [Date] mtime
  @utimesSync: (path, atime, mtime) =>
    path = @_canonicalizePath path
    if typeof atime is 'number'
      atime = new Date atime*1000
    if typeof mtime is 'number'
      mtime = new Date mtime*1000
    @root.utimesSync path, atime, mtime

  # Asynchronous `realpath`. The callback gets two arguments
  # `(err, resolvedPath)`. May use `process.cwd` to resolve relative paths.
  #
  # @example Usage example
  #   var cache = {'/etc':'/private/etc'};
  #   fs.realpath('/etc/passwd', cache, function (err, resolvedPath) {
  #     if (err) throw err;
  #     console.log(resolvedPath);
  #   });
  #
  # @param [String] path
  # @param [Object?] cache An object literal of mapped paths that can be used to
  #   force a specific path resolution or avoid additional `fs.stat` calls for
  #   known real paths.
  # @param [Function(BrowserFS.ApiError, String)] callback
  @realpath: (path, cache, callback=nopCb) =>
    try
      if typeof cache is 'function'
        callback = cache
        cache = {}
      newCb = wrapCb callback, 2
      path = @_canonicalizePath path
      @root.realpath path, cache, newCb
    catch e
      newCb e
  # Synchronous `realpath`.
  # @param [String] path
  # @param [Object?] cache An object literal of mapped paths that can be used to
  #   force a specific path resolution or avoid additional `fs.stat` calls for
  #   known real paths.
  # @return [String]
  @realpathSync: (path, cache={}) =>
    path = @_canonicalizePath path
    @root.realpathSync path, cache

# Represents one of the following file modes. A convenience object.
#
# * `'r'` - Open file for reading. An exception occurs if the file does not exist.
# * `'r+'` - Open file for reading and writing. An exception occurs if the file does not exist.
# * `'rs'` - Open file for reading in synchronous mode. Instructs the filesystem to not cache writes.
# * `'rs+'` - Open file for reading and writing, and opens the file in synchronous mode.
# * `'w'` - Open file for writing. The file is created (if it does not exist) or truncated (if it exists).
# * `'wx'` - Like 'w' but opens the file in exclusive mode.
# * `'w+'` - Open file for reading and writing. The file is created (if it does not exist) or truncated (if it exists).
# * `'wx+'` - Like 'w+' but opens the file in exclusive mode.
# * `'a'` - Open file for appending. The file is created if it does not exist.
# * `'ax'` - Like 'a' but opens the file in exclusive mode.
# * `'a+'` - Open file for reading and appending. The file is created if it does not exist.
# * `'ax+'` - Like 'a+' but opens the file in exclusive mode.
#
# Exclusive mode ensures that the file path is newly created.
class BrowserFS.FileMode
  # Contains cached FileMode instances.
  @modeCache = {}
  # Array of valid mode strings.
  @validModeStrs = ['r','r+','rs','rs+','w','wx','w+','wx+','a','ax','a+','ax+']

  # Get an object representing the given file mode.
  # @param [String] modeStr The string representing the mode
  # @return [BrowserFS.FileMode] The FileMode object representing the mode
  # @throw [BrowserFS.ApiError] when the mode string is invalid
  @getFileMode: (modeStr) =>
    # Check cache first.
    if modeStr in @modeCache
      return @modeCache[modeStr]
    fm = new BrowserFS.FileMode modeStr
    @modeCache[modeStr] = fm
    return fm

  # Indicates that the code should not do anything.
  @NOP: 0
  # Indicates that the code should throw an exception.
  @THROW_EXCEPTION: 1
  # Indicates that the code should truncate the file, but only if it is a file.
  @TRUNCATE_FILE: 2
  # Indicates that the code should create the file.
  @CREATE_FILE: 3

  # This should never be called directly.
  # @param [String] modeStr The string representing the mode
  # @throw [BrowserFS.ApiError] when the mode string is invalid
  constructor: (@modeStr) ->
    unless modeStr in BrowserFS.FileMode.validModeStrs
      throw new BrowserFS.ApiError BrowserFS.ApiError.INVALID_PARAM, "Invalid mode string: #{modeStr}"

  # Returns true if the file is readable.
  # @return [Boolean]
  isReadable: -> return @modeStr.indexOf('r') != -1 or @modeStr.indexOf('+') != -1
  # Returns true if the file is writeable.
  # @return [Boolean]
  isWriteable: -> return @modeStr.indexOf('w') != -1 or @modeStr.indexOf('a') != -1 or @modeStr.indexOf('+') != -1
  # Returns true if the file mode should truncate.
  # @return [Boolean]
  isTruncating: -> return @modeStr.indexOf('w') != -1
  # Returns true if the file is appendable.
  # @return [Boolean]
  isAppendable: -> return @modeStr.indexOf('a') != -1
  # Returns true if the file is open in synchronous mode.
  # @return [Boolean]
  isSynchronous: -> return @modeStr.indexOf('s') != -1
  # Returns true if the file is open in exclusive mode.
  # @return [Boolean]
  isExclusive: -> return @modeStr.indexOf('x') != -1
  # Returns one of the static fields on this object that indicates the
  # appropriate response to the path existing.
  # @return [Number]
  pathExistsAction: ->
    if @isExclusive() then return BrowserFS.FileMode.THROW_EXCEPTION
    else if @isTruncating() then return BrowserFS.FileMode.TRUNCATE_FILE
    else return BrowserFS.FileMode.NOP
  # Returns one of the static fields on this object that indicates the
  # appropriate response to the path not existing.
  # @return [Number]
  pathNotExistsAction: ->
    if (@isWriteable() or @isAppendable()) and @modeStr isnt 'r+' then return BrowserFS.FileMode.CREATE_FILE
    else return BrowserFS.FileMode.THROW_EXCEPTION
