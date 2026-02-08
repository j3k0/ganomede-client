# A Javascript Toolkit for Haxe

A collection of externs and tools to quickly get started with [Haxe](http://www.haxe.org)/JS, including [Node.js](http://nodejs.org)

**Warning : This is a work in progress and is definitely not stable nor complete !**

## Installation

Using haxelib :
```
haxelib git js-kit https://github.com/clemos/haxe-js-kit.git haxelib
```
Or you can just download / clone the repo manually, and add the folder to your project's classpath

## Features

### Type signatures

The library contains type signatures for :

* **The core [node.js API](http://nodejs.org/api/)**
* **Common NPM libraries** such as :
	* **[Mongoose](http://mongoosejs.com/) elegant mongodb object modeling** with optional strict-typing and support for typedef to schema modeling [[example](https://github.com/clemos/haxe-js-kit/blob/master/test/MongooseTest.hx)]
	* **[Connect.js](http://www.senchalabs.org/connect/) middleware framework**
	* **[Express.js](http://expressjs.com/) web application framework**
	* **[Socket.io](http://socket.io/) cross-browser websockets for realtime apps**
	* **[Passport.js](http://passportjs.org/) simple, unobtrusive authentication**
	* **[Atom-shell](https://github.com/atom/atom-shell) cross-platform desktop application shell**
	* and more to come ;)
* **Some major client-side libraries** : up-to-date JQuery externs, socket.io client, etc

### NPM integration

The library provides an easy way to manage [NPM](https://npmjs.org/) dependencies: 

Basically, the NPM packages that correspond to the libraries used by your project will be automatically `require`d at compile-time.

#### Exporting your project dependencies

All NPM packages included this way can also be automatically exported by the Haxe compiler, typically to a ``package.json`` file, 
so they can be automatically installed using ``npm install``

You just add to add this flag to your ``build.hxml`` script :
```
--macro npm.Package.export("package.json")
```

Note that the macro will parse the package file, 
add dependencies to it, 
and then rewrite the whole json file.

**This means that it may change formatting.**

The process is incremental, though, which means that :

* other dependencies you may have added manually will be kept.
* unused dependencies will remain unless you remove them manually

Please also note that the dependency system currently doesn't manage package versions / SemVer.

#### Asynchronous programming (experimental)

Implementing `util.Async` allows to write typical asynchronous code in a "flat" way using the `@async` inline metadata.

This is very useful, avoiding superfluous indentations and braces / parenthesis mess 
in the context of linear, "single threaded" scripts...

For instance :

```haxe
class Exemple implements util.Async {
  static function main(){
     var err,doc = @async model.create({ /*...*/ });
     if( err != null ){
        trace("error",err);  
     }else{
        trace("created doc",doc);
     }
  }
}
```

is the equivalent of:

```haxe
class Exemple {
  static function main(){
     model.create({ /* ... */ }, function(err,doc){
     	if( err != null ){
           trace("error",err);  
        }else{
           trace("created doc",doc);
        }
     });
  }
}
```

See the (small) [mongoose example](https://github.com/clemos/haxe-js-kit/blob/master/test/Mongoose.hx) for a more practical and complete sample.

You can also scope the Async macro only to some block by using `util.Async.run({ \* flat code block / @async *\ })`.

## Contributing

We try to keep the externs as close as possible to their native APIs, 
while sticking as much as possible to the Haxe type / package system.

This means :
* **Splitting the APIs in modules** so the structure is as close as possible to the native API docs.
  This should also allow most code examples to look as similar as possible in JS and in Haxe.
* **Using extern classes rather than typedefs** when possible 
  (typedefs should be used only for simple JS key/value objects such as option objects)
* **Using packages rather than static variables** when possible 
  (``new js.npm.connect.CookieParser()`` rather than ``js.npm.Connect.cookieParser()``)
* Assuming that in most cases, instantiation using simple JS calls (like ``var app = express()``) 
  is similar to using ``new`` in Haxe (like ``var app = new Express()``)

### Including NPM packages

You can map your extern classes to an NPM package by implementing `npm.Package.Require` or `npm.Package.RequireNamespace`.

For example :
```haxe
// js/npm/MyPackage.hx
package js.npm;
extern class MyPackage
implements npm.Package.Require<"my-package","*">
```
```js
// Test.hx
var test = new js.npm.MyPackage();
```
```js
// resulting Javascript output:
var js_npm_MyPackage = require('my-package');
var test = new js_npm_MyPackage();
```

Sometimes, a single ``require`` exports several objects that can be considered individual classes in Haxe.

In such cases you can use ``RequireNamespace``:
```haxe
// js/node/http/Server.hx
package js.node.http;
extern class Server
implements npm.Package.RequireNamespace<"http","*">
```
```js
// resulting Javascript output:
var js_node_http_Server = require('http').Server;
```

The `@:native` metadata is supported with `RequireNamespace`


## Todo

* Continue integrating / cleaning / completing externs, mainly from [nodejs_externs](https://github.com/dionjwa/nodejs_externs)
* Complete the node API
* RequireJS & Bower integration (WIP)
* Improve NPM integration (SemVer, less intrusive dependency export)
* Publish to haxelib
