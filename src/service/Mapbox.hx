package service;

import tink.core.Error;

typedef GeoPoint = {
  place_type: Array<String>,
  geometry: {
    type: String,
    coordinates: Array<Float>
  }
};

class Mapbox {

  static public function geocode(address: String) {
    var options = new Map<String, Dynamic>();
    options.set("autocomplete", false);
    options.set("limit", 1);
    var res: Array<GeoPoint> = Mapbox.request("mapbox.places/" + StringTools.urlEncode(address) + ".json", options);
    return res[0];
  }


  static private function request(service: String, ?options: Map<String, Dynamic>): Array<GeoPoint> {
    var curl = new sugoi.apis.linux.Curl();
    var token = App.config.get("mapbox_server_token");
    var url = "https://api.mapbox.com/geocoding/v5/" + service + "?access_token=" + token;

    if (options != null) {
      var it = options.keys();
      var optionsArray = new Array<String>();
      while (it.hasNext()) {
        var key = it.next();
        optionsArray.push(key + "=" + Std.string(options.get(key)));
      }
      url += "&" + optionsArray.join("&");
    }

    try {
			var rawResult = curl.call("GET", url);
			if (rawResult != null && rawResult != ""){
        var res: Dynamic = haxe.Json.parse(rawResult);
        if(res==null || res.features==null){
          throw new Error("Invalid res features : "+Std.string(res));    
        }
        return res.features.map(Mapbox.parseGeoFeature);
      }
      throw new Error("Error");
		}catch (e: Dynamic){
			throw new Error(Std.string(e));
		}
  }

  static private function parseGeoFeature(data: Dynamic): GeoPoint {
    return {
      place_type: data.place_type,
      geometry: data.geometry
    }
  }
}