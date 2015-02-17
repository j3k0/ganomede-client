package fovea.ganomede
{
    public class GanomedeInvitation {
        public var id:String;
        public var gameId:String;
        public var type:String;
        public var to:String;
        public var from:String;
        public var index:int = 0;

        public function GanomedeInvitation(obj:Object = null) {
            if (obj) {
                fromJSON(obj);
            }
        }

        public function equals(obj:Object):Boolean {
            if (obj.id != id) return true;
            if (obj.gameId != gameId) return true;
            if (obj.type != type) return true;
            if (obj.to != to) return true;
            if (obj.from != from) return true;
            if (obj.index != index) return true;
            return false;
        }

        public function fromJSON(obj:Object):void {
            if (obj.id) id = obj.id;
            if (obj.gameId) gameId = obj.gameId;
            if (obj.type) type = obj.type;
            if (obj.to) to = obj.to;
            if (obj.from) from = obj.from;
            if (obj.index) index = obj.index;
        }

        public function toJSON():Object {
            return {
                id:id,
                gameId:gameId,
                type:type,
                to:to,
                from:from,
                index:index
            };
        }
    }
}
// vim: sw=4:ts=4:et: