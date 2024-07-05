package db;
import Common;
import sugoi.form.ListData;
import sys.db.Object;
import sys.db.Types;

/**
 * Distrib
 */
@:index(date,orderStartDate,orderEndDate)
class Distribution extends Object
{
	public var id : SId;	
	
	@hideInForms @:relation(catalogId) 	public var catalog : db.Catalog;
	@hideInForms @:relation(multiDistribId) public var multiDistrib : MultiDistrib;
	
	//deprecated
	@formPopulate("placePopulate") @:relation(placeId) public var place : Place;
	public var date : SNull<SDateTime>; 
	public var end : SNull<SDateTime>;
	
	//when orders are open
	@hideInForms public var orderStartDate : SDateTime; 
	@hideInForms public var orderEndDate : SDateTime; //cannot be null since CSA contracts also have orderEndDate
	
	// When recreating orders from this distrib, how many times the recurrent order must be created
	// Allows a distrib to be merged to another distrib while keeping the orders count
	@hideInForms public var quantities : Int = 1;
	
	public static var DISTRIBUTION_VALIDATION_LIMIT = 10;
	
	public function new() 
	{
		super();
		date = Date.now();
		end = DateTools.delta(date, 1000 * 60 * 90);

	}
	
	/**
	 * get group members list as form data
	 */
	public function distributorPopulate():FormData<Int> {
		if(App.current.user!=null && App.current.user.getGroup()!=null){
			return App.current.user.getGroup().getMembersFormElementData();				
		}else{
			return [];
		}
		
	}
	
	/**
	 * get groups places as form data
	 * @return
	 */
	public function placePopulate():FormData<Int> {
		var out = [];
		var places = new List();
		if(this.catalog!=null){
			//edit form
			places = db.Place.manager.search($groupId == this.catalog.group.id, false);
		}else{
			//insert form
			places = db.Place.manager.search($groupId == App.current.user.getGroup().id, false);
		}
		
		for (p in places) out.push( { label:p.name,value:p.id} );
		return out;
	}
	
	/**
	 * String to identify this distribution (debug use only)
	 */
	override public function toString() {
		return "#" + id + " Distribution du "+date.toString().substr(0,10)+" - " + catalog.name;		
	}
	
	public function getOrders() {
		return db.UserOrder.manager.search($distribution == this, false); 
	}

	/**
		Has user Orders in this distrib ?
	**/	
	public function hasUserOrders(user:db.User):Bool{
		return db.UserOrder.manager.select($distribution == this  && ($user==user || $user2==user), false) != null; 		
	}

	/**
		Get user orders
		This includes secondary user.
	**/
	public function getUserOrders(user:db.User):Array<db.UserOrder>{
		if( user == null || user.id == null ) throw new tink.core.Error( "user is null" );
		if ( this.catalog.type == db.Catalog.TYPE_CONSTORDERS){
		 	return db.UserOrder.manager.search($distribution == this  && ($user==user || $user2==user) , false).array(); 
		}else{
			return db.UserOrder.manager.search($distribution == this  && $user==user, false).array(); 
		}
	}
	
	public function getUsers():Iterable<db.User>{		
		return tools.ObjectListTool.deduplicate( Lambda.map(getOrders(), function(x) return x.user ) );		
	}

	/**
		get baskets implied in this distribution
	**/
	public function getBaskets(){
		var baskets = new Map<Int,db.Basket>();
		for( o in getOrders()){
			if(o.basket!=null) baskets.set(o.basket.id,o.basket);
		}
		return baskets.array();
	}

	
	/**
	 * Get TTC turnover for this distribution
	 */
	public function getTurnOver():Float{
		var products = catalog.getProducts(false);
		if(products.length==0) return 0.0;
		var sql = "select SUM(quantity * productPrice) from UserOrder  where productId IN (" + tools.ObjectListTool.getIds(products).join(",") +") ";
		// if (catalog.type == db.Catalog.TYPE_VARORDER) {
			sql += " and distributionId=" + this.id;	
		// }
	
		return sys.db.Manager.cnx.request(sql).getFloatResult(0);
	}
	
	/**
	 * Get HT turnover for this distribution
	 */
	public function getHTTurnOver(){
		
		var pids = tools.ObjectListTool.getIds(catalog.getProducts(false));
		
		var sql = "select SUM(uc.quantity *  (p.price/(1+p.vat/100)) ) from UserOrder uc, Product p ";
		sql += "where uc.productId IN (" + pids.join(",") +") ";
		sql += "and p.id=uc.productId ";
		
		if (catalog.type == db.Catalog.TYPE_VARORDER) {
			sql += " and uc.distributionId=" + this.id;	
		}
	
		return sys.db.Manager.cnx.request(sql).getFloatResult(0);
	}
	
	/**
	 * 
	 */
	public function canOrderNow() {
		
		if (orderEndDate == null) {
			return this.catalog.isUserOrderAvailable();
		}else {
			var n = Date.now().getTime();
			var f = this.catalog.flags.has(UsersCanOrder);
			
			return f && n < orderEndDate.getTime() && n > orderStartDate.getTime();
			
		}
	}

	override public function update(){
		if(this.date!=null){
			this.end = new Date(this.date.getFullYear(), this.date.getMonth(), this.date.getDate(), this.end.getHours(), this.end.getMinutes(), 0);
		}
		
		super.update();
	}

	public function getInfos():DistributionInfos{
		return {
			id:id,
			groupId		: place.group.id,
			groupName 	: place.group.name,
			vendorId				: this.catalog.vendor.id,
			distributionStartDate	: date==null ? multiDistrib.distribStartDate : date,
			distributionEndDate		: end==null ? multiDistrib.distribEndDate : end,
			orderStartDate			: orderStartDate==null ? this.catalog.startDate : orderStartDate,
			orderEndDate			: orderEndDate, //never null
			place 					: multiDistrib.place.getInfos()
		};
	}

	/**
		Trick for retrocompat with code made before Multidistrib entity (2019-04)
	**/
	public function populate(){
		date =  date==null ? multiDistrib.distribStartDate : date;
		end  =  end==null ? multiDistrib.distribEndDate : end;
		orderStartDate = orderStartDate==null ? multiDistrib.orderStartDate : orderStartDate;
		orderEndDate = orderEndDate==null ? multiDistrib.orderEndDate : orderEndDate;
		place = null;

	}
	
	/**
	 * Return a string like $placeId-$date.
	 * 
	 * It's an ID representing all the distributions happening on that day at that place.
	 */
	public function getKey():String{
		return db.Distribution.makeKey(this.date, this.place);
	}
	
	public static function makeKey(date, place){
		return date.toString().substr(0, 10) +"|"+Std.string(place.id);
	}	

	
	public static function getLabels(){
		var t = sugoi.i18n.Locale.texts;
		return [
			"date" 				=> t._("Date"),
			"endDate" 			=> t._("End hour"),
			"place" 			=> t._("Place"),
			"distributor1" 		=> t._("Distributor #1"),
			"distributor2" 		=> t._("Distributor #2"),
			"distributor3" 		=> t._("Distributor #3"),
			"distributor4" 		=> t._("Distributor #4"),
		];
	}


}