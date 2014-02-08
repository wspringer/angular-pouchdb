pouchdb = angular.module 'pouchdb', ['ng']

# Quick access to slice
slice = Array.prototype.slice

pouchdb.provider 'pouchdb', ->

  withAllDbsEnabled: ->
    PouchDB.enableAllDbs = true

  $get: ($q, $rootScope) ->

    qify = (fn) ->
      () ->
        deferred = $q.defer()
        callback = (err, res) ->
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

# pouch-repeat="name in collection"
pouchdb.directive 'pouchRepeat',
  () ->
    transclude: 'element'
    compile: (elem, attrs, transclude) ->
      ($scope, $element, $attr) ->
        console.info '$transclude', transclude
        parent = $element.parent()
        console.info $attr.pouchRepeat
        [cursor, collection] = /^\s*([a-zA-Z0-9]+)\s*in\s*([a-zA-Z0-9]+)\s*$/.exec($attr.pouchRepeat).splice(1)

        $scope.$watch collection
          , ->
            displayRow = (doc) ->
              childScope = $scope.$new()
              childScope[cursor] = doc
              transclude childScope, (clone) ->
                parent.append(clone)

            displayAll = (docs) ->
              displayRow(doc) for doc in docs.rows

            $scope[collection].allDocs().then(displayAll)
            return
