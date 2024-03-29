package fovea.ganomede;

import fovea.async.*;
import fovea.ganomede.models.GanomedeGame;
import fovea.utils.Collection;
import fovea.utils.Model;
import openfl.utils.Object;
import fovea.net.Ajax;
import fovea.net.AjaxError;
import fovea.events.Event;
import fovea.events.Events;

@:expose
class GanomedeGames extends UserClient
{
    private var type:String;
    public var collection(default,never) = new Collection();
    public function asArray() {
        var array = collection.asArray();
        array.sort(function(a:Model, b:Model):Int {
            return (a.id > b.id) ? 1 : -1;
        });
        return array;
    }
    public function toJSON():Object {
        return collection.toJSON();
    }

    public function new(client:GanomedeClient, type:String) {
        super(client, coordinatorClientFactory);
        collection.keepStrategy = function(game:Model):Bool {
            return cast(game,GanomedeGame).status == "active";
        };
        collection.modelFactory = function(json:Object):Model {
            return new GanomedeGame(json);
        };
        this.type = type;
        addEventListener("reset", onReset);
        collection.addEventListener(Events.CHANGE, dispatchEvent);
    }

    private function coordinatorClientFactory(url:String, token:String):AuthenticatedClient {
        return new GanomedeCoordinatorClient(url, token);
    }

    public function onReset(event:Event):Void {
        if (Ajax.verbose) Ajax.dtrace("reset!");
        collection.flushall();
        refreshArray();
    }

    public function add(game:GanomedeGame):Promise {
        if (!client.users.me.isAuthenticated()) {
            if (Ajax.verbose) Ajax.dtrace("cant add game: not authenticated");
            return error(AjaxError.CLIENT_ERROR);
        }

        return executeAuth(function():Promise {
            return cast(authClient, GanomedeCoordinatorClient).addGame(game);
        })
        .then(function(outcome:Dynamic):Void {
            collection.merge(game.toJSON());
        });
    }

    public function join(game:GanomedeGame):Promise {
        return executeAuth(function():Promise {
            return cast(authClient, GanomedeCoordinatorClient).joinGame(game);
        })
        .then(function(outcome:Dynamic):Void {
            collection.merge(game.toJSON());
        });
    }

    public function leave(game:GanomedeGame):Promise {
        return executeAuth(function():Promise {
            return cast(authClient, GanomedeCoordinatorClient).leaveGame(game);
        })
        .then(function(outcome:Dynamic):Void {
            collection.merge(game.toJSON());
        });
    }

    public function gameover(game:GanomedeGame, gameOverData:Object):Promise {
        return executeAuth(function():Promise {
            return cast(authClient, GanomedeCoordinatorClient).gameover(game, gameOverData);
        })
        .then(function(outcome:Dynamic):Void {
            collection.merge(game.toJSON());
        });
    }

    public function refreshArray():Promise {
        return refreshCollection(collection, function():Promise {
            return cast(authClient, GanomedeCoordinatorClient).activeGames(type)
            .then(function(outcome:Object):Void {
                if (outcome == null) return;
                if (outcome.data == null) return;
                var array:Array<Object> = cast(outcome.data, Array<Object>);
                if (array != null) for (i in 0...array.length) {
                    array[i].status = 'active';
                }
            });
        });
    }
}

// vim: sw=4:ts=4:et:
