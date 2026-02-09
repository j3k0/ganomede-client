HAXE_MAIN=fovea.ganomede.Ganomede

help:
	@echo make run ..... Runs the app
	@echo make build ... Compiles the app
	@echo make clean ... Cleanup binaries
	@echo
	@echo make js ...... Build js library
	@echo make as3 ..... Build as3 source code
	@echo make swc ...... Build swc library

bin/ganomede.swc:
	@mkdir -p bin
	./haxe -swf bin/ganomede.swc -dce no -D no-swf-compress -lib openfl -cp src ${HAXE_MAIN}

bin/ganomede-as3:
	@mkdir -p bin
	./haxe -as3 bin/ganomede-as3 -dce no -lib openfl -cp src ${HAXE_MAIN}

swc:
	@mkdir -p bin
	./haxe -swf bin/ganomede.swc -dce no -D no-swf-compress -lib openfl -cp src ${HAXE_MAIN}

as3:
	@mkdir -p bin
	./haxe -as3 bin/ganomede-as3 -dce no -lib openfl -cp src ${HAXE_MAIN}

js:
	@mkdir -p bin
	@#./haxe -js bin/ganomede.js -dce no -lib openfl -cp lib/js-kit -cp src ${HAXE_MAIN}
	./haxe -js bin/ganomede.js -lib openfl -cp lib/js-kit -cp src ${HAXE_MAIN}

ajaxweb: bin/ajaxweb.js

bin/ajaxweb.js:
	@mkdir -p bin
	npm install
	./haxe -js bin/ajax.js -lib openfl -cp lib/js-kit -cp src fovea.net.Ajax
	./node_modules/.bin/browserify src-js/ajaxweb.js > bin/ajaxweb.js
	./node_modules/.bin/uglifyjs bin/ajaxweb.js > bin/ajaxweb.min.js

build: swc
	@mkdir -p bin
	./amxmlc -output bin/Main.swf src-as3/Main.as -compiler.source-path src-as3/ -compiler.library-path bin/ganomede.swc

run: build
	./adl src/Main-app.xml bin

clean:
	rm -fr bin
