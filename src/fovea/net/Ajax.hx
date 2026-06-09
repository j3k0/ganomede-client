package fovea.net;

import openfl.utils.Object;
import fovea.async.Deferred;
import fovea.async.Promise;
import fovea.utils.NativeJSON;

#if flash

import fovea.net.IAjax;
import fovea.net.AjaxOpenFL;
import openfl.net.URLLoader;
import openfl.net.URLRequest;
import openfl.net.URLRequestHeader;
import openfl.net.URLRequestMethod;
import openfl.events.HTTPStatusEvent;
import openfl.events.EventDispatcher;
import openfl.events.IEventDispatcher;
import openfl.events.IOErrorEvent;
import openfl.events.SecurityErrorEvent;
import openfl.events.Event;
import fovea.events.Events;
import openfl.errors.Error;
import openfl.utils.Object;

class Ajax implements IAjax extends Events
{
    public static var verbose:Bool = false;
    public static var xAppVersionHeader:String = "";
    public static var xDeviceIdHeader:String = "";
    public static var dtrace = function(txt:String):Void {
        if (verbose)
            trace(txt);
    }
    public static function haxeTrace(txt:String):Void {
        trace(txt);
    }

    public static var implFactory = AjaxOpenFL.factory;
    public var impl:IAjax = null;
    public var url:String;

    public function new(url:String) {
        super();
        this.url = url;
        this.impl = implFactory(this);
    }

    public function beforeAjax(options:Object):Void {}
    public function afterAjax(options:Object, obj:Object):Void {}
    public function ajaxError(code:String, status:Int = 0, data:Object = null, url:String = null):AjaxError {
        return new AjaxError(code, status, data, url);
    }

    public function ajax(method:String, path:String, options:Object = null):Promise {
        var ret:Deferred = new Deferred();
        this.impl.ajax(method, path, options)
        .then(function(result:Object):Void {
            ret.resolve(result);
        })
        .error(function(error:Error):Void {
            var ajaxError:AjaxError = cast(error);
            if (ajaxError != null && (ajaxError.status == 504 || ajaxError.status == 503 || ajaxError.status == 502)) {
                dtrace("Request failed with status 503/504, retrying in 1s");
                haxe.Timer.delay(function():Void {
                    this.impl.ajax(method, path, options).then(ret.resolve).error(ret.reject);
                }, 1000);
            }
            else {
                ret.reject(error);
            }
        });
        return ret;
    }

    public static inline var ONLINE = "online";
    public static inline var OFFLINE = "offline";
    public static var onlineEvent = new Event(ONLINE);
    public static var offlineEvent = new Event(OFFLINE);
    public static var connection = new EventDispatcher();
    public static function when(status:String, fn:Event->Void):Void {
        connection.addEventListener(status, fn);
    }
    public static function stopListening(status:String, fn:Event->Void):Void {
        connection.removeEventListener(status, fn);
    }
}

#elseif js

import js.node.http.ClientRequest;
import js.node.Http.HttpClient;
import js.node.Http.HttpReqOpt;
import js.node.Http.HttpClientResp;
import js.node.Http;
import js.node.Https;
import fovea.events.Events;

//import lime.events.Event;
//import lime.events.EventDispatcher;

@:expose
class Ajax extends Events
{
    public static var verbose:Bool = false;
    public static var xAppVersionHeader:String = "";
    public static var xDeviceIdHeader:String = "";
    public static var dtrace = function(txt:String):Void {
        if (verbose)
            trace(txt);
    }
    public static function haxeTrace(txt:String):Void {
        trace(txt);
    }

    public var url:String;

    public var protocol:String;
    public var host:String;
    public var port:Int;
    public var path:String;

    public function new(url:String) {

        this.url = url;

        // extract protocol from the url
        this.protocol = url.split(":")[0];

        // extract path from the url
        this.path = "";
        var array = url.split("/");
        for (i in 3...array.length)
            this.path += "/" + array[i];

        // extract host and port
        var hostPort = url.split("/")[2];
        this.host = hostPort.split(":")[0];
        this.port = (this.protocol == "https" ? 443 : 80);
        if (this.host != hostPort) {
            this.port = Std.parseInt(hostPort.split(":")[1]);
        }
    }

    private function beforeAjax(options:Object):Void {}
    private function afterAjax(options:Object, obj:Object):Void {}
    private function ajaxError(code:String, status:Int = 0, data:Object = null, url:String = null):AjaxError {
        return new AjaxError(code, status, data, url);
    }

    public function reqUrl(reqOptions:HttpReqOpt):String {
        return reqOptions.method + " " + reqOptions.host + ":" + reqOptions.port + "/" + reqOptions.path;
    }

    public function prepareRequest(reqOptions:HttpReqOpt, callback:HttpClientResp->Void):ClientRequest {
        if (this.protocol == "https") {
            var reqsOptions:HttpsReqOpt = {
                host: reqOptions.host,
                port: reqOptions.port,
                path: reqOptions.path,
                method: reqOptions.method,
                headers: reqOptions.headers,
                ciphers: null,
                rejectUnauthorized: null
            };
            return Https.request(reqsOptions, callback);
        }
        else {
            return Http.request(reqOptions, callback);
        }
    }

    public function ajax(method:String, path:String, options:Object = null):Promise {

        if (options == null)
            options = {};
        options.method = method;
        options.path = path;

        var deferred:Deferred = new Deferred();

        var requestID:String = options.requestID != null
            ? options.requestID
            : StringTools.hex(Math.floor(Math.random() * 0xffff));
        options.requestID = requestID;
        dtrace("AJAX[" + requestID + "] " + method + " " + this.url + path);

        beforeAjax(options);

        var data = "";
        if (options.data) {
            data = NativeJSON.stringify(options.data);
        }

        var reqOptions:HttpReqOpt = {
            host: this.host,
            port: this.port,
            path: this.path + (path.charAt(0) != "/" ? "/" : "") + path,
            method: method,
            headers: {
                "X-App-Version": Ajax.xAppVersionHeader,
                "X-Device-Id": Ajax.xDeviceIdHeader,
                "Content-type": "application/json",
                'Content-Length': data.length
            }
        };
        // dtrace("AJAX[" + requestID + "] X-App-Version: " + Ajax.xAppVersionHeader);
        var req = prepareRequest(reqOptions, function(res:HttpClientResp):Void {
        /* var reqOptions:HttpReqOpt = {
            host: this.host,
            port: this.port,
            path: this.path + "/" + path,
            method: method,
            headers: {
                "Content-type": "application/json",
                'Content-Length': data.length
            }
        };

        // Prepare the request
        var req = Http.request(reqOptions, function(res:HttpClientResp):Void { */
            var status = res.statusCode;
            var data = "";
            res.on("data", function(chunk:String):Void {
                data += chunk;
            });
            res.on("end", function():Void {
                dtrace("AJAX[" + requestID + "] processing request");
                if (status >= 200 && status <= 299) {
                    var json:Dynamic = null;
                    try {
                        if (data != "")
                            json = cast(NativeJSON.parse(data));
                    }
                    catch (err:Dynamic) {
                        dtrace("[AJAX " + options.requestID + "] JSON parse error (" + data + ")");
                        if (err.stack)
                            dtrace("[AJAX " + options.requestID + "] " + err.stack);
                        else
                            dtrace("[AJAX " + options.requestID + "] " + err);
                        deferred.reject(ajaxError(AjaxError.IO_ERROR, AjaxError.IO_ERROR_JSON, data, reqUrl(reqOptions)));
                        return;
                    }
                    var obj:Object = {
                        status: status,
                        data: json
                    };
                    dtrace("AJAX[" + options.requestID + "] done[" + status + "]: " + data);
                    afterAjax(options, obj);
                    deferred.resolve(obj);
                    return;
                }
                deferred.reject(ajaxError(AjaxError.HTTP_ERROR, status, data, reqUrl(reqOptions)));
            });
        });

        req.on("error", function(error:Dynamic):Void {
            deferred.reject(ajaxError(AjaxError.IO_ERROR, 0, error.message, reqUrl(reqOptions)));
        });

        if (options.data) {
            req.write(data);
            dtrace("AJAX[" + requestID + "] data=" + data);
        }
        req.end();

        return deferred;
    }
}

#end

// vim: sw=4:ts=4:et:
