package fovea.ganomede;

import fovea.async.*;
import fovea.events.Event;
import openfl.utils.Object;
import fovea.net.AjaxError;

@:expose
class GanomedeUsers extends ApiClient
{
    public static inline var TYPE:String = "users/v1";

    public var initialized(default,null):Bool = false;
    private var client:GanomedeClient = null;
    // current authenticated user
    public var me(default,null):GanomedeUser = new GanomedeUser();

    public function new(client:GanomedeClient) {
        super(client.url + "/" + TYPE);
        this.client = client;
    }

    public function initialize():Promise {
        var deferred:Deferred = new Deferred();
        deferred.resolve();
        return deferred.then(function(obj:Object):Void {
                initialized = true;
                if (me.isAuthenticated()) {
                    dispatchLoginEvent(null);
                }
            });
    }

    private function dispatchLoginEvent(result:Object):Void {
        dispatchEvent(new Event(GanomedeEvents.LOGIN));
    }

    public function signUp(user:GanomedeUser):Promise {
        me = user;
        return ajax("POST", "/accounts", {
            data: user.toJSON(),
            parse: parseMe
        })
        .then(dispatchLoginEvent);
    }

    public function login(user:GanomedeUser):Promise {
        me = user;
        return ajax("POST", "/login", {
            data: {
                username: user.username,
                password: user.password
            },
            parse: parseMe
        })
        .then(dispatchLoginEvent);
    }

    public function logout() {
        me = new GanomedeUser();
        dispatchEvent(new Event(GanomedeEvents.LOGOUT));
    }

    public function fetch(user:GanomedeUser):Promise {
        var deferred:Deferred = new Deferred();
        if ((user.username == me.username) ||
            (user.email == me.username) ||
            (user.username == me.email)) {
            ajax("GET", "/auth/" + me.token + "/me", {
                parse: parseMe
            })
            .then(function(outcome:Object):Void {
                deferred.resolve(user);
            })
            .error(deferred.reject);
        } 
        else {
            deferred.reject(new ApiError(AjaxError.IO_ERROR)); // TODO
        }

        return deferred;
    }

    private function parseMe(obj:Object):Object {
        me.fromJSON(obj);
        return me;
    }
}

// vim: sw=4:ts=4:et:
