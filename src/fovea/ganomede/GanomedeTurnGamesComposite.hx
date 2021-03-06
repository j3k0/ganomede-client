package fovea.ganomede;

import fovea.async.*;
import fovea.ganomede.models.GanomedeTurnGame;
import fovea.ganomede.models.GanomedeTurnMove;
import fovea.events.Event;
import fovea.events.Events;
import fovea.net.AjaxError;
import haxe.ds.StringMap;
import openfl.errors.Error;
import openfl.utils.Object;

@:expose
class GanomedeTurnGamesComposite extends Events
{
    private var pool:GanomedeClientsPool;
    private var client:GanomedeClient;

    private var idMap = new StringMap<Int>();

    public function new(client:GanomedeClient, pool:GanomedeClientsPool) {
#if flash
        super();
#end
        this.pool = pool;
        this.client = client;
    }

    public function add(turngame:GanomedeTurnGame):Promise {
        var deferred:Deferred = new Deferred();
        prepareClient(turngame)
        .then(function clientPrepared(result:Dynamic):Void {
            var client:GanomedeClient = cast result.client;
            if (client == null || client.turngames == null) {
                deferred.reject(new ApiError(AjaxError.CLIENT_ERROR, 400));
                return;
            }
            client.turngames.add(turngame)
            .then(deferred.resolve)
            .error(deferred.reject);
        })
        .error(deferred.reject);
        return deferred;
    }

    private var listenedToMap = new StringMap<Bool>();
    private function listenToClient(id:Int, client:GanomedeClient):Void {
        if (listenedToMap.exists('' + id)) {
            return;
        }
        listenedToMap.set('' + id, true);
        if (client.notifications != null) {
            client.notifications.listenTo("turngame/v1", function turngameNotification(e:Event):Void {
                var event:GanomedeNotificationEvent = cast e;
                // refresh the updated game
                if (event.notification.type == "move") {
                    var gameJson:Object = event.notification.data.game;
                    var game:GanomedeTurnGame = get(gameJson.id);
                    if (game != null) {
                        game.fromJSON(gameJson);
                        dispatchEvent(new GanomedeTurnGameEvent(game));
                    }
                }
            });
        }
    }

    private function prepareClient(game:GanomedeTurnGame):Promise {
        var deferred:Deferred = new Deferred();
        pool.initializeClient(game.url, {
            turngames: { enabled: true },
            users: { enabled: true },
            notifications: { enabled: true}
        })
        .then(function clientInitialized(result:Dynamic):Void {
            var client:GanomedeClient = cast result.client;
            if (client == null) {
                deferred.reject(new ApiError(AjaxError.CLIENT_ERROR, 400));
                return;
            }
            listenToClient(result.id, client);
            if (!client.users.me.isAuthenticated()) {
                client.users.login(new GanomedeUser({
                    username: this.client.users.me.username,
                    password: this.client.users.me.password
                }))
                .then(function userLoggedIn(outcome:Dynamic):Void {
                    idMap.set(game.id, result.id);
                    deferred.resolve(result);
                })
                .error(deferred.reject);
            }
            else {
                deferred.resolve(result);
            }
        })
        .error(deferred.reject);
        return deferred;
    }

    public function get(id:String):GanomedeTurnGame {
        if (idMap.exists(id)) {
            var client = pool.getClient(idMap.get(id));
            return client.turngames.get(id);
        }
        else {
            return null;
        }
    }

    public function refresh(turngame:GanomedeTurnGame):Promise {
        if (idMap.exists(turngame.id)) {
            var client = pool.getClient(idMap.get(turngame.id));
            return client.turngames.refresh(turngame);
        }

        var deferred:Deferred = new Deferred();

        if (turngame.url != null) {
            prepareClient(turngame)
            .then(function clientPrepared(result:Dynamic):Void {
                var client:GanomedeClient = cast result.client;
                client.turngames.refresh(turngame)
                .then(function turngamesRefreshed(outcome:Dynamic):Void {
                    idMap.set(turngame.id, result.id);
                    deferred.resolve(result);
                })
                .error(deferred.reject);
            })
            .error(deferred.reject);
        }
        else {
            deferred.reject(new ApiError(AjaxError.HTTP_ERROR, 400));
        }

        return deferred;
    }

    public function addMove(turngame:GanomedeTurnGame, turnmove:GanomedeTurnMove):Promise {
        var deferred:Deferred = new Deferred();
        prepareClient(turngame)
        .then(function clientPrepared(result:Dynamic):Void {
            var client:GanomedeClient = cast result.client;
            client.turngames.addMove(turngame, turnmove)
            .then(deferred.resolve)
            .error(deferred.reject);
        })
        .error(deferred.reject);
        return deferred;
    }

    public function refreshArray(array:Array<GanomedeTurnGame>, on404:GanomedeTurnGame->Error->Void = null):Promise {
        return Parallel.runWithArgs(array, function(turngame:GanomedeTurnGame):Promise {
            var deferred = new Deferred();
            refresh(turngame)
            .always(function():Void { deferred.resolve(null); })
            .error(function(error:Error):Void {
                if (on404 != null)
                    on404(turngame, error);
            });
            return deferred;
        });
    }
}
