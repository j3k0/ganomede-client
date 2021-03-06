package fovea.ganomede;

import openfl.utils.Object;

@:expose
class GanomedeUser {
    public var username:String;
    public var givenName:String;
    public var surname:String;
    public var email:String;
    public var password:String;
    public var appleId:String;
    public var appleIdentityToken:String;
    public var appleAuthorizationCode:String;
    public var facebookId:String;
    public var facebookToken:String;
    public var metadata:Object;

    public var token(default,set):String = null;
    public function set_token(value:String):String {
        token = value;
        if (token == "") token = null;
        return token;
    }

    public function isAuthenticated():Bool {
        return !(token == null || token == "");
    }

    public function new(obj:Object = null) {
        if (obj != null) {
            username = obj.username;
            givenName = obj.givenName;
            surname = obj.surname;
            email = obj.email;
            password = obj.password;
            token = obj.token;
            facebookId = obj.facebookId;
            facebookToken = obj.facebookToken;
            appleId = obj.appleId;
            appleIdentityToken = obj.appleIdentityToken;
            appleAuthorizationCode = obj.appleAuthorizationCode;
            metadata = obj.metadata;
        }
    }

    public function fromJSON(obj:Object):Void {
        if (obj == null) return;
        if (obj.username) username = obj.username;
        if (obj.givenName) givenName = obj.givenName;
        if (obj.surname) surname = obj.surname;
        if (obj.email) email = obj.email;
        if (obj.password) password = obj.password;
        if (obj.token) token = obj.token;
        if (obj.appleId) appleId = obj.appleId;
        if (obj.appleIdentityToken) appleIdentityToken = obj.appleIdentityToken;
        if (obj.appleAuthorizationCode) appleAuthorizationCode = obj.appleAuthorizationCode;
        if (obj.facebookId) facebookId = obj.facebookId;
        if (obj.facebookToken) facebookToken = obj.facebookToken;
        if (obj.metadata) metadata = obj.metadata;
    }

    public function toJSON():Object {
        return {
            username: username,
            givenName: givenName,
            surname: surname,
            email: email,
            password: password,
            token: token,
            appleId: appleId,
            appleIdentityToken: appleIdentityToken,
            appleAuthorizationCode: appleAuthorizationCode,
            facebookId: facebookId,
            facebookToken: facebookToken,
            metadata: metadata
        };
    }
}

// vim: sw=4:ts=4:et:
