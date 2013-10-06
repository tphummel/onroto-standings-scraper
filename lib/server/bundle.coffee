fs              = require 'fs'
browserify      = require 'browserify'


vendor = [
  './lib/client/vendor/jquery.min.js'
  './lib/client/vendor/bootstrap.js'
  './lib/client/vendor/bootstrap-sortable.js'
]

opts =
  noParse: vendor
  
if process.env.NODE_ENV is 'development'
  opts.debug = true

bundle = browserify opts

for js in vendor
  bundle.add js

bundle.add './lib/client/entry.coffee'

out = fs.createWriteStream './public/main.js'
bs = bundle.bundle()
bs.pipe out

bs.on 'end', -> 
  bundle.emit 'end'
  console.log "browserified..."

module.exports = bundle