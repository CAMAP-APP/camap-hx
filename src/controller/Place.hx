package controller;
import sugoi.form.Form;

/**
 *  Place controller
 */
class Place extends Controller
{

	public function new()
	{
		super();
		addBc('amapadmin',"Admin","amapadmin");
		addBc('places',"Lieux","place");
	}

	@tpl('amapadmin/places.mtt')
	function doDefault(){
		view.places = app.getCurrentGroup().getPlaces();
		checkToken();
		
	}
	
	@tpl('place/view.mtt')
	function doView(place:db.Place) {
		view.place = place;
		
		//build adress for google maps
		var addr = "";
		if (place.address1 != null) addr += place.address1;
		if (place.address2 != null) addr += ", " + place.address2;
		if (place.zipCode != null) addr += " " + place.zipCode;
		if (place.city != null) addr += " " + place.city;
	
		view.addr = view.escapeJS(addr);
	}
	
	@tpl('amapadmin/form.mtt')
	function doEdit(p:db.Place) {
		
		var currentAddress = p.getAddress();

		var f = form.CamapForm.fromSpod(p);
		f.addElement(new sugoi.form.elements.StringSelect('country',t._("Country"),db.Place.getCountries(),p.country,true));
			
		if (f.isValid()) {
		
			f.toSpod(p); 

			if(currentAddress!=p.getAddress() || p.lat==null){
				try{
					service.PlaceService.geocode(p);
				}catch(e:Dynamic){
					App.current.session.addMessage(t._("Oops, we're unable to find where is located this address. This place will not be shown on the map.")+'<br/>$e',true);
				}
			}

			p.update();
			throw Ok('/place',t._("this place has been updated"));
		}
		
		view.form = f;
		view.title = t._("Edit a place");
	}
	
	@tpl("amapadmin/form.mtt")
	public function doInsert() {
		
		var d = new db.Place();
		var f = form.CamapForm.fromSpod(d);
		f.addElement(new sugoi.form.elements.StringSelect('country',t._("Country"),db.Place.getCountries(),"FR",true));
		
		if (f.isValid()) {
			var country = f.getValueOf('country');
			if(country!="FR" && country!="BE"){
				throw Error("/place/insert","Seules les adresses en France et en Belgique sont autorisées");
			}

			f.toSpod(d); 
			d.group = app.user.getGroup();
			d.insert();
			throw Ok('/place',t._("The place has been registred") );
		}
		
		view.form = f;
		view.title = t._("Register a new delivery place");
	}
	
	public function doDelete(p:db.Place) {
		if (!app.user.isAmapManager()) throw "forbidden";
		if (checkToken()) {
			
			if (db.Distribution.manager.search($placeId == p.id).length > 0) 
				throw Error('/contractAdmin', t._("You can't delete this place because one or more distributions are linked to this place.") );
			
			p.lock();
			p.delete();
			throw Ok("/place", t._("Place deleted") );
		}
		
	}
}