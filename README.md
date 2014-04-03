# Caution

Integration with PouchDB is currently broken. The `pouch2` branch seems to some extent, but fails while replicating data. Work is underway to fix it. 

# AngularJS PouchDB Support

A simple wrapper for PouchDB, to make integration into AngularJS applications a breeze. So what does it do?

* It wraps PouchDB as a provider, allowing you to set global configuration before your dependencies are getting injected.
* It uses `$q`-based promises instead of callbacks: `db.put({...})` will return a promise with the results, and no longer accepts a callback as the last parameter. The same goes for all other operations that normally required callbacks.
* It will make sure Angular is aware of asynchronous updates. (It will make sure it uses `$rootScope.$apply()` in cases where it makes sense.)
* It has a directive for traversing the contents of your database:
  * Sorting it,
  * Injecting data coming into your database in the right spot,
  * Using ngAnimate allowing you to animate your incoming data into place.

## Usage

First you need to get `angular-pouchdb`. Using bower, it's easy:

```
bower install -S angular-pouchdb
```

Then you will need to register pouchdb as a dependency. 

```javascript
var app = angular.module('app', ['pouchdb']);
```
    
Once you have added a dependency on the pouchdb *module*, you will have the ability to inject the pouchdb object into your services:

```javascript
angular.factory('someservice', function(pouchdb) {
  // Do something with pouchdb.
});
```

### Creating and destroying a database 

Once you have a reference to the pouchdb object, creating a database is easy:

```javascript
var db = pouchdb.create('testdb');
```
    
And destroying it is equally easy:

```javascript    
pouchdb.destroy('testdb');
``` 

### Interacting with the database

The `db` object created above allows you to call all of the operations PouchDB defines on a database. The API is not identical though. In all of the cases where PouchDB expects a callback, this library returns a `$q` promise. 

Adding a document is as simple as:

```javascript
db.put({_id: 'foo', name: 'bar'});
```

But if you want to handle the results returned by PouchDB, you need to do something with the promise returned.
    
```javascript
db.put({_id: 'foo', name: 'bar'}).then(function(response) {
        // Do something with the response
    }).catch(function(error) {
        // Do something with the error
    }).finally(function() {
        // Do something when everything is done
    });
```
 
### Angular promises vs. PouchDB promises

Version 2.0.0 of PouchDB introduced its own promises. Angular promises are not the same thing though. Future versions of this library might make some adjustments to the way PouchDB's 
promises are wrapped as `$q` promises.

### Injecting a database as a dependency

There might be times where you have multiple services using *the same* database. In those cases, it might be a good idea to create your database as a service. Once you've created it like that, you can *inject* your database into all other services. (And make sure it always uses that single database only.)
    
```javascript
angular.factory('testdb', function(pouchdb) {
    return pouchdb.create('testdb');
});
    
angular.factory('testservice', function(testdb) {
    return {
        add: function(obj) { testdb.put(obj); }
    };
});
```
    
### ng-repeat for PouchDB

To traverse and display all elements in a database (assuming that database is exposed as testdb on the `$scope` object):

```html
    <ul>
      <li pouch-repeat="item in testdb">
        {{item.name}}
      </li>
    </ul>
```

To traverse and display all elements in a database, and sort based on some fields

```html
    <ul>
      <li pouch-repeat="person in persons order by name.first,name.last">
        {{item.name}}
      </li>
    </ul>
```

Now, this version of the library doesn't use any of the filtering or sorting built into PouchDB yet. Previous versions of PouchDB didn't have the flexibility to make that a smooth experience. The latest version of PouchDB actually might have that. Stay tuned for some changes in that area. 

Now the interesting thing about the current approach is that if changes are coming in from your remote database, this library will make sure they are getting inserted in the right position in your list. Or if you're making a change to an entry, if those changes affect its position in the sort order, it will be moved in place automatically. 

That's right. Nothing you need to do about that. And to make sure you can automatically highlight changes coming in, it uses `ngAnimate` to add and move and remove elements from the list. Add some CSS to the mix, and you will have incoming changes getting animated automatically.
    
    
