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
  if array[idx] == value then idx else -1

find = (array, cond) ->
  console.info 'Finding'
  pos = 0
  while pos < array.length and !cond(array[pos])
    pos = pos + 1
  if pos < array.length
    console.info 'Found it'
    pos
  else
    console.info 'Didn\'t find it'
    -1

exists = (array, cond) ->
  find(array, cond) >= 0



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
            (doc) ->
              for getter in getters
                getter(doc)
          else null

        add = (doc) ->
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
              index = sortedIndex(blocks, block, (block) -> block.vector)
              preceding =
                if (index > 0)
                  blocks[index - 1]
                else
                  null
              $animate.enter(clone, parent, if preceding? then preceding.clone else top)
              blocks.splice(index, 0, block)
            else
              blocks.push(block)
              if last?
                $animate.enter(clone, parent, last.clone)
              else
                $animate.enter(clone, parent, top)

        modify = (doc) ->
          idx = find(blocks, (block) -> block.doc._id == doc._id)
          block = blocks[idx]
          block.scope[cursor] = doc
          if vectorOf?
            console.info 'Repositioning'
            block.vector = vectorOf(doc)
            blocks.splice(idx, 1)
            newidx = sortedIndex(blocks, block, (block) -> block.vector)
            blocks.splice(newidx, 0, block)
            $animate.move(
              block.clone,
              parent,
              if newidx > 0 then blocks[newidx - 1].clone else top
            )

        remove = (id) ->
          idx = find(blocks, (block) -> block.doc._id == id)
          block = blocks[idx]
          if block?
            $animate.leave block.clone, ->
              block.scope.$destroy()




        $scope.$watch collection
          , () ->
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
                  if update.deleted then remove(update.doc._id)
                  else
                    if exists(blocks, (block) -> block.doc._id == update.doc._id)
                      modify(update.doc)
                    else
                      add(update.doc)
            return
