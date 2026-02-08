package js.npm.connect;

typedef Encoding=String;

typedef OptionsBase = {
	@:optional var inflate :Bool;
	@:optional var limit :String;
	@:optional var type :Dynamic;
	@:optional var verify :js.node.http.ClientRequest->js.node.http.ServerResponse->js.node.Buffer->Encoding->Void;
}

typedef JsonOptions = { > OptionsBase,
	@:optional var reviver :Dynamic;
	@:optional var strict :Bool;
}

typedef RawOptions = OptionsBase;

typedef TextOptions = { > OptionsBase,
	@:optional var defaultCharset :String;
}

typedef UrlEncodedOptions = { > OptionsBase,
	@:optional var extended :Bool;
	@:optional var parameterLimit :Int;
}

extern class BodyParser
implements npm.Package.Require<"body-parser","~1.12.0"> #if !haxe3,#end
implements js.npm.connect.Middleware {

	public inline static function body( req : js.node.http.ClientRequest ) : Dynamic {
		return untyped req.body;
	}

	public static function json(?options :JsonOptions) : js.npm.connect.Middleware;
	public static function raw(?options :RawOptions) : js.npm.connect.Middleware;
	public static function urlencoded(?options :UrlEncodedOptions) : js.npm.connect.Middleware;
	public static function text(?options :TextOptions) : js.npm.connect.Middleware;
}