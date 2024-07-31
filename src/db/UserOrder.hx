package db;
import sys.db.Object;
import sys.db.Types;
import Common;

/**
 * a product order 
 */
class UserOrder extends Object
{
	public var id : SId;
	
	@formPopulate("populate") @:relation(userId)
	public var user : User;
	
	//shared order
	@formPopulate("populate") @:relation(userId2)
	public var user2 : SNull<User>;
	
	public var quantity : SFloat;
	
	@formPopulate("populateProducts") @:relation(productId)
	public var product : Product;
	
	//store price (1 unit price without fees) and fees (percentage not amount) rate when the order is done
	public var productPrice : SFloat;
	public var feesRate : SFloat; //fees in percentage
	
	public var paid : SBool;
	
	@:relation(distributionId)
	public var distribution:db.Distribution;
	
	@:relation(basketId)
	public var basket:db.Basket;

	@:relation(subscriptionId)
	public var subscription : SNull<db.Subscription>;
	
	public var date : SDateTime;	
	public var flags : SFlags<OrderFlags>;
	
	public function new() 
	{
		super();
		quantity = 1;
		paid = false;
		date = Date.now();
		flags = cast 0;
		feesRate = 0;
	}
	
	public function populate() {
		return App.current.user.getGroup().getMembersFormElementData();
	}
	
	
	/**
	 * For shared alternated orders in AMAP contracts
	 * @param	distrib
	 * @return	false -> user , true -> user2
	 */
	public function getWhosTurn(distrib:Distribution) {
		if (distrib == null) throw "distribution is null";
		if (user2 == null) throw "this contract is not shared";
		
		//compter le nbre de distrib pour ce contrat
		var c = Distribution.manager.count( $catalog == product.catalog && $date >= product.catalog.startDate && $date <= distrib.date);		
		var r = c % 2 == 0;
		if (flags.has(InvertSharedOrder)){
			return !r;
		}else{
			return r;
		}
	}
	
	override public function toString() {
		if(product==null) return quantity +"x produit inconnu";
		return user.getName()+" : "+tools.FloatTool.clean(quantity) + " x " + product.getName();
	}
	
	public function hasInvertSharedOrder():Bool{
		return flags.has(InvertSharedOrder);
	}

	/**
	 * On peut modifier si ça na pas deja été payé + commande encore ouvertes
	 */
	public function canModify():Bool {
	
		var can = false;
		if (this.product.catalog.type == db.Catalog.TYPE_VARORDER) {
			if(this.distribution==null) return false;
			if (this.distribution.orderStartDate == null) {
				can = true;
			}else {
				var n = Date.now().getTime();
				can = n > this.distribution.orderStartDate.getTime() && n < this.distribution.orderEndDate.getTime();
			}
		}else {
			can = this.product.catalog.isUserOrderAvailable();
		}
		
		return can && !this.paid;
	}
	
	function check(){
		if(quantity==null) quantity == 1;
	}

	override function update(){
		check();
		super.update();
	}

	override function insert(){
		check();
		super.insert();
	}
}
