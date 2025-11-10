
#if sys
typedef Right = db.UserGroup.Right;
#end

//OrderInSession v2 for db.TmpBasket
typedef TmpBasketData = {
	products:Array <{
		productId:Int,
		quantity:Float,
	}> ,		
}

@:keep
typedef VendorInfos = {
	id 		: Int,
	name 	: String,
	desc 	: String,
	longDesc: String,
	image 	: String, // logo
	profession: String,
	phone: String,
	address1: String,
	address2: String,
	zipCode: String,
	city: String,
	email: String,
	linkText: String,
	linkUrl: String,
	lat: Float,
	lng: Float,
}

typedef ContractInfo = {
	id:Int,
	name:String,
	image:Null<String>

}

typedef GroupInfo = {
	id : Int,
	name : String,
}

@:keep
typedef ProductInfo = {
	id : Int,
	name : String,
	ref : Null<String>,
	image : Null<String>,	
	price : Float,
	vat : Null<Float>,					//VAT rate
	vatValue : Null<Float>,				//amount of VAT included in the price
	desc : Null<String>,
	orderable : Bool,			//can be currently ordered
	qt:Null<Float>,
	unitType:Null<Unit>,
	stockTracking:Null<StockTracking>,

	organic:Bool,
	variablePrice:Bool,
	active:Bool,
	bulk:Bool,

	catalogId : Int,
	catalogTax : Null<Float>, 		//pourcentage de commission défini dans le contrat
	catalogTaxName : Null<String>,	//label pour la commission : ex: "frais divers"
	?vendorId : Int,
	?distributionId:Null<Int>, //in the context of a distrib

	?multiWeight : Bool, //Used in OrderBox to be able to create a new order when selecting a product that is multiweight
}

@:keep
typedef DistributionInfos = {
	id:Int,
	vendorId:Int,
	groupId:Int,
	groupName:String,
	distributionStartDate:Date,
	distributionEndDate:Date,
	orderStartDate:Date,
	orderEndDate:Date,
	place:PlaceInfos,
}
enum Unit{
	Piece;
	Kilogram;
	Gram;
	Litre;
	Centilitre;
	Millilitre;
}


/**
 * Stock tracking rule to use.
 */
 enum StockTracking {
	/**
	 * Always availabled.
	 */
	Disabled;

	/**
	 * A global initial stock that won't change for this Catalog
	 */
	Global;

	/**
	 * A per distribution stock. 
	 * @see StockTrackingPerDistribution
	 */
	PerDistribution;
}

/**
 * if "stockTracking" is "PerDistribution", stockTrackingPerDistrib is the rule to use.
 */
enum StockTrackingPerDistribution {
	/**
	 * initial stock is the same for each distribution
	 */
	AlwaysTheSame;

	/**
	 * initial stock exists at regular intervals. oe: 1 times out of 3 there is stock. Else, 0.
	 */
	FrequencyBased;

	/**
	 * initial stock configured per period (continuous group of distribs) for multiple periods. 
	 * @see db.ProductDistributionStock
	 */
	PerPeriod;
}

/**
 * Links in navbars for plugins
 */
typedef Link = {
	id:String,
	link:String,
	name:String,
	?icon:String,
}

typedef Block = {
	id:String,
	title:String,
	?icon:String,
	html:String
}

typedef UserOrder = {
	id:Int,
	?basketId:Int,
	userId:Int,
	userName:String,
	?userEmail : String,
	
	?userId2:Int,
	?userName2:String,
	?userEmail2:String,
	
	//deprecated
	?productId:Int,
	?productRef:String,
	?productName:String,	
	?productPrice:Float,
	?productImage:String,
	?productQt:Float,
	?productUnit:Unit,
	?productHasVariablePrice:Bool,
	

	//new way
	?product:ProductInfo,

	quantity:Float,
	smartQt:String,
	subTotal:Float,
	
	?fees:Null<Float>,
	?percentageName:Null<String>,
	?percentageValue:Null<Float>,
	total:Float,
	
	//flags
	paid:Bool,
	invertSharedOrder:Bool,
	?canceled:Bool,	
	?canModify:Bool,
	
	catalogId:Int,
	catalogName:String,
}

typedef PlaceInfos = {
	id:Int,
	name:String,
	address1:String,
	address2:String,
	zipCode:String,
	city:String,
	latitude:Float,
	longitude:Float
}

typedef UserInfo = {
	id:Int,
	name:String,
	firstName:String,
	lastName:String,
	email:String,
	?phone:String,
	?city:String,
	?zipCode:String,
	?address1:String,
	?address2:String,
}

enum OrderFlags {
	InvertSharedOrder;	//invert order when there is a shared/alternated order
}


typedef OrderByProduct = {
	quantity:Float,
	smartQt:String,
	pid:Int,
	pname:String,
	ref:String,
	priceHT:Float,
	priceTTC:Float,
	vat:Float,
	totalHT:Float,
	totalTTC:Float,
	weightOrVolume:String,
};
typedef OrderByEndDate = {date: String,contracts: Array<String>};


typedef RevenueAndFees = {amount:Float,netAmount:Float,fixedFees:Float,variableFees:Float};

/**
	Event enum used for plugins.
	
	As in most CMS event systems, 
	the events (or "triggers") can be caught by plugins 
	to perform an action or modifiy data carried by the event.
	
**/
enum Event {

	Page(uri:String);							//a page is displayed
	Nav(nav:Array<Link>, name:String, ?id:Int);	//a navigation is displayed, optionnal object id if needed
	Blocks(blocks:Array<Block>, name:String, ?context:Dynamic);	//HTML blocks that can be displayed on a page
	Permalink(permalink:{link:String,entityType:String, entityId:Int}); // a permalink is invoked
	
	#if sys
	SendEmail(message : sugoi.mail.Mail);		//an email is sent
	NewMember(user:db.User,group:db.Group);		//a new member is added to a group
	NewGroup(group:db.Group, author:db.User);	//a new group is created
	
	//Distributions
	PreNewDistrib(contract:db.Catalog);		//when displaying the insert distribution form
	NewDistrib(distrib:db.Distribution);		//when a new distrinbution is created
	PreEditDistrib(distrib:db.Distribution);
	EditDistrib(distrib:db.Distribution);
	DeleteDistrib(distrib:db.Distribution);
	PreNewDistribCycle(cycle:db.DistributionCycle);	
	NewDistribCycle(cycle:db.DistributionCycle);
	GetMultiDistrib(md:db.MultiDistrib);
	PreDeleteMultiDistrib(md:db.MultiDistrib);
	
	//Products
	PreNewProduct(contract:db.Catalog);	//when displaying the insert distribution form
	NewProduct(product:db.Product);			//when a new product is created
	PreEditProduct(product:db.Product);
	EditProduct(product:db.Product);
	DeleteProduct(product:db.Product);
	BatchEnableProducts(data:{pids:Array<Int>,enable:Bool});
	ProductInfosEvent(p:ProductInfo,?d:db.Distribution);	//when infos about a product are displayed
	
	//Contracts
	EditContract(contract:db.Catalog,form:sugoi.form.Form);
	DuplicateContract(contract:db.Catalog);
	DeleteContract(contract:db.Catalog);
	
	//crons
	DailyCron(now:Date);
	HourlyCron(now:Date);
	MinutelyCron(now:Date,jobs:Array<sugoi.tools.TransactionWrappedTask>,outputFormat:String);
	
	//orders
	MakeOrder(orders:Array<db.UserOrder>); 
	StockMove(order:{product:db.Product, move:Float}); //when a stock is modified
	ValidateBasket(basket:db.Basket);
	
	//payments
	GetPaymentTypes(data:{types:Array<payment.PaymentType>});
	NewOperation(op:db.Operation);
	PreOperationDelete(op:db.Operation);
	PreOperationEdit(op:db.Operation);
	PreRefund(form:sugoi.form.Form,basket:db.Basket,refundAmount:Float);
	Refund(operation:db.Operation,basket:db.Basket);
	
	#end
	
}

typedef Theme = {
	var id:String; // theme's id
	var name:String; // readable name
	var supportEmail:String; // email address of the support	
	var ?footer:{
		?bloc1:String, // first footer bloc in html
		?bloc2:String, // second footer bloc in html
		?bloc3:String, // third footer bloc in html
		?bloc4:String, // last footer bloc in html
	};
	var email : {
		senderEmail:String,
		brandedEmailLayoutFooter:String // footer of the branded email layout in html
	};
	var terms : {
		var termsOfServiceLink:String; // Terms of service (CGU)
		var termsOfSaleLink:String;    //CCP
		var platformTermsOfServiceLink:String;  //CGS
		var privacyPolicyLink:String; 
	};
}
