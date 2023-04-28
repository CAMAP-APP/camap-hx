package db;
import Common;
import sugoi.form.validators.EmailValidator;
import sys.db.Object;
import sys.db.Types;

enum DisabledReason{
	IncompleteLegalInfos; 	//0 : incomplete legal infos
	NotCompliantWithPolicy; //1 : not compliant with policy
	Banned; 				//2 : banned by administrators	
}


/**
 * Vendor (farmer/producer/vendor)
 */
class Vendor extends Object
{
	public var id : SId;
	public var name : SString<128>;	//Business name 
	public var peopleName : SNull<SString<128>>; //Business owner(s) name
	
	@hideInForms public var profession : SNull<SInt>;
	@hideInForms public var production2 : SNull<SInt>;
	@hideInForms public var production3 : SNull<SInt>;

	public var email:SNull<SString<128>>;
	public var phone:SNull<SString<19>>;
		
	public var address1:SNull<SString<64>>;
	public var address2:SNull<SString<64>>;
	public var zipCode:SString<32>;
	public var city:SString<25>;
	public var country:SNull<SString<64>>;
	public var companyNumber:SNull<SString<64>>;


	public var desc : SNull<SText>;
	@hideInForms public var cdate : SNull<SDateTime>; // date de création

	public var linkText:SNull<SString<256>>;
	public var linkUrl:SNull<SString<256>>;

	@hideInForms public var directory 	: SBool;
	@hideInForms public var longDesc 	: SNull<SText>;
	
	@hideInForms @:relation(imageId) 	public var image : SNull<sugoi.db.File>;
	
	@hideInForms public var disabled : SNull<SEnum<DisabledReason>>; // vendor is disabled
	
	@hideInForms public var lat:SNull<SFloat>;
	@hideInForms public var lng:SNull<SFloat>;

	public function new() 
	{
		super();
		directory = true;
		cdate = Date.now();
	}

	override function toString() {
		return name;
	}

	public function getContracts(){
		return db.Catalog.manager.search($vendor == this,{orderBy:-startDate}, false);
	}

	public function getActiveContracts(){
		var now = Date.now();
		return db.Catalog.manager.search($vendor == this && $startDate < now && $endDate > now ,{orderBy:-startDate}, false);
	}

	public function getImage():String{
		if (imageId == null) {
			return "/img/vendor.png";
		}else {
			return App.current.view.file(imageId);
		}
	}

	public function getImages(){

		var out = {
			logo:null,
			portrait:null,
			banner:null,
			farm1:null,				
			farm2:null,				
			farm3:null,				
			farm4:null,				
		};

		var files = sugoi.db.EntityFile.getByEntity("vendor",this.id);
		for( f in files ){
			switch(f.documentType){				
				case "logo" 	: out.logo 		= f.getFileId();
				case "portrait" : out.portrait 	= f.getFileId();
				case "banner" 	: out.banner 	= f.getFileId();
				case "farm1" 	: out.farm1 	= f.getFileId();
				case "farm2" 	: out.farm2 	= f.getFileId();
				case "farm3" 	: out.farm3 	= f.getFileId();
				case "farm4" 	: out.farm4 	= f.getFileId();
			}
		}

		if(out.logo==null) out.logo = this.imageId;

		return out;
	}

	public function getInfos(?withImages=false):VendorInfos{

		var file = function(fId: Int){
			return if(fId==null)  null else App.current.view.file(fId);
		}
		var vendor = this;
		var out : VendorInfos = {
			id : id,
			name : vendor.name,
			profession:null,
			email:vendor.email,
			image : file(vendor.imageId),
			images : cast {},
			address1: vendor.address1,
			address2: vendor.address2,
			zipCode : vendor.zipCode,
			city : vendor.city,
			linkText:vendor.linkText,
			linkUrl:vendor.linkUrl,
			desc:vendor.desc,
			longDesc:vendor.longDesc,
		};

		if(this.profession!=null){
			out.profession = getProfession();
		}

		if(withImages){
			var images = getImages();
			out.images.logo = file(images.logo);
			out.images.portrait = file(images.portrait);
			out.images.banner = file(images.banner);
			out.images.farm1 = file(images.farm1);
			out.images.farm2 = file(images.farm2);
			out.images.farm3 = file(images.farm3);
			out.images.farm4 = file(images.farm4);
		}
		return out;
	}

	public function getProfession():String {
		if(this.profession==null) return null;
		var p = service.VendorService.getVendorProfessions().find(x -> x.id==this.profession);
		if(p==null) throw new tink.core.Error("Vendor #"+this.id+" has invalid profession code : "+this.profession);
		return p.name;
	}

	public function getGroups():Array<db.Group>{
		var contracts = getActiveContracts();
		var groups = Lambda.map(contracts,function(c) return c.group);
		return tools.ObjectListTool.deduplicate(groups);
	}

	

	public static function getLabels(){
		var t = sugoi.i18n.Locale.texts;
		return [
			"name" 				=> "Nom de votre ferme/entreprise",
			"peopleName" 		=> "Nom de l'exploitant(e)",	
			"desc" 				=> t._("Description"),
			"email" 			=> t._("Email pro"),
			"legalStatus"		=> t._("Legal status"),
			"phone" 			=> t._("Phone"),
			"address1" 			=> t._("Address 1"),
			"address2" 			=> t._("Address 2"),
			"zipCode" 			=> t._("Zip code"),
			"city" 				=> t._("City"),			
			"linkText" 			=> t._("Link text"),			
			"linkUrl" 			=> t._("Link URL"),			
			"companyNumber" 	=> "Numéro SIRET (14 chiffres)",	
		];
	}

	public function getAddress(){
		var str = new StringBuf();
		if(address1!=null) str.add(address1);
		if(address2!=null) str.add(", "+address2);
		if(zipCode!=null) str.add(", "+zipCode);
		if(city!=null) str.add(" "+city);
		if(country!=null) str.add(", "+country);
		return str.toString();
	}

	public function isDisabled(){
		return disabled!=null;
	}

	public function getDisabledReason():Null<String>{
		return switch(this.disabled){
			case null : null;
			case DisabledReason.IncompleteLegalInfos : "Informations légales incomplètes. Complétez vos informations légales pour débloquer le compte. (SIRET,capital social,numéro de TVA)";
			case DisabledReason.NotCompliantWithPolicy : "Producteur incompatible avec la charte producteur de CAMAP";
			case DisabledReason.Banned : "Producteur bloqué par les administrateurs";
		};
	}

	function check(){
		/*if(this.email==null){
			throw new tink.core.Error("Vous devez obligatoirement saisir un email pour ce producteur.");
		}*/

		if(this.email!=null && !EmailValidator.check(this.email) ) {
			throw new tink.core.Error('Email du producteur ${this.id} invalide.');
		}
	}

	override function insert(){
		check();
		super.insert();
	}
	
	override function update(){
		check();
		super.update();
	}

	public function getImageId(){
        return this.imageId;
    }

}