package db;
import sys.db.Object;
import sys.db.Types;
import Common;
using tools.FloatTool;

/**
 * Product
 */
class Product extends Object
{
	public var id : SId;
	public var name : SString<128>;	
	public var ref : SNull<SString<32>>;	//référence produit
	
	@hideInForms  @:relation(catalogId) public var catalog : db.Catalog;
	
	//prix TTC
	public var price : SFloat;
	public var vat : SFloat;			//VAT rate in percent
	
	public var desc : SNull<SText>;
	public var stock : SNull<SFloat>; //if qantity can be float, stock should be float
	public var stockTracking : SEnum<StockTracking>;
	public var stockTrackingPerDistrib : SEnum<StockTrackingPerDistribution>; // if "stockTracking" is "PerDistribution", stockTrackingPerDistrib is the rule to use.
	
	public var unitType : SNull<SEnum<Unit>>; // Kg / L / g / units
	public var qt : SNull<SFloat>;
	
	public var organic : SBool;
	public var variablePrice : Bool; 	//price can vary depending on weighting of the product
	public var multiWeight : Bool;		//product cannot be cumulated in one order record
	public var bulk : Bool;		//(vrac) warn the customer this product is not packaged
	
	@hideInForms @:relation(imageId) public var image : SNull<sugoi.db.File>;
	
	public var active : SBool; 	//if false, product disabled, not visible on front office
	
	
	public function new() 
	{
		super();
		organic = false;
		active = true;
		variablePrice = false;
		multiWeight = false;
		bulk = false;
		vat = 5.5;
		unitType = Unit.Piece;
		qt = 1;
		
	}

	public function getAvailableStock(nextDistribId:Null<SId>, ignoreOrderId:Null<SId> = null):Float {
		if (this.stock == null || !this.hasStockTracking()) return null;

		var existingOrders:List<db.UserOrder>;
		if (this.stockTracking == StockTracking.PerDistribution && nextDistribId != null) {
			if (ignoreOrderId != null) {
				existingOrders = db.UserOrder.manager.search($productId==this.id && $distributionId==nextDistribId && $id!=ignoreOrderId && $quantity>0, true);
			} else {
				existingOrders = db.UserOrder.manager.search($productId==this.id && $distributionId==nextDistribId && $quantity>0, true);
			}
			
		} else if (this.stockTracking == StockTracking.Global) {
			if (ignoreOrderId != null) {
				existingOrders = db.UserOrder.manager.search($productId==this.id && $id!=ignoreOrderId && $quantity>0, true);
			} else {
				existingOrders = db.UserOrder.manager.search($productId==this.id && $quantity>0, true);
			}
			
		} else {
			existingOrders = new List<db.UserOrder>();
		}
		var totOrdersQt : Float = 0;
		for (order in existingOrders) {
			// if multiWeight, the exact weight does not matters, only the item count and there can be only 1 per line
			// also the stock for multiweight products is the number of products, not the quantité
			totOrdersQt += this.multiWeight ? 1 : order.quantity;
		}
		// Stock dispo = stock - commandes en cours ou terminées
		var availableStock = this.stock - totOrdersQt;
		if (availableStock < 0) availableStock = 0;
		return availableStock.clean();
	}

	public function hasStockTracking():Bool {
		return this.stockTracking != StockTracking.Disabled && this.stockTracking != null;
	}
	
	/**
	 * Returns product image URL
	 */
	public function getImage() {
		if (imageId == null) {
			return "/img/taxo/grey/legumes.png";
		}else {
			return App.current.view.file(imageId);
		}
	}
	
	public function getName(){	
		if (unitType != null && qt != null && qt != 0){
			return name +" " + qt + " " + Formatting.unit(unitType);
		}else{
			return name;
		}
	}
	
	override function toString() {
		return getName();
	}
	
	/**
	 * get price including margins
	 */
	public function getPrice():Float{
		return (price + catalog.computeFees(price)).clean();
	}
	
	/**
	   get product infos as an anonymous object 
	   @param	CategFromTaxo=false
	   @param	populateCategories=tru
	   @return
	**/
	public function infos(?categFromTaxo=false,?populateCategories=true,?distribution:db.Distribution):ProductInfo {
		var o :ProductInfo = {
			id : id,
			ref : ref,
			name : name,
			image : getImage(),
			price : getPrice(),
			vat : vat,
			vatValue: (vat != 0 && vat != null) ? (  this.price - (this.price / (vat/100+1))  )  : null,
			catalogTax : catalog.percentageValue,
			catalogTaxName : catalog.percentageName,
			desc : App.current.view.nl2br(desc),
			orderable : this.catalog.isUserOrderAvailable(),
			stock : catalog.hasStockManagement() ? this.stock : null,
			qt:qt,
			unitType:unitType,
			organic:organic,
			variablePrice:variablePrice,
			bulk:bulk,
			active: active,
			distributionId : distribution==null ? null : distribution.id,
			catalogId : catalog.id,
			vendorId : catalog.vendor.id,
			multiWeight : multiWeight,
		}
		
		App.current.event(ProductInfosEvent(o,distribution));
		
		return o;
	}
	
	/**
	 * customs categs
	 */
	// public function getCategories() {		
	// 	//"Types de produits" categGroup first
	// 	//var pc = db.ProductCategory.manager.search($productId == id, {orderBy:categoryId}, false);		
	// 	return Lambda.map(db.ProductCategory.manager.search($productId == id,{orderBy:categoryId},false), function(x) return x.category);
	// }
	
	public static function getByRef(c:db.Catalog, ref:String){
		var pids = tools.ObjectListTool.getIds(c.getProducts(false));
		return db.Product.manager.select($ref == ref && $id in pids, false);
	}

	function check(){		
		//Fix values that will make mysql 5.7 scream
		if(this.vat==null) this.vat=0;
		if(this.name.length>128) this.name = this.name.substr(0,128);
		if(qt==0.0) qt = null;

		//remove strange characters
		for( s in ["",""]){
			if(name!=null) name = StringTools.replace(name,s,"");
			if(desc!=null) desc = StringTools.replace(desc,s,"");
		}
		
		//round like 0.00
		price = Formatting.roundTo(price,2);

		//Only Integers are allowed for consumers and float for coordinators
		/* Permettre la multipesée seule
		if( this.multiWeight ) {
			this.variablePrice = true;
		}
		*/
	}

	override public function update(){
		check();
		super.update();
	}

	override public function insert(){
		check();
		super.insert();
	}

	public static function getLabels(){
		var t = sugoi.i18n.Locale.texts;
		return [
			"name" 					=> t._("Product name"),
			"ref" 					=> t._("Product ID"),
			"price" 				=> t._("Price"),
			"desc" 					=> t._("Description"),
			"stock" 				=> t._("Stock"),
			"unitType" 				=> t._("Base unit"),
			"qt" 					=> t._("Quantity"),			
			"hasFloatQt" 			=> t._("Allow fractional quantities"),			
			"active" 				=> t._("Available"),			
			"organic" 				=> t._("Organic agriculture"),			
			"vat" 					=> t._("VAT Rate"),			
			"variablePrice"			=> t._("Variable price based on weight"),			
			"multiWeight" 			=> t._("Multi-weighing"),	
			"bulk" 					=> "Vrac",
			"stockTracking" 		=> t._("Stock tracking"),
			"stockTrackingPerDistrib" => t._("Stock per distribution configuration"),
		];
	}
	
}

