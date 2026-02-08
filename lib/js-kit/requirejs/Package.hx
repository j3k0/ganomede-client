package requirejs;

import haxe.ds.StringMap;

#if macro
import haxe.Json;
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Expr.Field;
import sys.io.File;
#end

#if !macro extern #end class Include {

	public static var mapping : StringMap<String>;
	static var requireId;

	static inline var USAGE = "Usage: 'implements requirejs.Require<\"module-name\",\"module-version\">'";
	static inline var REQUIREJS_REQUIRE = "requirejs.Package.Require";
	static inline var REQUIREJS_DEFINE = "requirejs";

	#if haxe3 macro #else @:macro #end public static function build() : Array<Field>{
		var fields = Context.getBuildFields();
		
		if( !Context.defined(REQUIREJS_DEFINE) ){
			return fields;
		}
		if( mapping == null ){
			requireId = 0;
			mapping = new StringMap();
		}

		var required : String = null;
		var cl = Context.getLocalClass().get();
		var requireNS = false;
		var pos = Context.currentPos();
		
		trace('building',cl);

		var requireParams = util.Macro.extractStringParams( cl , REQUIREJS_REQUIRE );
		if( requireParams.length == 0 ){
			throw USAGE;
		}

		var required = requireParams[0][0];
		if( required == null ){
			throw USAGE;
		}

		var native = cl.name + '__' + requireId++;
		cl.meta.add(":native",[macro $v{native}], pos);

		mapping.set( required , native );

		trace('import', required);

		return fields;
	}
}

@:autoBuild( requirejs.Include.build() )
extern interface Require<Const,Const> {}
