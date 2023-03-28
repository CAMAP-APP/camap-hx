package service;

import sugoi.form.elements.Checkbox;
import sugoi.form.elements.Input.InputType;
import sugoi.form.elements.IntInput;
import sugoi.form.validators.EmailValidator;
import tink.core.Error;

typedef VendorDto = {
	name:String,
	email:String,
	linkUrl:String,
	country:String,

}

class VendorService{

	public static var PROFESSIONS:Array<{id:Int,name:String}>; //cache

	public function new(){}

	/**
		Search vendors.
	**/
	public static function findVendors(search:{?name:String,?email:String,?geoloc:Bool,?profession:Int,?fromLat:Float,?fromLng:Float}){
		var vendors = [];
		var names = [];
		var where = [];
		if(search.name!=null){
			for( n in search.name.split(" ")){
				n = n.toLowerCase();
				if(Lambda.has(["le","la","les","du","de","l'","a","à","au","en","sur","qui","ferme","GAEC","EARL","SCEA","jardin","jardins"],n)) continue;
				if(Lambda.has(["create","delete","drop","select","count","truncate"],n)) continue; //no SQL injection !
			
				names.push(n);
			}
			where.push('(' + names.map(n -> 'name LIKE "%$n%"').join(' OR ') + ')');
		}
		
		//search by mail
		// if(search.email!=null){
		// 	where.push('email LIKE "${search.email}"');
		// }

		//search by profession
		if(search.profession!=null){
			where.push('(profession = ${search.profession} OR production2 = ${search.profession} OR production3 = ${search.profession})');
		}
		
		var selectDist = '';
		var orderBy = "";

		if(search.geoloc && search.fromLat!=null){
			orderBy = "ORDER BY dist ASC";
			selectDist = ',SQRT(POW(lat-${search.fromLat},2) + POW(lng-${search.fromLng},2)) as dist';
			where.push("lat is not null");
		}

		//search for each term
		vendors = Lambda.array(db.Vendor.manager.unsafeObjects('SELECT * $selectDist FROM Vendor WHERE ${where.join(' AND ')} $orderBy LIMIT 30',false));

		return vendors;
	}


	/**
		Create a vendor
	**/
	public static function create(data:VendorDto):db.Vendor{

		//already exists ?
		var vendors = db.Vendor.manager.search($email==data.email,false).array();

		if(vendors.length>0) throw new Error("Un producteur est déjà référencé avec cet email dans notre base de données");

		var vendor = update(new db.Vendor(),cast data);

		vendor.insert();
		return vendor;
	}

	public static function getForm(vendor:db.Vendor):sugoi.form.Form {
		var t = sugoi.i18n.Locale.texts;
		var form = form.CamapForm.fromSpod(vendor);
		
		//country
		form.removeElementByName("country");
		var country = vendor.country==null ? "FR" : vendor.country.toUpperCase();
		form.addElement(new sugoi.form.elements.StringSelect('country',t._("Country"),db.Place.getCountries(),country,true));
		
		//profession
		var data = sugoi.form.ListData.fromSpod(service.VendorService.getVendorProfessions());
		form.addElement(new sugoi.form.elements.IntSelect('profession',"Profession",data,vendor.profession,true),4);
		form.addElement(new sugoi.form.elements.IntSelect('production2',"Profession 2",data,vendor.production2,false),5);
		form.addElement(new sugoi.form.elements.IntSelect('production3',"Profession 3",data,vendor.production3,false),6);

		//email is required
		form.getElement("email").required = true;

		return form;
	}

	/**
		update a vendor
	**/
	public static function update(vendor:db.Vendor,data:VendorDto){

		//apply changes
		for( f in Reflect.fields(data)){
			var v = Reflect.field(data,f);
			Reflect.setProperty(vendor,f,v);
		}

		if(data.linkUrl!=null && data.linkUrl.indexOf("http://")==-1 && data.linkUrl.indexOf("https://")==-1){
			vendor.linkUrl = "http://"+data.linkUrl;
		}

		//email
		if( vendor.email==null ) throw new Error("Vous devez définir un email pour ce producteur.");
		if( !EmailValidator.check(vendor.email) ) throw new Error("Email invalide.");

		//desc
		if( vendor.desc!=null && vendor.desc.length>1000) throw  new Error("Merci de saisir une description de moins de 1000 caractères");

		return vendor;
	}

	/**
		Loads vendors professions from json
	**/
	public static function getVendorProfessions():Array<{id:Int,name:String}>{
		if( PROFESSIONS!=null ) return PROFESSIONS;
		var filePath = sugoi.Web.getCwd()+"../data/vendorProfessions.json";
		var json = haxe.Json.parse(sys.io.File.getContent(filePath));
		PROFESSIONS = json.professions;
		return json.professions;
	}	

}