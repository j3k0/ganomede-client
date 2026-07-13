package fovea.ganomede.models;

import openfl.utils.Object;
import fovea.utils.Model;

@:expose
class GanomedePlayerScore {
    public var username:String;
    public var score:Int;
    public var resigned:Bool = false;
    public var kickedOut:Bool = false;

    public function new(obj:Object) {
        username = obj.username;
        score = obj.score;
        if (obj.resigned) resigned = true;
        if (obj.kickedOut) kickedOut = true;
    }

    public function toJSON():Object {
        return {
            username:username,
            score:score,
            resigned:resigned,
            kickedOut:kickedOut
        };
    }
}

// vim: sw=4:ts=4:et:
