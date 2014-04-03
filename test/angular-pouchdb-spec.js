/**
 * Some of these tests require CouchDB to be running on a default port with default permissions.
 */
describe('pouchdb', function () {

  beforeEach(module('pouchdb'));

  function recreate(name, callback) {
    var db = new PouchDB(name);
    db.destroy().then(function() {
      db = new PouchDB(name);
      callback(db);
    })
  }

  var doc = {
    _id: 'foo',
    title: 'bar'
  };



  it('should support replication', inject(function (pouchdb, $rootScope) {

    var replicated = false;
    var local, remote;

    runs(function () {
      recreate('local1', function(local1) {
        local = local1;
        recreate('remote1', function(remote1) {
          remote = remote1;
          local.replicate.to(remote, {
            onChange: function() {
              replicated = true;
            }, continous: true
          });
          local.put(doc);
        });
      });
    });

    waitsFor(function () {
      $rootScope.$digest();
      return replicated;
    }, 'Waiting till replicated', 2000);

    runs(function () {
      remote.get(doc._id).then(function (value) {
        expect(value).not.toBeNull();
      });
    });

  }));



  it('should support remote replication', inject(function (pouchdb, $rootScope) {

    var replicated = false;
    var local, remote;

    runs(function () {
      recreate('local2', function(local1) {
        local = local1;
        recreate('http://localhost:5984/remote2', function(remote1) {
          remote = remote1;
          local.replicate.to(remote, {
            onChange: function() {
              replicated = true;
            }, continous: true
          });
          local.put(doc);
        });
      });
    });

    waitsFor(function () {
      $rootScope.$digest();
      return replicated;
    }, 'Waiting till replicated', 2000);

    runs(function () {
      remote.get(doc._id).then(function (value) {
        expect(value).not.toBeNull();
      });
    });

  }));


  it('should support replication from remote', inject(function (pouchdb, $rootScope) {

    var replicated = false;
    var local, remote;

    runs(function () {
      recreate('local3', function(local1) {
        local = local1;
        recreate('http://localhost:5984/remote3', function(remote1) {
          remote = remote1;
          remote.replicate.to(local, {
            onChange: function() {
              replicated = true;
            }, continous: true
          });
          remote.put(doc);
        });
      });
    });

    waitsFor(function () {
      $rootScope.$digest();
      return replicated;
    }, 'Waiting till replicated', 2000);

    runs(function () {
      local.get(doc._id).then(function (value) {
        expect(value).not.toBeNull();
      });
    });

  }));



  it('should allow you to store and retrieve documents', inject(function (pouchdb, $rootScope) {
    var done = false;
    var doc = {
      _id: 'foo',
      title: 'bar'
    };
    runs(function () {
      recreate('test', function(db) {
        db.put(doc).then(function () {
          db.get(doc._id).then(function (result) {
            var retrieved = result;
            expect(retrieved).not.toBeNull();
            expect(retrieved.title).toBe('bar');
            db.destroy().then(function () {
              done = true;
            });
          }).catch(function (error) {
            dump(error);
          });
          $rootScope.$digest();
        }).catch(function (error) {
          dump(error);
        });
      });
    });

    waitsFor(function () {
      $rootScope.$digest();
      return done;
    }, 'Waiting till done for good', 5000);

  }));

});
