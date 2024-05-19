package db;
import sys.db.Object;
import sys.db.Types;
import Common;
using tools.ObjectListTool;
using Lambda;
import haxe.Json;
import db.Basket.BasketStatus;


/**
 * MultiDistrib represents a global distributions with many vendors. 	
 * @author fbarbut
 */
@:index(distribStartDate)
class MultiDistrib extends Object
{
	public var id : SId;
	
	public var distribStartDate : SDateTime; 
	public var distribEndDate : SDateTime;	
	public var orderStartDate : SDateTime; 
	public var orderEndDate : SDateTime;

	@hideInForms @:relation(groupId) public var group : db.Group;
	@formPopulate("placePopulate") @:relation(placeId) public var place : Place;
	@hideInForms @:relation(distributionCycleId) public var distributionCycle : SNull<DistributionCycle>;

	@hideInForms public var volunteerRolesIds : SNull<String>;

	@:skip public var contracts : Array<db.Catalog>;
	@:skip public var extraHtml : String;
	
	public function new(){
		super();
		contracts = [];
		extraHtml = "";
	}
	
	/**
		Get a distribution for date + place.
	**/
	public static function get(date:Date, place:db.Place, ?lock=false){
		var start = tools.DateTool.setHourMinute(date, 0, 0);
		var end = tools.DateTool.setHourMinute(date, 23, 59);

		return db.MultiDistrib.manager.select($distribStartDate>=start && $distribStartDate<=end && $place==place,lock);
	}

	public static function getFromTimeRange( group: db.Group, from: Date, to: Date ) : Array<MultiDistrib> {

		var multidistribs = new Array<db.MultiDistrib>();
		var start = tools.DateTool.setHourMinute(from, 0, 0);
		var end = tools.DateTool.setHourMinute(to, 23, 59);
		
		multidistribs = Lambda.array(db.MultiDistrib.manager.search( $group == group && $distribStartDate >= start && $distribStartDate < end, false ));
		
		//sort by date desc
		multidistribs.sort(function(x,y){
			return Math.round( x.getDate().getTime()/1000 ) - Math.round(y.getDate().getTime()/1000 );
		});

		//trigger event
		for(md in multidistribs) {
			md.useCache = true;
			App.current.event(GetMultiDistrib(md));
		}

		return multidistribs;
	}

	public static function getNextMultiDistrib(group: db.Group) : MultiDistrib {

		var multidistribs = new Array<db.MultiDistrib>();
		var now = Date.now();
		var now = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
		var twoMonths = new Date(now.getFullYear(), now.getMonth()+2, now.getDate(), 0, 0, 0);
		
		multidistribs = Lambda.array(db.MultiDistrib.manager.search( $group == group && $distribStartDate >= now && $distribStartDate < twoMonths, { orderBy: distribStartDate, limit: 1 } ));

		return multidistribs.length > 0 ? multidistribs[0] : null;
	}

	public function getPlace(){
		return place;
	}

	public function getDate(){
		return distribStartDate;
	}

	public function getEndDate(){
		return distribEndDate;
	}

	/**
		prepare an excerpt of products ( and store it in cache )
	**/
	static var PRODUCT_EXCERPT_KEY = "productsExcerpt";

	public function getProductsExcerpt(productNum:Int):Array<{name:String,image:String}>{
		var key = PRODUCT_EXCERPT_KEY+this.id;
		var cache:Array<{rid:Int,name:String,image:String}> = sugoi.db.Cache.get(key);
		if(cache!=null){
			return cache;
		}else{
			cache = [];
			for( d in getDistributions(db.Catalog.TYPE_VARORDER)){
				for ( p in d.catalog.getProductsPreview(productNum)){
					cache.push( {
						rid : p.image!=null ? Std.random(500)+500 : Std.random(500),
						name:p.name,
						image:p.getImage()
					} );	
				}
			}

			//randomize
			cache.sort(function(a,b){
				return b.rid - a.rid;
			});
			cache = cache.slice(0, productNum);

			sugoi.db.Cache.set(key, cache , 3600*12 );
			return cache;	
		}

	}

	public function deleteProductsExcerpt(){
		sugoi.db.Cache.destroy(PRODUCT_EXCERPT_KEY+this.id);
	}

	public function userHasOrders(user:db.User,type:Int):Bool{
		if(user==null) return false;
		for ( d in getDistributions(type)){
			if(d.hasUserOrders(user)) return true;						
		}
		return false;
	}
	
	/**
		Are orders currently open ?
		( including exceptions )
	**/
	public function isActive(){

		if (getOrdersStartDate() == null) return false; //constant orders
			
		var now = Date.now();	
		if (now.getTime() >= getOrdersStartDate(true).getTime()  && now.getTime() <= getOrdersEndDate(true).getTime() ){			
			return true;				
		}else {
			return false;				
		}
	}

	public function getOrdersStartDate(?includingExceptions=false){
		if(includingExceptions){
			if(orderStartDate==null) return null;
			//find earliest order start date 
			var date = orderStartDate;
			for(d in getDistributions(db.Catalog.TYPE_VARORDER)){
				if(d.orderStartDate==null) continue;
				if(d.orderStartDate.getTime() < date.getTime()) date = d.orderStartDate;
			}
			return date;
		}else{
			return orderStartDate;
		}
		
	}

	public function getOrdersEndDate(?includingExceptions=false){
		if(includingExceptions){
			if(orderEndDate==null) return null;
			//find lates order end date 
			var date = orderEndDate;
			for(d in getDistributions(db.Catalog.TYPE_VARORDER)){
				if(d.orderEndDate==null) continue;
				if(d.orderEndDate.getTime() > date.getTime()) date = d.orderEndDate;
			}
			return date;
		}else{
			return orderEndDate;
		}
		
	}

	/**
		Get distributions for constant orders or variable orders.
	**/
	@:skip private var distributionsCache:Array<db.Distribution>;
	@:skip public var useCache:Bool;
	public function getDistributions(?type:Int){
		
		if(distributionsCache==null || !useCache){
			distributionsCache = db.Distribution.manager.search($multiDistrib==this,false).array();
		}

		if(type==null){
			return distributionsCache;
		}else{
			var out = [];
			for ( d in distributionsCache){
				if( d.catalog.type==type ) out.push(d);
			}
			return out;
		} 
		
	}

	public function getDistributionForContract(contract:db.Catalog):db.Distribution{
		for( d in getDistributions()){
			if(d.catalog.id == contract.id) return d;
		}
		return null;
	}

	/**
	 * Get all orders involved in this multidistrib
	 */
	public function getOrders(?type:Int){
		var out = [];
		for ( d in getDistributions(type)){
			out = out.concat(d.getOrders().array());
		}
		return out;		
	}

	/**
	 * Get orders for a user in this multidistrib
	 * @param user 
	 */
	public function getUserOrders(user:db.User,?type:Int){
		var out = [];
		for ( d in getDistributions(type) ){
			var pids = d.catalog.getProducts(false).map(x->x.id);		
			var userOrders =  db.UserOrder.manager.search( $userId == user.id && $distributionId==d.id && $productId in pids , false);	
			for( o in userOrders ){
				out.push(o);
			}
		}
		return out;		
	}

	public function getVendors():Array<db.Vendor>{
		var vendors = new Map<Int,db.Vendor>();
		for( d in getDistributions()) vendors.set(d.catalog.vendor.id,d.catalog.vendor);
		return vendors.array();
	}
	
	public function getUsers(?type:Int){
		var users = [];
		for ( o in getOrders(type)) users.push(o.user);
		return users.deduplicate();		
	}

	public function getState():String{
		var now = Date.now().getTime();
		if(getOrdersStartDate()==null || getOrdersEndDate()==null) return null;
		
		if( getDate().getTime() > now ){
			//we're before distrib

			if( getOrdersStartDate(true).getTime() > now ){
				return "notYetOpen";
			}
			
			if( getOrdersEndDate(true).getTime() > now ){
				return "open";
			}else{
				return "closed";
			}
		}else{
			//after distrib
			return "distributed";			
		}
	}

	public function getStatus(){
		return getState();
	}
	
	/**
		retrocomp
	**/
	public function getKey(){
		return "md"+this.id;
	}

	override public function toString(){
		try{
			return "#"+id+" Multidistrib à "+getPlace().name+" le "+getDate();
		}catch(e:Dynamic){
			return "#"+this.id;
		}
		
	}

	public function placePopulate():sugoi.form.ListData.FormData<Int> {
		var out = [];
		var places = new List();
		if(this.place!=null){			
			places = db.Place.manager.search($groupId == this.place.group.id, false);
		}
		for (p in places) out.push( { label:p.name,value:p.id} );
		return out;
	}

	public static function getLabels(){
		var t = sugoi.i18n.Locale.texts;
		return [
			"distribStartDate"	=> t._("Date"),
			"distribEndDate"	=> t._("End hour"),
			"place" 			=> t._("Place"),
			"orderStartDate" 	=> t._("Orders opening date"),
			"orderEndDate" 		=> t._("Orders closing date"),
		];
	}

	public function getGroup(){
		return group;
	}

	/**
		get non open baskets
	**/
	public function getBaskets():Array<db.Basket>{
		var baskets = db.Basket.manager.search($multiDistrib==this && $status!=Std.string(BasketStatus.OPEN),false).array();

		//sort by user lastname
		baskets.sort((a,b)-> {
			if(a.user==null || b.user==null) return -1;
			return a.user.lastName > b.user.lastName ? 1 : -1 ;
		});

		return baskets;
	}

	/**
		get open baskets
	**/
	public function getTmpBaskets():Array<db.Basket>{
		return db.Basket.manager.search($multiDistrib==this && $status==Std.string(BasketStatus.OPEN),false).array();
	}

	public function getUserBasket(user:db.User){
		var orders = getUserOrders(user);
		for( o in orders ){
			if(o.basket!=null) return o.basket;
		}
		return null;
	}

	/**
		get user open basket
	**/
	public function getUserTmpBasket(user:db.User):db.Basket{
		return db.Basket.manager.select($multiDistrib==this && $user==user && $status==Std.string(BasketStatus.OPEN),false);
	}

	/**
		Get total income of the md, variable and constant
	**/
	public function getTotalIncome():Float{
		var income = 0.0;
		
		for( d in getDistributions()){
			income += d.getTurnOver();
		}

		return income;
	}


	public function getVolunteerRoles() {
		var roleIds = [];
		roleIds = getVolunteerRoleIds();
		if(roleIds.length==0) return [];
		var volunteerRoles = db.VolunteerRole.manager.search($id in roleIds,false).array();

		/*for ( roleId in  ) {
			var volunteerRole = db.VolunteerRole.manager.get(roleId,false);
			if ( volunteerRole != null ) {
				volunteerRoles.push( volunteerRole );
			}
		}*/

		volunteerRoles.sort(function(b, a) { 
			var a_str = (a.catalog == null ? "null" : Std.string(a.catalog.id)) + a.name.toLowerCase();
			var b_str = (b.catalog == null ? "null" : Std.string(b.catalog.id)) + b.name.toLowerCase();
			return  a_str < b_str ? 1 : -1;
		});

		
		return volunteerRoles;
	}

	
	public function getVolunteerRoleIds():Array<Int>{
		if(volunteerRolesIds==null) return [];
		var rolesIds = volunteerRolesIds.split(",").map(Std.parseInt);
		rolesIds = tools.ArrayTool.deduplicate(rolesIds);
		rolesIds = rolesIds.filter( rid -> rid!=null);
		return rolesIds;
	}

	@:skip private var volunteersCache:Array<db.Volunteer>;
	
	public function getVolunteers() {
		if(!useCache || volunteersCache==null){
			volunteersCache = db.Volunteer.manager.search($multiDistrib == this, false).array();
		}
		return volunteersCache;
	}

	public function hasVacantVolunteerRoles() {

		if ( this.volunteerRolesIds != null && canVolunteersJoin() ) {
			var volunteerRoles = this.getVolunteerRoles();
			if ( volunteerRoles != null && volunteerRoles.length > db.Volunteer.manager.count($multiDistrib == this) ) {
				return true;
			} 
		}
		return false;
	}

	public function getVacantVolunteerRoles():Array<db.VolunteerRole> {

		if (hasVacantVolunteerRoles()) {
			var volunteers = getVolunteers();
			var vacantVolunteerRoles = getVolunteerRoles();

			for ( volunteer in volunteers ) {
				vacantVolunteerRoles.remove(volunteer.volunteerRole);
			}
			vacantVolunteerRoles.sort(function(b, a) { return a.name.toLowerCase() < b.name.toLowerCase() ? 1 : -1; });
			return vacantVolunteerRoles;
		}

		return [];
	}

	public function hasVolunteerRole(role: db.VolunteerRole) {
		var volunteerRoles: Array<db.VolunteerRole> = getVolunteerRoles();
		if (volunteerRoles == null) return false;
		return Lambda.has(volunteerRoles, role);
	}

	public function getVolunteerForRole(role: db.VolunteerRole) {
		return db.Volunteer.manager.select($multiDistrib == this && $volunteerRole == role, false);
	}

	public function getVolunteerForUser(user: db.User): Array<db.Volunteer> {
		return Lambda.array(db.Volunteer.manager.search($multiDistrib == this && $user == user, false));
	}
	
	/**
		Can volunteers join ( check on date and daysBeforeDutyPeriodsOpen )
	**/
	public function canVolunteersJoin() {
		var joinDate = DateTools.delta( this.distribStartDate, - 1000.0 * 60 * 60 * 24 * this.group.daysBeforeDutyPeriodsOpen );
		return Date.now().getTime() >= joinDate.getTime();		
	}

	public function getDistributionFromProduct(product:db.Product):db.Distribution{
		for( d in getDistributions()){
			for( p in d.catalog.getProducts(false)){
				if(p.id==product.id) return d;
			}
		}
		return null;
	}

}