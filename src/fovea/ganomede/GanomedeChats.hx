package fovea.ganomede;

import fovea.async.Promise;
import fovea.events.Event;
import fovea.events.Events;
import fovea.ganomede.models.GanomedeChatMessage;
import fovea.ganomede.models.GanomedeChatRoom;
import fovea.net.Ajax;
import fovea.net.AjaxError;
import fovea.utils.Collection;
import fovea.utils.Model;
import openfl.utils.Object;

@:expose
class GanomedeChats extends UserClient
{
    public var collection(default,never) = new Collection();
    public function asArray():Array<GanomedeChatRoom> {
        var array = collection.asArray();
        // order chatrooms by id
        array.sort(function arrayComparator(a:Model, b:Model):Int {
            var as = cast(a, GanomedeChatRoom).id;
            var bs = cast(b, GanomedeChatRoom).id;
            if (as < bs) return -1;
            if (as > bs) return 1;
            return 0;
        });
        return cast array;
    }
    public function toJSON():Object {
        return collection.toJSON();
    }

    public function new(client:GanomedeClient) {
        super(client, chatClientFactory, GanomedeChatClient.TYPE);
        collection.modelFactory = function modelFactory(json:Object):GanomedeChatRoom {
            return new GanomedeChatRoom(json);
        };
        addEventListener("reset", onReset);
        collection.addEventListener(Events.CHANGE, dispatchEvent);
        if (client.notifications != null) {
            client.notifications.listenTo("chat/v1", onChat);
        }
    }

    private function onChat(event:Event):Void {
        var e:GanomedeNotificationEvent = cast event;
        var data = e.notification.data;
        if (data != null && data.roomId != null) {
            var room:GanomedeChatRoom = cast collection.get(data.roomId);
            var msg:Object = {
                timestamp: data.timestamp,
                from: data.from,
                type: data.type,
                message: data.message
            };
            if (room == null) {
                room = new GanomedeChatRoom({
                    id: data.roomId,
                    type: data.roomId.split("/").slice(0,2).join("/"),
                    users: [ client.users.me.username, data.from ],
                    messages: []
                });
            }
            room.messages.unshift(new GanomedeChatMessage(msg));
            dispatchEvent(new GanomedeChatEvent(room));
        }
    }

    public function chatClientFactory(url:String, token:String):AuthenticatedClient {
        return new GanomedeChatClient(url, token);
    }

    private function onReset(event:Event):Void {
        collection.flushall();
        // refreshArray();
    }

    public function join(room:GanomedeChatRoom):Promise {
        if (!client.users.me.isAuthenticated()) {
            if (Ajax.verbose) Ajax.dtrace("cant join chat room: not authenticated");
            return error(AjaxError.CLIENT_ERROR);
        }
        if (room.type == null) {
            if (Ajax.verbose) Ajax.dtrace("cant join chat room: missing type");
            return error(AjaxError.CLIENT_ERROR);
        }
        if (room.users == null || room.users.length == 0) {
            if (Ajax.verbose) Ajax.dtrace("cant join chat room: no users");
            return error(AjaxError.CLIENT_ERROR);
        }

        return executeAuth(function joinRoomFn():Promise {
            var chatClient:GanomedeChatClient = cast authClient;
            return chatClient.joinRoom(room);
        })
        .then(function roomJoined(outcome:Dynamic):Void {
            collection.merge(room.toJSON());
        });
    }

    public function postMessage(room:GanomedeChatRoom, message:GanomedeChatMessage):Promise {
        room.messages.unshift(message);
        return executeAuth(function postMessageFn():Promise {
            var chatClient:GanomedeChatClient= cast authClient;
            return chatClient.postMessage(room, message);
        });
        //.then(function messagePosted(outcome:Dynamic):Void {
        //});
    }

    //public function refreshArray():Promise {
    //    return refreshCollection(collection, function arrayRefreshed():Promise {
    //        return cast(authClient, GanomedeInvitationsClient).listInvitations();
    //    });
    //}
}

// vim: sw=4:ts=4:et:

