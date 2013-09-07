#! /usr/bin/env coffee

google = require 'googleapis'
open = require 'open'
http = require 'http'
url = require 'url'

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
    console.log(code)
    res.end('Authenticated sucessfuly. Please close this page.\n')
    process.exit(0)
  else
    console.log('error')
    process.exit(1)
).listen(port, '127.0.0.1')

open(callback, (err) ->
  if err
    console.error(err)
    return
)
