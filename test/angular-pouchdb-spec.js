/**
 * Some of these tests require CouchDB to be running on a default port with default permissions.
 */
'use strict';

describe('pouchdb', function () {

  var pouchdb;

  beforeEach(module('pouchdb'));

  beforeEach(inject(function (_pouchdb_) {
      pouchdb = _pouchdb_;
  }));

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

  it('should support replication', function (done) {
    recreate('local1', function(local1) {
      recreate('local2', function(local2) {
        local1.replicate.to(local2, {
          onChange: function () {
            local2.get(doc._id).then(function (value) {
              expect(value, "replication NOT supported").not.toBeNull();
              done();
            });
          }
        });
        local1.put(doc);
      });
    });
  });

  it('should support local to remote replication', function (done) {
    recreate('local2', function(local) {
      recreate('http://localhost:5984/remote2', function(remote2) {
        local.replicate.to(remote2, {
          onChange: function () {
            remote2.get(doc._id).then(function (value) {
              expect(value, "local NOT replicated to remote").not.toBeNull();
              done();
            });
          }
        });
        local.put(doc);
      });
    });
  });


  it('should support replication from remote', function (done) {
    recreate('local3', function(local) {
      recreate('http://localhost:5984/remote3', function(remote3) {
        remote3.replicate.to(local, {
          onChange: function () {
            local.get(doc._id).then(function (value) {
              expect(value, "remote DID NOT replicate from remote").not.toBeNull();
              done();
            });
          }
        });
        remote3.put(doc);
      });
    });
  });


  it('should allow you to store and retrieve documents', function (done) {
    recreate('test', function(db) {
      db.put(doc).then(function () {
        db.get(doc._id).then(function (result) {
          var retrieved = result;
          expect(retrieved).not.toBeNull();
          expect(retrieved.title).toBe('bar');
          db.destroy().then(function () {
            done();
          });
        }).catch(function (error) {
          dump(error);
        });
      }).catch(function (error) {
        dump(error);
      });
    });
  });

});
