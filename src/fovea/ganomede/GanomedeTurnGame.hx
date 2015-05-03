package fovea.ganomede;

import openfl.utils.Object;
import fovea.utils.Model;

@:expose
class GanomedeTurnGame extends Model {
    public var type:String;
    public var players:Array<String>;
    public var turn:String;
    public var status:String;
    public var gameData:Object;
    public var gameConfig:Object;

    // server handling this turngame
    public var url:String;

    public function new(obj:Object = null) {
        super(obj);
    }

    public function fromGame(game:GanomedeGame):GanomedeTurnGame {
        fromJSON(game.toJSON());
        return this;
    }

    public override function fromJSON(obj:Object):Void {
        if (obj.id) id = obj.id;
        if (obj.type) type = obj.type;
        if (obj.players) players = obj.players;
        if (obj.turn) turn = obj.turn;
        if (obj.status) status = obj.status;
        if (obj.gameData) gameData = obj.gameData;
        if (obj.gameConfig) gameConfig = obj.gameConfig;
        if (obj.url) url = obj.url;
    }

    public override function toJSON():Object {
        return {
            id:id,
            type:type,
            players:players,
            turn:turn,
            status:status,
            gameData:gameData,
            gameConfig:gameConfig,
            url:url
        };
    }
}
// vim: sw=4:ts=4:et: