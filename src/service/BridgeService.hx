package service;

import sugoi.db.Cache;
import db.Vendor;
import haxe.Json;
import sugoi.apis.linux.Curl;

class BridgeService {
	private static var _neoManifest:Null<haxe.DynamicAccess<Dynamic>> = null;

	private static function getNeoWebpackManifest():haxe.DynamicAccess<Dynamic> {
		if (BridgeService._neoManifest == null) {
			var url = App.config.get("camap_bridge_api") + "/neostatic/manifest.json";
			var curl = new Curl();			
			var res = curl.call("GET", url, getHeaders());
			var manifest:haxe.DynamicAccess<Dynamic> = haxe.Json.parse(res);
			_neoManifest = manifest;
		};
		return _neoManifest;
	}

	public static function getNeoModuleScripts() {
		try{
			var manifest = BridgeService.getNeoWebpackManifest();
			var data = [manifest.get("runtime.js"), manifest.get("reactlibs.js"), manifest.get("vendors.js"), manifest.get("neo.js")];
			if(Std.random(10)==0 && Cache.get("manifest")==null){
				Cache.set("manifest",data,60*60);
			}
			return data;
			
		}catch(e:Dynamic){

			var cache = Cache.get("manifest");
			if(cache!=null){
				return cache;
			}else{
				throw "Unable to load ressources from CAMAP-ts.";				
			}
		}
	}

	public static function call(uri:String) {
		var baseUrl = App.config.get("camap_bridge_api") + "/bridge";
		var curl = new Curl();
		var res = curl.call("GET", baseUrl + uri, getHeaders());
		try{
			return haxe.Json.parse(res);
		}catch(e:Dynamic){
			throw "Bridge Error :"+Std.string(e)+", raw : "+Std.string(res);			
		}		
	}

	public static function getAuthToken(user:db.User) {
		var baseUrl = App.config.get("camap_bridge_api") + "/bridge";
		var curl = new Curl();
		//no json
		return curl.call("GET", baseUrl + "/auth/tokens/"+user.id, getHeaders());
	}

	public static function logout(user:db.User) {
		if (user==null) return null;
		var baseUrl = App.config.get("camap_bridge_api") + "/bridge";
		var curl = new sugoi.apis.linux.Curl();
		return curl.call("GET", baseUrl + "/auth/logout/"+user.id, getHeaders());
	}

	static function getHeaders():Map<String,String>{
		return [
			"Authorization" => "Bearer " + App.config.get("key"),
			"Content-type" => "application/json;charset=utf-8",
			"Accept" => "application/json",
			"Cache-Control" => "no-cache",
			"Pragma" => "no-cache",
		];

	}
}
