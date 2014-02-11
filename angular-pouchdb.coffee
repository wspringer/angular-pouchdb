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
  ($parse) ->
    transclude: 'element'
    compile: (elem, attrs, transclude) ->
      ($scope, $element, $attr) ->
        parent = $element.parent()
        [cursor, collection, sort] =
          /^\s*([a-zA-Z0-9]+)\s*in\s*([a-zA-Z0-9]+)\s*(?:order by\s*([a-zA-Z0-9\.]+))?$/.exec($attr.pouchRepeat).splice(1)
        blocks = {}

        $scope.$watch collection
          , ->
            displayDoc = (doc) ->
              childScope = $scope.$new()
              childScope[cursor] = doc
              transclude childScope, (clone) ->
                blocks[doc._id] =
                  clone: clone
                  scope: childScope
                parent.append(clone)

            displayAll = (docs) ->
              displayDoc(doc) for doc in docs

            extractDocs = (result) ->
              row.doc for row in result.rows

            # Not using query, since the map function doesn't accept emit as an argument just yet.
            process =
              if sort?
                getter = $parse(sort)
                sortorder = (first, second) ->
                  x = getter(first)
                  y = getter(second)
                  if x < y
                    -1
                  else if x > y
                    1
                  else
                    0
                (result) -> displayAll(extractDocs(result).sort(sortorder))
              else
                (result) -> displayAll(extractDocs(result))

            $scope[collection].allDocs({include_docs: true}).then(process)

            $scope[collection].info().then (info) ->
              $scope[collection].changes
                include_docs: true
                continuous: true
                since: info.update_seq
                onChange: (update) ->
                  block = blocks[update.id]
                  if update.deleted
                    block.clone.remove()
                    block.scope.$destroy()
                  else
                    if block?
                      block.scope[cursor] = update.doc
                    else
                      displayDoc(update.doc)
            return
