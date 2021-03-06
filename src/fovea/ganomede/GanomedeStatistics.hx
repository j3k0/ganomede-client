package fovea.ganomede;

import fovea.async.Deferred;
import fovea.async.Promise;
import fovea.events.Event;
import fovea.events.Events;
import fovea.ganomede.models.GanomedeGameArchive;
import fovea.net.Ajax;
import fovea.net.AjaxError;
import openfl.utils.Object;

//
// Link to ganomede-statistics module.
//
// The server module fetches over-ed game as they get registered
// into ganomede-coordinator.
//
// It stores its own archive of games by players, but adds for each
// the updated level and ranking of both players.
//
// This class provides access points to archive, rank and level for
// any player from its username.
//
// See https://github.com/j3k0/ganomede-statistics for the full REST API
//
@:expose
class GanomedeStatistics extends ApiClient
{
    public static inline var TYPE:String = "statistics/v1";

    public function new(client:GanomedeClient, gameType:String) {
        super(client.url + "/" + TYPE + "/" + gameType);
    }

    public function initialize():Promise {
        return new Deferred().resolve(null);
    }

    public function getRank(username:String):Promise {
        return ajaxGetData(makePath(username, "rank"));
    }

    public function getLevel(username:String):Promise {
        return ajaxGetData(makePath(username, "level"));
    }

    public static function makePath(username:String, endpoint:String):String {
        return "/" + username + "/" + endpoint;
    }

    // Array<{
    //   "game": {
    //     "id": String;
    //     "date": Number;
    //     "players": Array<{
    //       "username": String;
    //       "score": int;
    //     }>
    //   }
    //   "outcome": {
    //     "newLevel": Number;
    //     "newRank": int;
    //   }
    // }>
    public function getArchive(username:String):Promise {
        var deferred:Deferred = new Deferred();
        ajaxGetData(makePath(username, "archive"))
        .then(function(obj:Array<Object>):Void {
            deferred.resolve(GanomedeGameArchive.fromJSON(obj));
        })
        .error(deferred.reject);
        return deferred;
    }
}

// vim: sw=4:ts=4:et:

