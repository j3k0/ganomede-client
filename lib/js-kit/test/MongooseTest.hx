package test;

import js.npm.mongoose.macro.Model;
import js.npm.Mongoose.mongoose;

typedef StuffData = {
	test : String,
	foo : Int,
	?bar : {
		hello : String,
		world : Array<Dynamic>
	}
}

// declare the model
// the typedef fields will be "copied" to Stuff instance
@:schemaOptions({
    autoIndex: true
})
class Stuff extends Model<StuffData>{}
class StuffManager extends js.npm.mongoose.macro.Manager<StuffData,Stuff>{}

class MongooseTest implements util.Async {

	static function main(){
		// connect
		var db = mongoose.connect("mongodb://localhost/test_mongoose");

		// build the model
		var stuff = StuffManager.build(db,"Stuff");

		// will expand to `new stuff({...})`
		var something = stuff.construct({test:"hello",foo:1});

		// use the model
		trace("running test");
		var err = @async stuff.remove({});

		trace("cleared DB");
		var d = {
			test : "test",
			foo : 1
		};

		var err,doc = @async stuff.create( d );

		trace("foo", doc.foo);
		trace("test",doc.test);

	}

}
