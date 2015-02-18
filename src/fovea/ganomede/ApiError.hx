package fovea.ganomede;

import openfl.errors.Error;
import openfl.utils.Object;

class ApiError extends Error
{
    // Codes
    public static inline var HTTP_ERROR:String = "HTTP";
    public static inline var IO_ERROR:String = "IO";
    public static inline var SECURITY_ERROR:String = "SECURITY";
    public static inline var CLIENT_ERROR:String = "CLIENT";

    // Api Codes
    public static inline var INVALID:String = "StormpathResourceError400";
    public static inline var ALREADY_EXISTS:String = "StormpathResourceError2001";

    public function new(pcode:String, pstatus:Int = 0, pdata:Object = null)
    {
        var msg:String = "ApiError[" + pcode + "]";
        if (pstatus != 0) {
            msg += " status:" + pstatus;
        }
        super(msg, 1838012);
        this.code = pcode;
        this.status = pstatus;
        this.data = pdata;
    }

    public var code(default,null):String = null;
    public var status(default,null):Int = 0;
    public var data(default,null):Object = null;

    public var apiMessage(get,never):String;
    public function get_apiMessage():String {
        if (data != null && data.message)
            return data.message;
        else
            return message();
    }

    public var apiCode(get,never):String;
    public function get_apiCode():String {
        if (data != null && data.code)
            return data.code;
        else if (status != 0) {
            return code + status;
        }
        else {
            return code;
        }
    }
}

// vim: sw=4:ts=4:et:
