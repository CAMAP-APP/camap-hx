package db;
import sys.db.Object;
import sys.db.Types;
import db.Operation;
import Common;

@:enum
abstract BasketStatus(String) {
  var OPEN = "OPEN";
  var CONFIRMED = "CONFIRMED";
  var VALIDATED = "VALIDATED";
}

/**
 * Basket : represents the orders of a user for specific multidistrib
 */
// @:index(ref)
class Basket extends Object
{
	public var id : SId;
	// public var ref : SNull<SString<256>>; 	//basket unique ref, used also by tmpBasket
	public var cdate : SDateTime; 			//date when the order has been placed
	public var num : SInt;		 			//Basket number for distribution
	public var total : SFloat;				//orders total price for stats, !!! this is not reliable, dont use this for payments !!!
	public var status : SString<32>; 		//Mysql enum  OPEN , CONFIRMED , VALIDATED
	public var data : SText; //TmpBasketData; 

	@:relation(userId) public var user : SNull<db.User>;
	@:relation(multiDistribId) public var multiDistrib : db.MultiDistrib;

	public static var CACHE = new Map<String,db.Basket>();
	
	public function new(){
		super();
		cdate = Date.now();
	}

	public static function emptyCache(){
		CACHE = new Map<String,db.Basket>();
	}
	
	public static function get(user:db.User,distrib:db.MultiDistrib, ?lock = false):db.Basket{
		return manager.select($user==user && $multiDistrib==distrib,lock);
	}

	/*public static function get(user:db.User,md:db.MultiDistrib, ?lock = false):db.Basket{
		
		//date = tools.DateTool.setHourMinute(date, 0, 0);

		//caching
		 var k = user.id + "-" + place.id + "-" + date.toString().substr(0, 10);
		 var b = CACHE.get(k);
		var b = null;
		// if (b == null){
			//var md = db.MultiDistrib.get(date, place);
			if(md==null) return null;
			for( o in md.getUserOrders(user)){
				if(o.basket!=null) {
					b = o.basket;
					break;
				}
			}
			CACHE.set(k, b);
		 }
		
		return b;

	}*/

	
	/**
	 * Get a Basket or create it if it doesn't exists.
	 */
	public static function getOrCreate(user:db.User, multiDistrib:db.MultiDistrib){
		var b = get(user, multiDistrib, true);
			
		if (b == null || b.status == Std.string(OPEN)){
			//compute basket number
			b = new Basket();
			var max : Int = sys.db.Manager.cnx.request("select max(num) from Basket where multiDistribId="+multiDistrib.id).getIntResult(0);
			if( max < 0 ) max = 0;
			b.num = max + 1;
			b.multiDistrib = multiDistrib;
			b.user = user;
			b.status = Std.string(BasketStatus.CONFIRMED);
			b.insert();
		}

		return b;		
	}
	
	public function getUser():db.User{
		return this.user;
	}

	public function getDistribution():db.MultiDistrib{
		return this.multiDistrib;
	}
	
	/**
	 *  Get basket's orders
	 */
	public function getOrders(?type:Int):Array<db.UserOrder> {
		if(type==null){
			//get all orders
			return db.UserOrder.manager.search($basket == this, false).array();
		}else{
			//get CSA/variable orders 
			var out = new Array<db.UserOrder>();
			for( d in getDistribution().getDistributions(type)){
				out = out.concat( d.getUserOrders(this.user).array() );
			}
			return out;
		}		
	}

	/**
		get basket's orders for this distribution (one vendor)
	**/
	public function getDistributionOrders(d:db.Distribution):Array<db.UserOrder>{
		return db.UserOrder.manager.search($basket == this && $distribution==d, false).array();
	}
	
	/**
	 * Returns the list of operations which paid this basket
	 * @return
	 */
	public function getPaymentsOperations():Array<db.Operation> {
		
		var op = getOrderOperation(false);
		if (op == null){
			return [];
		}else{			
			return op.getRelatedPayments().array();
		}
	}

	/**
	 * Returns the total amount of payments
	 * @return Float
	 */
	public function getTotalPaid() : Float {
		var payments = getPaymentsOperations();
		var totalPaid = 0.0;

		//Let's sum up all the payments
		for( payment in payments ) {
			totalPaid += payment.amount;
		}
		return totalPaid;
	}

	/**
	 * Returns the total amount of all the orders in this basket
	 /!\ never forget to round each order line 
	 */
	public function getOrdersTotal(?type:Int) : Float {
		/*var total = 0.0;
		for( order in getOrders(type)){
			total += order.quantity * (order.productPrice * (1+order.feesRate/100));
		}
		return total;
		*/
		return getOrders(type).fold( 
			(order,total)-> {
				var a = order.quantity * (order.productPrice * (1+order.feesRate/100));
				//neko float bug
				a = Std.string(a).parseFloat();
				return total + Math.round(a*100)/100;
			}
		, 0.0);
	}
	
	/**
		Get order operation related to this basket
	**/
	public function getOrderOperation(?onlyPending=true):db.Operation {

		/* var order = Lambda.find(getOrders(),function(o) return o.distribution!=null );
        if(order==null) return null;*/

		// return service.PaymentService.findVOrderOperation(this.multiDistrib,this.user, onlyPending );

		if (onlyPending) {
			return db.Operation.manager.select($basket == this && $type == VOrder && $pending == true, true);
		} else {
			return db.Operation.manager.select($basket == this && $type == VOrder, true);
		}
	}
	
	public function isValidated() {

		/*var ordersPaid = Lambda.count(getOrders(), function(o) return !o.paid) == 0;
		var op = getOrderOperation(false);
		var orderOperationNotPending = op!=null ? op.pending == false : true;
		var paymentOperationsNotPending = Lambda.count(getPaymentsOperations(), function(p) return p.pending) == 0;

		return ordersPaid && orderOperationNotPending && paymentOperationsNotPending;			*/
		return status==Std.string(BasketStatus.VALIDATED);
	}

	public function getGroup() : db.Group {
		//return getOrders().first().distribution.catalog.group;
		return multiDistrib.group;
	}

	public function canBeValidated()
	{
		var t = sugoi.i18n.Locale.texts;
		var hasPendingOnTheSpotPayments = getPaymentsOperations().count( (op) -> return op.pending && op.getData().type == payment.OnTheSpotPayment.TYPE ) != 0;

		if (hasPendingOnTheSpotPayments){
			throw new tink.core.Error(t._("You need to select manually the type of pending payments on the spot to be able to validate this distribution."));
		}
		
		return !hasPendingOnTheSpotPayments;			
	}

	public function renumber(){
		this.lock();
		var max : Int = sys.db.Manager.cnx.request("select max(num) from Basket where multiDistribId="+this.multiDistrib.id).getIntResult(0);
		this.num = max + 1;
		this.update();
	}

	public function getData():TmpBasketData{
		try{
			return haxe.Json.parse(data);
		}catch(e:Dynamic){
			return {products:[]};
		}
		
	}

	public function setData(tmpBasketData: TmpBasketData){
		data = haxe.Json.stringify(tmpBasketData);
	}

	/**
		Get total amount to pay for this TMP basket
	**/
	public function getTmpTotal():Float{
		var total = 0.0;
		var data = this.getData();
		for( o in data.products){
			var p = db.Product.manager.get(o.productId,false);
			if(p==null) continue;
			total += o.quantity * p.getPrice();
		}
		return total;
	}

	public function getTmpOrders(){
		var out = new Array<{product:db.Product,quantity:Float}>();
		var data = this.getData();
		for( o in data.products){
			var p = db.Product.manager.get(o.productId,false);
			if(p==null) continue;
			out.push({product:p , quantity : o.quantity});
		}
		return out;
	}

}