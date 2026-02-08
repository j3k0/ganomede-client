package test;

using js.npm.express.Session;

class ExpressTest {
	static function main(){
		var PORT = 9000;
		var app = new js.npm.Express();
		var secret = 'mySecret';
		app.use( new js.npm.express.CookieParser( secret ) );
		app.use( new Session({ secret : secret }) );
		app.all('/', function(req,res, next){
			var session = req.session();
			if( session.n == null ){
				session.n = 1;
			}
			res.send("HELLO " + session.n++ );
		});
		app.use( new js.npm.express.Static('.') );
		
		trace('listening to $PORT');
		app.listen(PORT);
	}
}