package fovea.ganomede;

import openfl.utils.Object;
import fovea.async.*;
import fovea.ganomede.models.GanomedeVMoney;
import fovea.ganomede.models.GanomedePackPurchase;
import fovea.net.AjaxError;

@:expose
class GanomedeVirtualCurrencyClient extends AuthenticatedClient
{
    public static inline var TYPE:String = "virtualcurrency/v1";

    public function new(baseUrl:String, token:String) {
        super(baseUrl, TYPE, token);
    }

    public function listProducts():Promise {
        return cachedAjax("GET", "/products?limit=999999");
    }

    public function getCount(currencyCodes:Array<String>):Promise {
        return ajax("GET", "/coins/" + currencyCodes.join(",") + "/count", {
            cache: false
        });
    }

    private function pushVar(array:Array<String>, options:Object, variable:String):Void {
        if (options != null) {
            var value:Dynamic = Reflect.field(options, variable);
            if (value != null)
                array.push(variable + "=" + value);
        }
    }

    private function pushArray(array:Array<String>, options:Object, variable:String):Void {
        if (options != null) {
            var value:Array<String> = Reflect.field(options, variable);
            if (value != null)
                array.push(variable + "=" + value.join(","));
        }
    }

    private function makePath(p:String, vars:Array<String>):String {
        if (vars.length > 0)
            return p + "?" + vars.join("&");
        else
            return p;
    }

    // options:
    //  - currencies: Array of currency codes
    //  - reasons: Either "purchase" or "reward"
    //  - limit: Max number of entries to retrieve
    public function getTransactions(options:Object = null):Promise {
        var vars:Array<String> = [];
        pushArray(vars, options, "currencies");
        pushVar(vars, options, "reasons");
        pushVar(vars, options, "limit");
        return ajax("GET", makePath("/transactions", vars));
    }

    public function addPurchase(productId:String, cost:GanomedeVMoney):Promise {

        var data:Object = {
            itemId: productId,
            cost: {
            }
        };
        Reflect.setField(data.cost, cost.id, cost.count);

        return ajax("POST", "/purchases", { data: data });
    }

    public function addPackPurchase(packPurchase:GanomedePackPurchase):Promise {
        return ajax("POST", "/packs/" + packPurchase.packId + "/purchases", { data: packPurchase.toJSON() });
    }

    /*public function listVirtualCurrency():Promise {
        return ajax("GET", "/invitations");
    }*/

    /* private function parseArray(obj:Object):Object {
        var array:Array<Object> = cast(obj, Array<Object>);
        if (array == null) {
            return obj;
        }
        var i:Int;
        for (i in 0...array.length) {
            array[i] = new GanomedeInvitation(array[i]);
        }
        return array;
    }

    public function deleteInvitation(invite:GanomedeInvitation, reason:String):Promise {
        var deferred:Deferred = new Deferred();
        // ajax("DELETE", "/invitations/" + invite.id, {
        ajax("POST", "/invitations/" + invite.id + "/delete", {
            data: {
                reason: reason
            }
        })
        .then(function invitationDeleted(result:Object):Void {
            if (!result.data || result.data.ok == true)
                deferred.resolve();
            else
                deferred.reject(new ApiError(AjaxError.HTTP_ERROR, result.status, result.data));
        })
        .error(deferred.reject);
        return deferred;
    }*/
}

// vim: sw=4:ts=4:et:

