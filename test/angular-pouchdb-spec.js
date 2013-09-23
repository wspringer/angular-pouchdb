describe('pouchdb', function() {

  beforeEach(module('pouchdb'));

  it("should allow you to store and retrieve documents", inject(function(pouchdb, $rootScope) {
    var retrieved;
    var stored = false;
    var done = false;
    var doc = {
      _id: 'foo',
      title: 'bar'
    };
    
    runs(function() {
      var db = pouchdb.create('test');

      debugger;

      var result = db.put(doc).then(function() {
        stored = true;
        db.get(doc._id).then(function(result) {
          retrieved = result;
          done = true;
        });
      }).catch(function(error) {
        dump(error);
      }).finally(function() {
                pouchdb.destroy('test').finally(function() {
                    done = true;
                });
            });
        });

        waitsFor(function() {
            return done;
        }, "Waiting till done", 2000);

        runs(function() {
            expect(stored).toBe(true);
            expect(retrieved).not.toBeNull();
            expect(retrieved.title).toBe('bar');
        });
    
    }));

});
