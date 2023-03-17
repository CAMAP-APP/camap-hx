package service;

import service.Mapbox;

class PlaceService{

	/**
	 *  Geocode a place with MapBox Geocode API
	 */
	public static function geocode(p:db.Place):{lat:Float,lng:Float}{
		var address = p.getAddress();
		var res = Mapbox.geocode(address);

		// trace(res);

		if(res.geometry.coordinates[0]==null){
			throw new tink.core.Error("unable to locate this address");
		}
		
		p.lock();
		p.lat = res.geometry.coordinates[1];
		p.lng = res.geometry.coordinates[0];
		p.update();

		return {lat:p.lat,lng:p.lng};

	}

}