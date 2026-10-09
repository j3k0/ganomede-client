package fovea.net;

#if flash

import flash.events.Event;
import flash.events.HTTPStatusEvent;
import flash.events.IOErrorEvent;
import flash.events.ProgressEvent;
import flash.events.SecurityErrorEvent;
import flash.net.URLRequest;
import flash.net.URLRequestHeader;
import flash.net.URLStream;
import flash.utils.ByteArray;

/**
 * Server-Sent Events reader over flash.net.URLStream.
 *
 * - Parses `event:`, `id:` and `data:` fields; comments (`:ping`) only feed the watchdog.
 * - Reconnects with capped exponential backoff and +/-25% jitter, sending `Last-Event-ID`.
 * - Dead-link watchdog: no bytes received for WATCHDOG_MS => close and reconnect.
 *   (Server heartbeats every 15s.) The platform backstop is the request's idleTimeout
 *   (IDLE_TIMEOUT_MS), set on the stream request only so other requests keep their default.
 * - Gives up (onFailure) on a non-retryable answer (4xx, wrong Content-Type) or after
 *   MAX_FAILURES_WITHOUT_DATA consecutive attempts that never produced a single SSE frame.
 *   The caller is expected to fall back to long-polling.
 */
class EventSourceStream
{
    public static var WATCHDOG_MS:Int = 40000;
    public static var IDLE_TIMEOUT_MS:Int = 80000;
    public static var BACKOFF_BASE_MS:Int = 1000;
    public static var BACKOFF_CAP_MS:Int = 30000;
    public static var MAX_FAILURES_WITHOUT_DATA:Int = 3;
    public static var MAX_BUFFER_BYTES:Int = 256 * 1024;

    public var url(default, null):String;

    /** Returns the Last-Event-ID to send on (re)connect, or null. */
    private var getLastEventId:Void->String;
    /** Called for each complete event: (eventType or null, id or null, data). */
    private var onMessage:String->String->String->Void;
    /** Called once when the stream gives up for good. */
    private var onFailure:String->Void;

    private var running:Bool = false;
    private var stream:URLStream = null;
    private var buffer:ByteArray = null;
    private var watchdog:haxe.Timer = null;
    private var retryTimer:haxe.Timer = null;
    private var gotFrame:Bool = false;     // this attempt produced at least one SSE frame
    private var failures:Int = 0;          // consecutive attempts without any frame
    private var backoffMs:Int;

    public function new(url:String, getLastEventId:Void->String,
                        onMessage:String->String->String->Void, onFailure:String->Void) {
        this.url = url;
        this.getLastEventId = getLastEventId;
        this.onMessage = onMessage;
        this.onFailure = onFailure;
        this.backoffMs = BACKOFF_BASE_MS;
    }

    public function start():Void {
        if (running) return;
        running = true;
        failures = 0;
        backoffMs = BACKOFF_BASE_MS;
        connect();
    }

    public function stop():Void {
        running = false;
        if (retryTimer != null) {
            retryTimer.stop();
            retryTimer = null;
        }
        closeStream();
    }

    private function log(msg:String):Void {
        if (Ajax.verbose) Ajax.dtrace("[EventSourceStream] " + msg);
    }

    private function connect():Void {
        retryTimer = null;
        if (!running) return;
        closeStream();
        buffer = new ByteArray();
        gotFrame = false;

        var request = new URLRequest(url);
        request.method = "GET";
        // URLRequest.idleTimeout is AIR-only (not in the Haxe externs).
        try { Reflect.setField(request, "idleTimeout", IDLE_TIMEOUT_MS); } catch (e:Dynamic) {}
        var headers:Array<URLRequestHeader> = [
            new URLRequestHeader("Accept", "text/event-stream"),
            new URLRequestHeader("X-App-Version", Ajax.xAppVersionHeader),
            new URLRequestHeader("X-Device-Id", Ajax.xDeviceIdHeader)
        ];
        var lastEventId = getLastEventId();
        if (lastEventId != null)
            headers.push(new URLRequestHeader("Last-Event-ID", lastEventId));
        request.requestHeaders = headers;

        stream = new URLStream();
        stream.addEventListener("httpResponseStatus", onResponseStatus);
        stream.addEventListener(HTTPStatusEvent.HTTP_STATUS, onResponseStatus);
        stream.addEventListener(ProgressEvent.PROGRESS, onProgress);
        stream.addEventListener(Event.COMPLETE, onClosed);
        stream.addEventListener(IOErrorEvent.IO_ERROR, onClosed);
        stream.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onClosed);
        armWatchdog();
        log("connect (Last-Event-ID: " + lastEventId + ")");
        try {
            stream.load(request);
        }
        catch (e:Dynamic) {
            log("load failed: " + e);
            reconnectLater();
        }
    }

    private function closeStream():Void {
        disarmWatchdog();
        if (stream == null) return;
        var s = stream;
        stream = null;
        s.removeEventListener("httpResponseStatus", onResponseStatus);
        s.removeEventListener(HTTPStatusEvent.HTTP_STATUS, onResponseStatus);
        s.removeEventListener(ProgressEvent.PROGRESS, onProgress);
        s.removeEventListener(Event.COMPLETE, onClosed);
        s.removeEventListener(IOErrorEvent.IO_ERROR, onClosed);
        s.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onClosed);
        try { s.close(); } catch (e:Dynamic) {}
    }

    private function fail(reason:String):Void {
        log("giving up: " + reason);
        stop();
        if (onFailure != null) onFailure(reason);
    }

    private function reconnectLater():Void {
        closeStream();
        if (!running) return;
        if (!gotFrame) {
            failures++;
            if (failures >= MAX_FAILURES_WITHOUT_DATA) {
                fail(failures + " attempts without data");
                return;
            }
        }
        var delay = Std.int(backoffMs * (0.75 + Math.random() * 0.5));
        backoffMs = Std.int(Math.min(backoffMs * 2, BACKOFF_CAP_MS));
        log("reconnect in " + delay + "ms");
        retryTimer = haxe.Timer.delay(connect, delay);
    }

    private function armWatchdog():Void {
        disarmWatchdog();
        watchdog = haxe.Timer.delay(onWatchdog, WATCHDOG_MS);
    }

    private function disarmWatchdog():Void {
        if (watchdog != null) {
            watchdog.stop();
            watchdog = null;
        }
    }

    private function onWatchdog():Void {
        watchdog = null;
        log("watchdog: no data for " + WATCHDOG_MS + "ms");
        reconnectLater();
    }

    private function onResponseStatus(event:HTTPStatusEvent):Void {
        if (event.target != stream) return;
        var status = event.status;
        if (status == 0) return; // unknown on this platform
        if (status >= 500) return; // transient: the stream will close and we retry with backoff
        if (status != 200) {
            fail("HTTP " + status);
            return;
        }
        var headers:Array<Dynamic> = Reflect.field(event, "responseHeaders");
        if (headers == null || headers.length == 0) return; // not exposed (HTTP_STATUS event)
        for (h in headers) {
            if (Std.string(h.name).toLowerCase() == "content-type") {
                if (Std.string(h.value).toLowerCase().indexOf("text/event-stream") != 0)
                    fail("Content-Type " + h.value);
                return;
            }
        }
        fail("no Content-Type");
    }

    private function onClosed(event:Event):Void {
        if (event.target != stream) return;
        log("closed: " + event.type);
        reconnectLater();
    }

    private function onProgress(event:ProgressEvent):Void {
        if (event.target != stream) return;
        armWatchdog();
        var available = stream.bytesAvailable;
        if (available > 0)
            stream.readBytes(buffer, buffer.length, available);
        processBuffer();
    }

    // Splits the buffer on blank lines (end of SSE frame). Works on bytes so a
    // multi-byte UTF-8 character split across two PROGRESS events stays intact.
    private function processBuffer():Void {
        var end = 0;
        var len:Int = buffer.length;
        var i = 1;
        while (i < len) {
            if (buffer[i] == 10 && (buffer[i - 1] == 10
                || (i >= 3 && buffer[i - 1] == 13 && buffer[i - 2] == 10 && buffer[i - 3] == 13))) {
                end = i + 1;
            }
            i++;
        }
        if (end == 0) {
            if (len > MAX_BUFFER_BYTES) {
                log("buffer overflow without frame boundary");
                reconnectLater();
            }
            return;
        }
        buffer.position = 0;
        var text = buffer.readUTFBytes(end);
        var rest = new ByteArray();
        if (len > end)
            rest.writeBytes(buffer, end, len - end);
        buffer = rest;

        text = StringTools.replace(text, "\r\n", "\n");
        for (frame in text.split("\n\n")) {
            if (!running) return; // a handler stopped us
            if (frame.length > 0)
                processFrame(frame);
        }
    }

    private function processFrame(frame:String):Void {
        if (!gotFrame) {
            gotFrame = true;
            failures = 0;
            backoffMs = BACKOFF_BASE_MS;
        }
        var eventType:String = null;
        var id:String = null;
        var data:String = null;
        for (line in frame.split("\n")) {
            if (line.length == 0 || line.charAt(0) == ":") continue; // comment / heartbeat
            var colon = line.indexOf(":");
            var field = colon < 0 ? line : line.substr(0, colon);
            var value = colon < 0 ? "" : line.substr(colon + 1);
            if (value.charAt(0) == " ") value = value.substr(1);
            switch (field) {
                case "event": eventType = value;
                case "id": id = value;
                case "data": data = (data == null) ? value : data + "\n" + value;
                default: // "retry" and unknown fields are ignored
            }
        }
        if (data == null) return; // heartbeat-only frame
        try {
            onMessage(eventType, id, data);
        }
        catch (e:Dynamic) {
            log("event handler error: " + e);
        }
    }
}

#end

// vim: sw=4:ts=4:et:
