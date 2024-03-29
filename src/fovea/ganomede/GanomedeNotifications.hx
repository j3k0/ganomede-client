package fovea.ganomede;

import fovea.async.*;
import fovea.ganomede.models.GanomedePushToken;
import fovea.events.Event;
import fovea.net.Ajax;
import fovea.net.AjaxError;
import fovea.utils.Collection;
import fovea.utils.NativeJSON;
import openfl.errors.Error;
import openfl.utils.Object;

@:expose
class GanomedeNotifications extends UserClient
{
    public function new(client:GanomedeClient) {
        super(client, notificationsClientFactory, GanomedeNotificationsClient.TYPE);
        addEventListener("change:initialize", onInitialize);
        addEventListener("reset", onReset);
    }

    private var keepPolling:Bool = true;
    public function stopPolling():Void {
        this.keepPolling = false;
    }
    public function startPolling():Void {
        this.keepPolling = true;
    }

    public function notificationsClientFactory(url:String, token:String):AuthenticatedClient {
        return new GanomedeNotificationsClient(url, token);
    }

    public function listenTo(emiter:String, callback:Event->Void):Void {
        this.on(emiter, callback);
    }

    private var lastId:Int = -1;
    private function onPollSuccess(result:Object):Void {
        try {
            // result.state;
            var notifClient:GanomedeNotificationsClient = cast authClient;
            var notifications:Array<Object> = cast(result.data, Array<Object>);
            if (Ajax.verbose) Ajax.dtrace("[GanomedeNotifications] results for " + result.token);
            if (notifications == null || result.token != notifClient.token || result.clientId != notifClient.clientId) {
                if (Ajax.verbose && notifications != null )
                    Ajax.dtrace("skip");
                haxe.Timer.delay(poll, 100);
                return;
            }
            for (i in 0...notifications.length) {
                var n:GanomedeNotification = notifications[notifications.length - i - 1];
                if (n.id > lastId)
                    lastId = n.id;
                if (!result.silent)
                    dispatchNotification(n);
            }
        }
        catch (error:String) {
            if (Ajax.verbose) Ajax.dtrace("[GanomedeNotifications] ERROR " + error);
        }
        haxe.Timer.delay(poll, 100);
    }
    private function onPollError(error:Error):Void {
        haxe.Timer.delay(poll, 1000);
    }
    public function poll():Void {
        if (!keepPolling) {
            haxe.Timer.delay(poll, 1000);
            return;
        }
        var notifClient:GanomedeNotificationsClient = cast authClient;
        if (!notifClient.polling) {
            if (Ajax.verbose) Ajax.dtrace("[GanomedeNotifications] poll");
            executeAuth(function():Promise {
                return notifClient.poll(lastId);
            })
            .then(onPollSuccess)
            .error(onPollError);
        }
    }
    public function silentPoll():Void {
        var notifClient:GanomedeNotificationsClient = cast authClient;
        if (isAuthOK()) {
            executeAuth(function():Promise {
                return notifClient.poll(-2);
            })
            .then(function(result:Object) {
                result.silent = true;
                onPollSuccess(result);
            })
            .error(function(err:Error):Void {
                haxe.Timer.delay(silentPoll, 1000);
            });
        }
        else {
            haxe.Timer.delay(silentPoll, 1000);
        }
    }

    private function onInitialize(event:Event):Void {
        silentPoll();
        // in case polling stops working...
        var timer = new haxe.Timer(60000);
        timer.run = poll;
    }

    private function onReset(event:Event):Void {
        lastId = -1;
        silentPoll();
    }

    private function dispatchNotification(n:GanomedeNotification):Void {
        if (Ajax.verbose) Ajax.dtrace("[GanomedeNotifications] notification: " + NativeJSON.stringify(n.toJSON()));
        dispatchEvent(new GanomedeNotificationEvent(n));
    }

    public var apiSecret:String = "";
    public function send(n:GanomedeNotification):Promise {
        var data:Object = n.toJSON();
        data.secret = apiSecret;
        return ajax("POST", "/messages", {
            data: data
        });
    }

    public var online:Array<String> = [];
    public function refreshOnline(tag:String):Promise {
        if (Ajax.verbose) Ajax.dtrace("[GanomedeNotifications] refreshOnline(" + tag + ")");

        var method = "GET";
        var endpoint = "/online";
        if (tag != null) {
            endpoint = endpoint + "/" + tag;
        }
        
        // Removing support for notification < 1.1.0
        // POST /auth/token/online supported since service version 1.1.0
        // var service = client.registry.getService("notifications", 1);
        // var postSupported = (service != null && service.versionGE(1,1,0));

       var postSupported = true;

        if (client.users.me != null && postSupported) {
            var token = client.users.me.token;
            if (token != null) {
                method = "POST";
                endpoint = "/auth/" + token + "/online";
                if (tag != null) {
                    endpoint = endpoint + "/" + tag;
                }
            }
        }
        return ajax(method, endpoint)
        .then(function(outcome:Object):Void {
            if (Ajax.verbose) Ajax.dtrace("[GanomedeNotifications] online.then(): " + NativeJSON.stringify(outcome));
            online = outcome.data;
        });
    }

    public function lastSeen(usernames: Array<String>): Promise {
        if (Ajax.verbose) Ajax.dtrace("[GanomedeNotifications] lastSeen(" + NativeJSON.stringify(usernames) + ")");
        return ajax("GET", "/lastseen/" + usernames.join(","))
        .then(function(outcome:Object):Void {
            if (Ajax.verbose) Ajax.dtrace("[GanomedeNotifications] lastSeen.then(): " + NativeJSON.stringify(outcome));
        });
    }

    public function savePushToken(pushToken:GanomedePushToken):Promise {
        if (client.users.me != null) {
            var token = client.users.me.token;
            var endpoint = "/auth/" + token + "/push-token";
            return ajax("POST", endpoint, {
                data: pushToken.toJSON()
            });
        }
        else {
            return new Deferred().reject(new Error("Not authenticated"));
        }
    }
}
// vim: sw=4:ts=4:et:
