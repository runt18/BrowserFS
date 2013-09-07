#! /usr/bin/env coffee

google = require 'googleapis'
open = require 'open'
http = require 'http'
url = require 'url'
fs = require 'fs'

id = '555024705616.apps.googleusercontent.com'
secret = '5e9PHL3GL7lR8hyGfIW_ssWY'
port = 8000
redirect = "http://localhost:#{port}/oauth2callback"
scope = 'https://www.googleapis.com/auth/drive'

client = new google.OAuth2Client(id, secret, redirect)
callback = client.generateAuthUrl({
  access_type: 'offline'
  scope: scope
})

http.createServer((req, res) ->
  {code} = url.parse(req.url, true).query
  if code
    data = JSON.stringify({code: code})
    fs.mkdirSync('test/google') unless fs.existsSync('test/google')
    fs.writeFileSync('test/google/token.json', data)
    res.end('Authenticated sucessfuly. Please close this page.\n')
    console.log('Done')
    process.exit(0)
  else
    console.error('error')
    process.exit(1)
).listen(port, '127.0.0.1')

open(callback, (err) ->
  if err
    console.error(err)
    return
)
