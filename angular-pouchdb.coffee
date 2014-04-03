###
The MIT License

Copyright (c) 2013-2014 Wilfred Springer, http://nxt.flotsam.nl/

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
###

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

indexOf = (array, cond) ->
  pos = 0
  while pos < array.length and !cond(array[pos])
    pos = pos + 1
  if pos < array.length then pos else -1

exists = (array, cond) ->
  indexOf(array, cond) >= 0



pouchdb.provider 'pouchdb', ->

  withAllDbsEnabled: ->
    PouchDB.enableAllDbs = true

  $get: ($q, $rootScope, $timeout) ->

    qify = (fn) ->
      () ->
        deferred = $q.defer()
        callback = (err, res) ->
          $timeout () ->
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
      put: qify db.put.bind(db)
      post: qify db.post.bind(db)
      get: qify db.get.bind(db)
      remove: qify db.remove.bind(db)
      bulkDocs: qify db.bulkDocs.bind(db)
      allDocs: qify db.allDocs.bind(db)
      changes: (options) ->
        clone = angular.copy options
        clone.onChange = (change) ->
          $rootScope.$apply () ->
            options.onChange change
        db.changes clone
      putAttachment: qify db.putAttachment.bind(db)
      getAttachment: qify db.getAttachment.bind(db)
      removeAttachment: qify db.removeAttachment.bind(db)
      query: qify db.query.bind(db)
      info: qify db.info.bind(db)
      compact: qify db.compact.bind(db)
      revsDiff: qify db.revsDiff.bind(db)
      replicate:
        to: db.replicate.to.bind(db)
        from: db.replicate.from.bind(db)
        sync: db.replicate.sync.bind(db)
      destroy: qify db.destroy.bind(db)

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
          idx = indexOf(blocks, (block) -> block.doc._id == doc._id)
          block = blocks[idx]
          block.scope[cursor] = doc
          if vectorOf?
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
          idx = indexOf(blocks, (block) -> block.doc._id == id)
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
