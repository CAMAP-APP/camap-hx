package controller.api;
import haxe.Json;
import tink.core.Error;
import service.PaymentService;
import Common;
import jwt.JWT;

/**
 * Public user API
 */
class User extends Controller
{

	public function doDefault(user:db.User){
		//get a user
	}

	public function doMe() {
		if (App.current.user == null) throw new Error(Unauthorized, "Access forbidden");
		var current = App.current.user;

		if (sugoi.Web.getMethod() == "GET") {
			return Sys.print(haxe.Json.stringify(current.infos()));
		} else if (sugoi.Web.getMethod() == "POST") {
			var request = sugoi.tools.Utils.getMultipart( 1024 * 1024 * 10 ); //10Mb	

			current.lock();
			
			if (request.exists("address1")) current.address1 = request.get("address1");
			if (request.exists("address2")) current.address2 = request.get("address2");
			if (request.exists("city")) current.city = request.get("city");
			if (request.exists("zipCode")) current.zipCode = request.get("zipCode");
			if (request.exists("phone")) current.phone = request.get("phone");

			current.update();

			return Sys.print(haxe.Json.stringify(current.infos()));
		} else throw new Error(405, "Method Not Allowed");
	}

	/**
	 *  get users of current group
	 */
	@logged
	function doGetFromGroup(){

		if(!app.user.canAccessMembership() && !app.user.isContractManager()) {
			throw new tink.core.Error(403,"Access forbidden");
		}

		var members:Array<UserInfo> = service.UserService.getFromGroup(app.user.getGroup()).map( m -> m.infos() );
		Sys.print(tink.Json.stringify({users:members}));
	}


	@logged
	function doGetToken() {
		var token : String = JWT.sign({ email: App.current.user.email, id: App.current.user.id }, App.config.get("key"));
		Sys.print(
			Json.stringify({ 
				token:token 
			})
		);
	} 
	
}