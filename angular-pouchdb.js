(function() {
  var pouchdb, slice;

  pouchdb = angular.module('pouchdb', ['ng']);

  slice = Array.prototype.slice;

  pouchdb.provider('pouchdb', function() {
    return {
      withAllDbsEnabled: function() {
        return PouchDB.enableAllDbs = true;
      },
      $get: function($q, $rootScope, $timeout) {
        var qify;
        qify = function(fn) {
          return function() {
            var args, callback, deferred;
            deferred = $q.defer();
            callback = function(err, res) {
              return $timeout(function() {
                return $rootScope.$apply(function() {
                  if (err) {
                    return deferred.reject(err);
                  } else {
                    return deferred.resolve(res);
                  }
                });
              });
            };
            args = arguments != null ? slice.call(arguments) : [];
            args.push(callback);
            fn.apply(this, args);
            return deferred.promise;
          };
        };
        return {
          create: function(name, options) {
            var db;
            db = new PouchDB(name, options);
            return {
              put: qify(db.put),
              post: qify(db.post),
              get: qify(db.get),
              remove: qify(db.remove),
              bulkDocs: qify(db.bulkDocs),
              allDocs: qify(db.allDocs),
              changes: function(options) {
                var clone;
                clone = angular.copy(options);
                clone.onChange = function(change) {
                  return $rootScope.$apply(function() {
                    return options.onChange(change);
                  });
                };
                return db.changes(clone);
              },
              putAttachment: qify(db.putAttachment),
              getAttachment: qify(db.getAttachment),
              removeAttachment: qify(db.removeAttachment),
              query: qify(db.query),
              info: qify(db.info),
              compact: qify(db.compact),
              revsDiff: qify(db.revsDiff)
            };
          },
          allDbs: qify(PouchDB.allDbs),
          destroy: qify(PouchDB.destroy),
          replicate: PouchDB.replicate
        };
      }
    };
  });

}).call(this);

/*
//@ sourceMappingURL=angular-pouchdb.js.map
*/
