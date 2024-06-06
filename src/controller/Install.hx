package controller;
import service.SubscriptionService;
import sugoi.db.Variable;
import sugoi.form.elements.StringInput;
import service.VolunteerService;
import Common;

/**
 * ...
 * @author fbarbut
 */
class Install extends controller.Controller
{
	/**
	 * First install 
	 */
	 @tpl("form.mtt")
	 public function doDefault(){
 
		if (db.User.manager.count(true) > 0) {
			throw "CAMAP est déjà installé";
		}

		view.title = "Installation de CAMAP";

		var f = new sugoi.form.Form("c");
		f.addElement(new StringInput("amapName", t._("Name of your group"),"",true));
		f.addElement(new StringInput("userFirstName", t._("Your firstname"),"",true));
		f.addElement(new StringInput("userLastName", t._("Your lastname"),"",true));

		if (f.checkToken()) {

			var user = new db.User();
			user.firstName = f.getValueOf("userFirstName");
			user.lastName = f.getValueOf("userLastName");
			user.email = "admin@camap.localdomain";
			user.setPass("admin");
			user.rights.set(Admin);
			user.insert();
		
			var amap = new db.Group();
			amap.name = f.getValueOf("amapName");
			amap.contact = user;
			amap.hasMembership = true;
			amap.insert();
			
			var ua = new db.UserGroup();
			ua.user = user;
			ua.group = amap;				
			ua.insert();
			ua.giveRight(Right.GroupAdmin);
			ua.giveRight(Right.Membership);
			ua.giveRight(Right.Messages);
			ua.giveRight(Right.ContractAdmin(null));
			
			//example datas
			var place = new db.Place();
			place.name = t._("Marketplace");
			place.group = amap;
			place.address1 = t._("4 Place de Bretagne");
			place.zipCode = "44000";
			place.city = t._("Nantes");
			place.insert();
			
			var vendor = new db.Vendor();
			vendor.name = t._("Harry Covert");
			vendor.email = "harry.covert@camap.tld";
			vendor.zipCode = "44670";
			vendor.city = "Juigné-les-Moutiers";
			vendor.insert();
			
			var contract = new db.Catalog();
			contract.name = t._("Vegetables Contract Example");
			contract.group  = amap;
			contract.type = 0;
			contract.vendor = vendor;
			contract.startDate = Date.now();
			contract.endDate = DateTools.delta(Date.now(), 1000.0 * 60 * 60 * 24 * 364);
			contract.contact = user;
			contract.distributorNum = 2;
			contract.insert();
			
			var p = new db.Product();
			p.name = t._("Big basket of vegetables");
			p.price = 20;
			p.vat = 5;
			p.catalog = contract;
			p.insert();
			
			var p = new db.Product();
			p.name = t._("Small basket of vegetables");
			p.price = 10;
			p.vat = 5;
			p.catalog = contract;
			p.insert();
		
			App.current.user = null;
			// App.current.session.data.amapId  = amap.id;
			
			throw Ok("/", t._("Group and user 'admin' created. Your email is 'admin@camap.localdomain' and your password is 'admin'"));
		}	
		
		view.form = f;
	}

	public function doDiagnostics(){

		var webroot = sugoi.Web.getCwd();

		if(!sys.FileSystem.exists(webroot+"file")){
			Sys.println("no File directory : created");
			sys.FileSystem.createDirectory(webroot+"file");
		} 
		if(!sys.FileSystem.exists(webroot+"file/.htaccess")){
			Sys.println("no .htaccess file in 'File' directory");
		} 
		if(!sys.FileSystem.exists(webroot+"../tmp")) {
			Sys.println("no tmp directory : created");
			sys.FileSystem.createDirectory(webroot+"../tmp");
		}

	}

}