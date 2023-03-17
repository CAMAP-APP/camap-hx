package controller;
import db.UserGroup;
import haxe.Json;
import neko.Web;
import sugoi.db.Session;

/**
 * REST JSON API
 * 
 * @author fbarbut
 */
class Api extends Controller
{

	/**
	 * Public infos about this CAMAP installation
	 */
	public function doDefault(){
		
		var json : Dynamic = {
			version:App.VERSION.toString(),
			debug:App.config.DEBUG,			
		};
		Sys.print( Json.stringify(json) );
	}
	
	public function doOrder(d:haxe.web.Dispatch) {
		d.dispatch(new controller.api.Order());
	}	

	public function doDistributions(d:haxe.web.Dispatch) {
		d.dispatch(new controller.api.Distributions());
	}	

	public function doPlaces(d:haxe.web.Dispatch, place: db.Place) {
		d.dispatch(new controller.api.Places(place));
	}

	public function doCatalog(d:haxe.web.Dispatch) {
		d.dispatch(new controller.api.Catalog());
	}
	
	public function doSubscription(d:haxe.web.Dispatch) {
		d.dispatch(new controller.api.Subscription());
	}

	/**
	 * Get distribution planning for this group
	 * 
	 * @param	group
	 */
	public function doPlanning(group:db.Group){
		
		var contracts = group.getActiveContracts(true);
		var cids = Lambda.map(contracts, function(p) return p.id);
		var now = Date.now();
		var now = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
		var twoMonths = new Date(now.getFullYear(), now.getMonth()+2, now.getDate(), 0, 0, 0);
		var distribs = db.Distribution.manager.search(($catalogId in cids) && ($date >= now) && ($date<=twoMonths), { orderBy:date }, false);
		
		var out = new Array<{id:Int,start:Date,end:Date,contract:String,contractId:Int,place:Dynamic}>();
		
		for ( d in distribs){
			
			var place = d.place;
			var p =  {name:place.name, address1:place.address1,address2:place.address2,zipCode:place.zipCode,city:place.city }			
			out.push({id:d.id,start:d.date,end:d.end,contract:d.catalog.name,contractId:d.catalog.id,place:p});
		}
		
		Sys.print(Json.stringify(out));
	}
	
	public function doUser(d:haxe.web.Dispatch){
		d.dispatch(new controller.api.User());
	}
	
	public function doProduct(d:haxe.web.Dispatch){
		d.dispatch(new controller.api.Product());
	}

	/**
		create session with no user for dev purpose
	**/
	public function doCreateSid(){

		if(!App.config.DEBUG) throw "only works if config.DEBUG=true";

		var session = Session.init([]);

		json({
			sid : session.sid,
		});



	}
	
}