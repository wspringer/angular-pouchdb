pouchdb = angular.module 'pouchdb', ['ng']

# Quick access to array functions
slice = Array.prototype.slice
concat = Array.prototype.concat

# Copy of sortedIndex; returns position where we need to insert an element in order to preserver the sort order.
sortedIndex = (array, value, callback) ->
  low = 0
  high = if array? then array.length else low

  callback = callback or identity
  value = callback(value)

  while (low < high)
    mid = (low + high) >>> 1
    if callback(array[mid]) < value
      low = mid + 1
    else
      high = mid
  return low

# Assume sorted index
indexOf = (array, value, callback) ->
  idx = sortedIndex(array, value, callback)
  if array[idx] == value idx else -1



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
      id: db.id
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
  ($parse, $animate) ->
    transclude: 'element'
    priority: 10
    compile: (elem, attrs, transclude) ->
      ($scope, $element, $attr) ->
        parent = $element.parent()
        top = angular.element(document.createElement('div'))
        parent.append(top)
        [cursor, collection, sort] =
          /^\s*([a-zA-Z0-9]+)\s*in\s*([a-zA-Z0-9]+)\s*(?:order by\s*([a-zA-Z0-9\.,]+))?$/.exec($attr.pouchRepeat).splice(1)

        # The blocks managed by this directive.
        blocks = []

        vectorOf =
          if sort?
            getters =
              $parse(fld) for fld in sort.split(',')
            console.info 'getters', getters
            (doc) ->
              for getter in getters
                getter(doc)
          else null

#        sortOrder = (first, second, fn) ->
#          mappedFirst = fn(first)
#          mappedSecond = fn(second)
#          if mappedFirst < mappedSecond -1
#          else if mappedFirst > mappedSecond 1
#          else 0

        add =  (doc) ->
          childScope = $scope.$new();
          childScope[cursor] = doc
          transclude childScope, (clone) ->
            block =
              doc    : doc
              clone  : clone
              scope  : childScope
              vector : if vectorOf? then vectorOf(doc) else null
            last = blocks[blocks.length - 1]
            if vectorOf?
              console.info 'Block vector', block.vector
              console.info 'Blocks', blocks
              index = sortedIndex(blocks, block, (block) -> block.vector)
              console.info 'Index', index
              preceding =
                if (index > 0)
                  blocks[index - 1]
                else
                  null
              if preceding? then console.info "Adding after", doc, preceding.doc
              $animate.enter(clone, parent, if preceding? then preceding.clone else top)
              blocks = concat.call(
                slice.call(blocks, 0, index - 1),
                [block],
                slice.call(blocks, index)
              )

            else
              blocks.push(block)
              if last?
                $animate.enter(clone, parent, last.clone)
              else
                $animate.enter(clone, parent, top)

        update = (doc) ->
          wrapped =
            doc: doc
          idx = indexOf(blocks, wrapped, (block) -> block.doc.id)
          block = blocks[idx]
          block.scope[cursor] = doc
          block.vector = vectorOf(doc)
          stripped = concat.call(
            slice.call(blocks, 0, idx - 1),
            slice.call(blocks, idx + 1)
          )
          newidx = sortedIndex(stripped, block, (block) -> block.vector)
          blocks = concat.call(
            slice.call(blocks, 0, newidx - 1),
            [block],
            slice.call(blocks, newidx)
          )
          $animate.move(
            block.clone,
            parent,
            if newidx > 0 then blocks[newidx - 1] else top
          )

        remove = (doc) ->
          wrapped =
            doc: doc
          idx = indexOf(blocks, wrapped, (block) -> block.doc.id)
          block = blocks[idx]
          if block? then block.scope.$destroy()




        $scope.$watch collection
          , ->
            # Not using query, since the map function doesn't accept emit as an argument just yet.
            process = (result) ->
              for row in result.rows
                add(row.doc)
            $scope[collection].allDocs({include_docs: true}).then(process)

            $scope[collection].info().then (info) ->
              $scope[collection].changes
                include_docs: true
                continuous: true
                since: info.update_seq
                onChange: (update) ->
                  if update.deleted then remove(update.doc)
                  else
                    idx = indexOf(blocks, { doc: updated.doc }, (block) -> block.doc.id)
                    if idx >= 0
                      update(update.doc)
                    else
                      add(update.doc)
            return
