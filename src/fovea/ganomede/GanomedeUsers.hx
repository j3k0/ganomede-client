package fovea.ganomede;

import fovea.async.*;
import fovea.events.Event;
import fovea.utils.ReadyStatus;
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
    public var loginStatus(default,null):ReadyStatus = new ReadyStatus();

    public function new(client:GanomedeClient) {
        super(client.url + "/" + TYPE);
        this.client = client;
    }

    public function initialize():Promise {
        var deferred:Deferred = new Deferred();
        deferred.resolve();
        return deferred.then(function initializedFn(obj:Object):Void {
            initialized = true;
            if (me.isAuthenticated()) {
                dispatchLoginEvent(null);
            }
        });
    }

    private function dispatchLoginEvent(result:Object):Void {
        dispatchEvent(new Event(GanomedeEvents.LOGIN));
        loginStatus.setReady();
    }

    public function signUp(user:GanomedeUser):Promise {
        me = user;
        return ajax("POST", "/accounts", {
            data: user.toJSON(),
            parse: parseMe
        })
        .then(dispatchLoginEvent);
    }

    public function passwordResetEmail():Promise {
        return ajax("POST", "/auth/" + me.token + "/passwordResetEmail");
    }

    public function forgotPassword(email:String):Promise {
        return ajax("POST", "/passwordResetEmail", {
            data: {
                email: email
            }
        });
    }

    public function login(user:GanomedeUser):Promise {
        me = user;
        return ajax("POST", "/login", {
            data: {
                username: user.username,
                password: user.password,
                facebookId: user.facebookId,
                facebookToken: user.facebookToken
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
            .then(function fetched(outcome:Object):Void {
                deferred.resolve(user);
                loginStatus.setReady();
            })
            .error(deferred.reject);
        } 
        else {
            deferred.reject(new ApiError(AjaxError.IO_ERROR)); // TODO
        }

        return deferred;
    }

    // Retrieve metadata for a user, cache the result.
    // Note, saving metadata have to update the cache, or this will fail miserably!
    public function loadUserMetadata(username:String, key:String):Promise {
        var deferred:Deferred = new Deferred();
        var endpoint:String = "/" + username + "/metadata/" + key;
        var obj:Object = cached("GET", endpoint);
        if (obj) {
            deferred.resolve(obj.data);
        }
        else {
            cachedAjax("GET", endpoint)
            .then(function metadataLoaded(obj:Object):Void {
                deferred.resolve(obj.data);
            })
            .error(deferred.reject);
        }
        return deferred;
    }

    // Load some metadata for the current user
    public function loadMetadata(key:String):Promise {
        if (me != null && key == "email" && me.email != null)
            return new Deferred().resolve({
                value: me.email
            });
        else if (me != null && me.metadata != null && Reflect.hasField(me.metadata, key))
            return new Deferred().resolve({
                value: Reflect.field(me.metadata, key)
            });
        else if (me.token == null) {
            return new Deferred().resolve({
                value: null
            });
        }
        return loadUserMetadata("auth/" + me.token, key)
        .then(function(outcome:Dynamic):Void {
            if (me == null)
                return;
            if (me.metadata == null)
                me.metadata = {};
            if (key == 'email')
                me.email = outcome.value;
            else
                Reflect.setField(me.metadata, key, outcome.value);
        });
    }

    // Load multiple metadatas for the current user
    // TODO: replace by a single API call
    public function loadMetadatas(keys:Array<String>):Promise {
        var ret = {};
        var load = function(key:String):Promise {
            return loadMetadata(key)
            .then(function(outcome:Dynamic):Void {
                Reflect.setField(ret, key, outcome.value);
            });
        };
        var deferred:Deferred = new Deferred();
        Parallel.runWithArgs(keys, load)
        .then(function(outcome:Dynamic):Void {
            deferred.resolve(ret);
        })
        .error(deferred.reject);
        return deferred;
    }

    // TODO: replace by a single API call
    public function loadUsersMetadata(usernames:Array<String>, key:String):Promise {
        var ret = [];
        var load = function(username:String):Promise {
            return loadUserMetadata(username, key)
            .then(function(outcome:Dynamic):Void {
                ret.push({
                    username: username,
                    key: key,
                    value: outcome.value
                });
            });
        };
        var deferred:Deferred = new Deferred();
        Parallel.runWithArgs(usernames, load)
        .then(function(outcome:Dynamic):Void {
            deferred.resolve({
                metadatas: ret
            });
        })
        .error(deferred.reject);
        return deferred;
    }

    // Save metadata for the current user
    public function saveMetadata(key:String, value:String):Promise {
        var endpoint:String = "/auth/" + me.token + "/metadata/" + key;
        var data:Object = { value: value };
        return ajax("POST", endpoint, {
            data: data
        })
        .then(function metadataSaved(outcome:Object):Void {
            // Update the GET cache...
            var endpoint:String = "/" + me.username + "/metadata/" + key;
            setCache("GET", endpoint, {
                status: 200,
                data: data
            });
        });
    }

    public var friends(default, null) = new Array<String>();
    public function refreshFriends():Promise {
        var endpoint:String = "/auth/" + me.token + "/friends";
        return ajax("GET", endpoint)
        .then(function friendsRefreshed(outcome:Object):Void {
            friends = outcome.data;
        });
    }

    private function parseMe(obj:Object):Object {
        var oldToken:String = me.token;
        var oldUsername:String = me.username;
        me.fromJSON(obj);
        if (me.token != oldToken || me.username != oldUsername) {
            dispatchEvent(new Event(GanomedeEvents.AUTH));
        }
        return me;
    }
}

// vim: sw=4:ts=4:et:
