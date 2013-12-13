pouchdb = angular.module 'pouchdb', ['ng']

# Quick access to slice
slice = Array.prototype.slice

pouchdb.provider 'pouchdb', ->
  withAllDbsEnabled: ->
    PouchDB.enableAllDbs = true
  $get: ($q, $rootScope, $timeout) ->
    qify = (fn) ->
      () ->
        deferred = $q.defer()
        callback = (err, res) ->
          $timeout ->
            $rootScope.$apply () ->
              if (err)
                deferred.reject err
              else
                deferred.resolve res
        args = if arguments? then slice.call(arguments) else []
        args.push callback
        fn.apply this, args
        deferred.promise
    create: (name, options) ->
      db = new PouchDB(name, options)
      put: qify db.put
      post: qify db.post
      get: qify db.get
      remove: qify db.remove
      bulkDocs: qify db.bulkDocs
      allDocs: qify db.allDocs
      changes: (options) ->
        clone = angular.copy options
        clone.onChange = (change) ->
          $rootScope.$apply () ->
            options.onChange change
        db.changes clone
      putAttachment: qify db.putAttachment
      getAttachment: qify db.getAttachment
      removeAttachment: qify db.removeAttachment
      query: qify db.query
      info: qify db.info
      compact: qify db.compact
      revsDiff: qify db.revsDiff
    allDbs: qify PouchDB.allDbs
    destroy: qify PouchDB.destroy
    replicate: PouchDB.replicate


