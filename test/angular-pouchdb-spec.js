describe('pouchdb', function () {

  beforeEach(module('pouchdb'));

  it('should support replication', inject(function(pouchdb, $rootScope){
    var retrieved = null;
    var replicated = false;
    var stored = false;
    var doc = {
      _id: 'foo',
      title: 'bar'
    };

    var db = pouchdb.create('replication');
    var remote = new PouchDB('remote');

    runs(function() {
      db.replicate.to(remote, {
        onChange: function() {
          replicated = true;
        },
        continuous: true
      });
      db.put(doc).then(function() {
        stored = true;
      })
    });

    waitsFor(function() {
      $rootScope.$digest();
      return replicated;
    }, 'Waiting till done', 2000);

    runs(function() {
      remote.get(doc._id).then(function(value) {
        retrieved = value;
      });
    });

    waitsFor(function() {
      $rootScope.$digest();
      return retrieved != null;
    }, 'Waiting till available', 2000);

    runs(function() {
      expect(retrieved).not.toBeNull();
      db.destroy().then(function() {
        remote.destroy();
      })
    });

  }));

  it('should allow you to store and retrieve documents', inject(function (pouchdb, $rootScope) {

    var stored = false;
    var done = false;
    var doc = {
      _id: 'foo',
      title: 'bar'
    };
    var db = pouchdb.create('test');
    runs(function () {
      db.put(doc).then(function () {
        stored = true;
        db.get(doc._id).then(function (result) {
          var retrieved = result;
          expect(retrieved).not.toBeNull();
          expect(retrieved.title).toBe('bar');
          db.destroy().then(function () {
            done = true;
          });
        });
      }).catch(function (error) {
        dump(error);
      });
    });

    waitsFor(function () {
      $rootScope.$digest();
      return done;
    }, 'Waiting till done for good', 5000);

  }));

});
