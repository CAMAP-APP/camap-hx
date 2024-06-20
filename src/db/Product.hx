package db;
import thx.Error;
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
	public var qt : SNull<SFloat>;
	public var unitType : SNull<SEnum<Unit>>; // Kg / L / g / units

	public var stockTracking : SEnum<StockTracking>;
	public var stockTrackingPerDistrib : SEnum<StockTrackingPerDistribution>; // if "stockTracking" is "PerDistribution", stockTrackingPerDistrib is the rule to use.
	public var stock : SNull<SFloat>; //if qantity can be float, stock should be float
	
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
	
	/**
	 * get distribution stocks
	 * @param	onlyActive = true
	 */
	 public function getDistributionsStocks():List<ProductDistributionStock> {
		return ProductDistributionStock.manager.search($product==this, false);
	}

		/**
	 * Get remaining stocks for a specific distrib. = product stock - current orders.
	 * 4 cases are handled:
	 * - global stock. 
	 * 		- Value: this.stock holds the stock value for ALL distributions.
	 * 		- Orders: all orders are taken into account to decrement stock.
	 * - per distribution stock - AlwaysTheSame. 
	 * 		- Value: this.stock holds the stock value for EACH distribution.
	 * 		- Orders: only the orders of the considerer discribution are decremented.
	 * - per distribution stock - FrequencyBased. 
	 * 		- Value: the associated ProductDistributionStock.stockPerDistribution holds the stock value for CONFIGURED distributions and the configuration.
	 * 		- Orders: only the orders of the considerer distribution are decremented
	 * - per distribution stock - PerPeriod. 
	 * 		- Value: the first ProductDistributionStock.stockPerDistribution that encapsulate the nextDistribId.
	 * 		- Orders: only the orders of the considerer distribution are decremented.
	 * @param nextDistribId The distrib we want to check the stock for
	 * @param ignoreOrderId We might want to ignore the order we are currently calculating. Ignores a specific order in the calcultion
	 * @param alwaysPositive = true By default, the return value is >=0. alwaysPositive at false will gives how much stock is missing to match the current orders as a negative value.
	 * @return Float
	 */
	 public function getDistribStock(nextDistribId:Null<SId>):Float {
		if (!this.hasStockTracking()) return null;
		if (nextDistribId == null) throw new Error('Product.getDistribStock expects an existing nextDistribId.');

		// calcul du stock pour la période (global ou distribution)
		var periodStock = this.stock;

		if (this.stockTracking == StockTracking.PerDistribution && this.stockTrackingPerDistrib == StockTrackingPerDistribution.FrequencyBased) {
			var pdsResult = ProductDistributionStock.manager.search($productId==this.id);
			if (pdsResult.length > 0) {
				var pds = pdsResult.first();
				var distribs:List<Distribution> = Distribution.manager.search( $catalog == this.catalog && $date >= pds.startDistribution.date, { orderBy:date,limit:999 } ,false);
				var index = distribs.map(d -> d.id).indexOf(nextDistribId);
				 // ie. 7th distribution on a "1/3" frequency ratio will have the following calculation:
				 // expected distribs with stock: 1 0 0 1 0 0 1 0 0… (have stock (=1) each 3 distribs)
				 //                        index: 0 1 2 3 4 5 6 7 8…
				 // index of 7th distribution = 6 (indexes starts at 0)
				 // pds.frequencyRatio = 3 (1/3 is represented as "3" in database)
				 // 6 % 3 == 0 is true, stocks should be considered available for the 7th distribution
				var hasStock = (index % pds.frequencyRatio) == 0;
				periodStock = hasStock ? pds.stockPerDistribution : 0;
			} else {
				// The product might be in creation and the stockTracking not configured yet. Consider 0 stock in this case.
				periodStock = 0;
			}
		}

		if (this.stockTracking == StockTracking.PerDistribution && this.stockTrackingPerDistrib == StockTrackingPerDistribution.PerPeriod) {
			var distrib = Distribution.manager.get(nextDistribId);
			if (distrib.date == null) throw new Error('Distrib ${nextDistribId} doesnt have a date setup. Please fix date so the distrib has a date.');
			var periods = ProductDistributionStock.manager.search($productId==this.id);
			periods = periods.filter(function (period:ProductDistributionStock) {
				if (period.startDistribution == null || period.endDistribution == null) throw new Error('Configured period ${period.id} is missing start or end date. Ensure all ProductDistributionStock have dates.');
				var periodStart = period.startDistribution.date;
				var periodEnd = period.endDistribution.date;
				return periodStart.getTime() <= distrib.date.getTime() && distrib.date.getTime() <= periodEnd.getTime();
			});
			if (periods.length > 0) {
				periodStock = periods.first().stockPerDistribution;
			} else {
				periodStock = 0;
			}
		}

		return periodStock;
	}

	/**
	 * Get remaining stocks for a specific distrib. = product stock - current orders.
	 * 4 cases are handled:
	 * - global stock. 
	 * 		- Value: this.stock holds the stock value for ALL distributions.
	 * 		- Orders: all orders are taken into account to decrement stock.
	 * - per distribution stock - AlwaysTheSame. 
	 * 		- Value: this.stock holds the stock value for EACH distribution.
	 * 		- Orders: only the orders of the considerer discribution are decremented.
	 * - per distribution stock - FrequencyBased. 
	 * 		- Value: the associated ProductDistributionStock.stockPerDistribution holds the stock value for CONFIGURED distributions and the configuration.
	 * 		- Orders: only the orders of the considerer distribution are decremented
	 * - per distribution stock - PerPeriod. 
	 * 		- Value: the first ProductDistributionStock.stockPerDistribution that encapsulate the nextDistribId.
	 * 		- Orders: only the orders of the considerer distribution are decremented.
	 * @param nextDistribId The distrib we want to check the stock for
	 * @param ignoreOrderId We might want to ignore the order we are currently calculating. Ignores a specific order in the calcultion
	 * @param alwaysPositive = true By default, the return value is >=0. alwaysPositive at false will gives how much stock is missing to match the current orders as a negative value.
	 * @return Float
	 */
	public function getAvailableStock(nextDistribId:Null<SId>, ignoreOrderId:Null<SId> = null, alwaysPositive = true):Float {
		if (this.stock == null || !this.hasStockTracking()) return null;
		if (nextDistribId == null) throw new Error('Product.getAvailableStock expects an existing nextDistribId.');

		var existingOrders:List<db.UserOrder>;
		if (this.stockTracking == StockTracking.PerDistribution) {
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

		// calcul du stock pour la période (global ou distribution)
		var distribStock = this.getDistribStock(nextDistribId);

		// Stock dispo = stock - commandes en cours ou terminées
		var availableStock = distribStock - totOrdersQt;
		if (alwaysPositive && availableStock < 0) availableStock = 0;
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

