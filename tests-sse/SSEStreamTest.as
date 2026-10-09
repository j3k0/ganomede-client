package
{
    import flash.display.MovieClip;
    import flash.display.Sprite;
    import flash.desktop.NativeApplication;
    import flash.net.URLLoader;
    import flash.net.URLRequest;
    import flash.utils.setTimeout;
    import fovea.net.EventSourceStream;

    // Drives EventSourceStream against tests-sse/server.js. Results are posted to /log.
    public class SSEStreamTest extends Sprite
    {
        private static const BASE:String = "http://127.0.0.1:18765";
        private var queue:Array = [];

        public function SSEStreamTest() {
            haxe.initSwc(new MovieClip());
            EventSourceStream.WATCHDOG_MS = 2000;
            queue = [
                ["s1", 6000], ["404", 3000], ["html", 3000], ["hang", 12000], ["503", 8000]
            ];
            next();
        }

        private function log(m:String):void {
            new URLLoader().load(new URLRequest(BASE + "/log?m=" + encodeURIComponent(m)));
        }

        private function next():void {
            if (queue.length == 0) {
                log("END");
                setTimeout(function():void { NativeApplication.nativeApplication.exit(0); }, 500);
                return;
            }
            var item:Array = queue.shift();
            var name:String = item[0];
            var lastId:String = null;
            var stream:EventSourceStream = new EventSourceStream(BASE + "/" + name,
                function():String { return lastId; },
                function(type:String, id:String, data:String):void {
                    if (id != null) lastId = id;
                    log("msg|" + type + "|" + id + "|" + data);
                },
                function(reason:String):void {
                    log("fail|" + name + "|" + reason);
                });
            stream.start();
            setTimeout(function():void { stream.stop(); next(); }, item[1]);
        }
    }
}
