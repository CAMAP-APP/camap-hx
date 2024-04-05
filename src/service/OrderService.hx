package service;
import Common;
import db.MultiDistrib;
import db.Basket;
import db.Basket.BasketStatus;
import tink.core.Error;
import sugoi.Web;


/**
 * Order Service 
 * @author web-wizard,fbarbut
 -
 */
class OrderService
{

	public static function canHaveFloatQt(product:db.Product):Bool{
		return product.variablePrice || product.bulk;
	}

	/**
	 * Make a product Order
	 * 
	 * @param	quantity
	 * @param	productId
	 *
	 */
	public static function make(user:db.User, quantity:Float, product:db.Product, distribId:Int, ?paid:Bool, ?subscription : db.Subscription, ?user2:db.User, ?invert:Bool, ?basket:db.Basket ) : Null<db.UserOrder> {
		
		var t = sugoi.i18n.Locale.texts;

		if( distribId == null ) throw new Error( "You have to provide a distribId" );
		if( quantity == null ) throw new Error( "Quantity is null" );
		if( quantity < 0 ) throw new Error( "Quantity is negative" );
		var vendor = product.catalog.vendor;
		
		if( vendor.isDisabled()) {
			throw new Error('${vendor.name} est désactivé. Raison : ${vendor.getDisabledReason()}');
		}
		
		//quantity
		if ( !canHaveFloatQt(product) ){
			if( !tools.FloatTool.isInt(quantity)  ) {
				throw new Error( t._("Error : product \"::product::\" quantity should be integer",{product:product.name}) );
			}
		}
		
		//multiweight : make one row per product
		
		if ( product.multiWeight && quantity > 1.0 ) {

			if ( !tools.FloatTool.isInt( quantity ) ) throw new Error( t._("multi-weighing products should be ordered only with integer quantities") );
			var newOrder = null;
			for ( i in 0...Math.round(quantity) ) {
				try{
					newOrder = make( user, 1, product, distribId, paid, subscription, user2, invert, basket);
				} catch(e:tink.core.Error) {
					throw (e);
				}
			
			}
			return newOrder;
		}
		
		//checks
		if (quantity <= 0) return null;
		
		//check for previous orders on the same distrib
		var prevOrders = db.UserOrder.manager.search($product==product && $user==user && $distributionId==distribId, true);
		
		//Create order object
		var order = new db.UserOrder();
		order.product = product;
		order.quantity = quantity;
		order.productPrice = product.price;
		if ( product.catalog.hasPercentageOnOrders() ){
			order.feesRate = product.catalog.percentageValue;
		}
		order.user = user;
		if (user2 != null) {
			order.user2 = user2;
			if ( invert ) order.flags.set(InvertSharedOrder);
		}
		if (paid != null) order.paid = paid;
		if (distribId != null) order.distribution = db.Distribution.manager.get(distribId,false);
		
		//cumulate quantities if there is a similar previous order
		if (prevOrders.length > 0 && !product.multiWeight) {
			for (prevOrder in prevOrders) {
				//if (!prevOrder.paid) {
					order.quantity += prevOrder.quantity;
					prevOrder.delete();
				//}
			}
		}

		//basket can be sent in param, if not getOrCreate it
		if(basket==null){
			basket = db.Basket.getOrCreate(user, order.distribution.multiDistrib);
		}
		order.basket = basket;			
		
		//checks
		if(order.distribution==null) throw new Error( "cant record an order for a variable catalog without a distribution linked" );
		if(order.basket==null) throw new Error( "this order should have a basket" );
		if( subscription != null && subscription.id == null ) throw new Error( "La souscription a un id null." );
		if( subscription == null ) throw new Error( "Impossible d'enregistrer une commande sans souscription." );
		order.subscription = subscription;

		order.insert();
		
		//Stocks

		if (order.product.stock != null) {
			var c = order.product.catalog;
			if (c.hasStockManagement()) {
				var orderDate = order.distribution.date;
				var now = Date.now();
				var availableStock = order.product.stock;
				var actualOrders;
									
				// Calculer le stock de la distri concernée
				// Commande en cours dans la distri
				var totOrdersQt : Float = 0;
				// Attention: si multiweight, la quantité des commandes existantes de l'utilisateur
				// n'est pas cummulée dans la quantité totale (quantity), le controle de stock est donc inopérant
				// il faut inclure les commandes précédentes du user
				if (order.product.multiWeight) {
					//if (App.config.DEBUG){
					//	var msg="Multiweight";
					//	App.current.session.addMessage (msg);
					//}
					actualOrders = db.UserOrder.manager.search($product==order.product && $distributionId==order.distribution.id, true);
				} else {
					actualOrders = db.UserOrder.manager.search($product==order.product && $user!=order.user && $distributionId==order.distribution.id, true);
				}
				for (actualOrder in actualOrders) {
					totOrdersQt += actualOrder.quantity;
					//if (App.config.DEBUG){
					//	var msg= '${DateTools.format(order.distribution.date,"%d/%m/%Y")} Commandes présentes : ' +totOrdersQt+ ' ' +order.product.name+ 'pour l\'utilisateur' +user.id;
					//	App.current.session.addMessage (msg);
					//}
				}
				// Stock dispo = stock - commandes en cours
				if (order.product.multiWeight){
					totOrdersQt -= quantity;
					availableStock -= totOrdersQt;
				} else {
					availableStock -= totOrdersQt;
				}
				
				//if (App.config.DEBUG){
				//	var msg = "stock départ: " +order.product.stock+ "tot Orders: " +totOrdersQt+ " stock disponible: " +availableStock;
				//	App.current.session.addMessage (msg,true);
				//}

				// si stock à 0 annuler commande
				if (availableStock == 0) {
					order.quantity = 0;
					order.update();
					throw new Error('Erreur: ${DateTools.format(order.distribution.date,"%d/%m/%Y")}: le stock de ${order.product.name} est épuisé');	
				} else if (availableStock - order.quantity < 0) {
				// si stock insuffisant, cancel
					var canceled = order.quantity - availableStock;
					order.quantity -= canceled;
					order.update();
					throw new Error('Erreur: ${DateTools.format(order.distribution.date,"%d/%m/%Y")}: le stock de ${order.product.name} n\'est pas suffisant, vous ne pouvez commander plus de ${availableStock} ${order.product.name}');	
				}
			}	
		}

		return order;
	}


	/**
	 * Edit an existing order (quantity)
	 */
	public static function edit(order:db.UserOrder, newquantity:Float, ?paid:Bool , ?user2:db.User,?invert:Bool):db.UserOrder {
		
		var t = sugoi.i18n.Locale.texts;
		
		order.lock();
		
		//quantity
		if (newquantity == null) newquantity = 0;
		if(newquantity<0) throw new Error( "Quantity is negative" );
		
		if ( !canHaveFloatQt(order.product) ){
			if( !tools.FloatTool.isInt(newquantity)  ) {
				throw new Error( 'Erreur : la quantité du produit "${order.product.name}" doit être un nombre entier' );
			}
		}

		//paid
		if (paid != null) {
			order.paid = paid;
		}else {
			if (order.quantity < newquantity) order.paid = false;	
		}
		
		//shared order
		if (user2 != null){
			order.user2 = user2;	
			if (invert == true) order.flags.set(InvertSharedOrder);
			if (invert == false) order.flags.unset(InvertSharedOrder);
		}else{
			order.user2 = null;
			order.flags.unset(InvertSharedOrder);
		}

		//stocks
		
		if (order.product.stock != null) {
			var c = order.product.catalog;
			
			if (c.hasStockManagement()) {
				var totOrdersQt : Float = 0;
				var actualOrders = db.UserOrder.manager.search($productId==order.product.id && $distributionId==order.distribution.id, true);
				for (actualOrder in actualOrders) {
					totOrdersQt += actualOrder.quantity;
				}
				totOrdersQt -= order.quantity;
				// Stock dispo = stock - commandes en cours
				var availableStock = order.product.stock - totOrdersQt;
				if (availableStock == 0 && newquantity != 0) {
					newquantity = 0;
					throw new Error('Erreur: ${DateTools.format(order.distribution.date,"%d/%m/%Y")}: le stock de ${order.product.name} est épuisé');	
				} else if (newquantity >= order.quantity && availableStock - newquantity < 0) {
						//stock is not enough, cancel
						newquantity = availableStock;
						order.quantity = newquantity;
						order.update();
						throw new Error('Erreur: ${DateTools.format(order.distribution.date,"%d/%m/%Y")}: le stock de ${order.product.name} n\'est pas suffisant, vous ne pouvez commander plus de ${availableStock} ${order.product.name}.');
				}
			}	
		}
		
		//mise à jour de la commande
		if (newquantity == 0) {
			order.quantity = 0;			
			order.paid = true;
			order.update();
		}else {
			order.quantity = newquantity;
			order.update();				
		}	

		//checks
		var o = order;
		if(o.distribution==null) throw new Error( "cant record an order which is not linked to a distribution");
		if(o.basket==null) throw new Error( "this order should have a basket" );

		return order;
	}

	/**
		edit a multiweight product order from a single qty input ( CSA order form ).
	**/
	public static function editMultiWeight( order:db.UserOrder, newquantity:Float ):db.UserOrder {

		if( !tools.FloatTool.isInt(newquantity) ) {
			throw new Error( "Erreur : la quantité du produit" + order.product.name + " devrait être un entier." );
		}

		if( order.product.multiWeight ) {

			var currentOrdersNb = db.UserOrder.manager.count( $subscription == order.subscription && $distribution == order.distribution && $product == order.product && $quantity > 0 );
			if ( newquantity == currentOrdersNb ) return order;
			
			var orders = db.UserOrder.manager.search( $subscription == order.subscription && $distribution == order.distribution && $product == order.product && $quantity > 0, false).array();
			if ( newquantity != 0 ) {

				var quantityDiff = Std.int(newquantity) - currentOrdersNb;
				if ( quantityDiff < 0 ) {

					for ( i in 0...-quantityDiff ) {
						edit( orders[i], 0 );
						// orders.remove( orders[i] );
					}
				} else if ( quantityDiff > 0 ) {
					for ( i in 0...Math.round(quantityDiff) ){
						try {
							make( order.user, 1, order.product, order.distribution.id, null, order.subscription );
						} catch(e:tink.core.Error) {
							throw (e);
						}
					}
					// for ( i in 0...quantityDiff ) {
					// 	orders.push( make( order.user, 1, order.product, order.distribution.id, null, order.subscription ) );
					// }
				}

				// for ( order in orders ) {
				// 	edit( order , 1 );
				// }
			}else{

				//set all orders to zero
				for ( order in orders ) {
					edit( order , 0 );
				}
			}
			
		}
		
		return order;
	}

	/**
	 *  Delete an order
	 */
	public static function delete( order : db.UserOrder, ?force = false ) {
		var t = sugoi.i18n.Locale.texts;
		if(order==null) throw new Error( t._( "This order has already been deleted." ) );
		order.lock();
		
		if (order.quantity == 0 || force) {

			var contract = order.product.catalog;
			var user = order.user;
			var product = order.product;

			//stock mgmt
			/*
			if (contract.hasStockManagement() && product.stock!=null && order.quantity!=null) {
				//re-increment stock
				product.lock();
				product.stock +=  order.quantity;
				product.update();
			}
			*/
			order.delete();
			service.SubscriptionService.createOrUpdateTotalOperation( order.subscription );
	
		} else {
			throw new Error( t._( "Deletion not possible: quantity is not zero." ) );
		}

	}

	/**
	 * Prepare a simple dataset, ready to be displayed
	 */
	public static function prepare(orders:Iterable<db.UserOrder>):Array<UserOrder> {
		var out = new Array<UserOrder>();
		var orders = Lambda.array(orders);
		var view = App.current.view;
		var t = sugoi.i18n.Locale.texts;

		for (o in orders) {
		
			var x : UserOrder = cast { };
			x.id = o.id;
			x.basketId = o.basket==null ? null : o.basket.id;
			x.userId = o.user.id;
			x.userName = o.user.getCoupleName();
			x.userEmail = o.user.email;
			
			//shared order
			if (o.user2 != null){
				x.userId2 = o.user2.id;
				x.userName2 = o.user2.getCoupleName();
				x.userEmail2 = o.user2.email;
			}
			
			//deprecated
			x.productId = o.product.id;
			x.productRef = o.product.ref;
			x.productQt = o.product.qt;
			x.productUnit = o.product.unitType;
			x.productPrice = o.productPrice;
			x.productImage = o.product.getImage();
			x.productHasVariablePrice = o.product.variablePrice;
			//new way
			x.product = o.product.infos();
			x.product.price = o.productPrice;//do not use current price, but price of the order
			x.quantity = o.quantity;
			
			//smartQt
			if (x.quantity == 0.0){
				x.smartQt = t._("Canceled");
			}else if( OrderService.canHaveFloatQt(o.product)){
				x.smartQt = view.smartQt(x.quantity, x.productQt, x.productUnit);
			}else{
				x.smartQt = Std.string(x.quantity);
			}

			//product name.
			if ( x.productHasVariablePrice || x.productQt==null || x.productUnit==null ){
				x.productName = o.product.name;	
			}else{
				x.productName = o.product.name + " " + view.formatNum(x.productQt) +" "+ view.unit(x.productUnit,x.productQt>1);	
			}
			
			x.subTotal = o.quantity * o.productPrice;

			var c = o.product.catalog;
			
			if ( o.feesRate!=0 ) {
				
				x.fees = x.subTotal * (o.feesRate/100);
				x.percentageName = c.percentageName;
				x.percentageValue = o.feesRate;
				x.total = x.subTotal + x.fees;
				
			}else {
				x.total = x.subTotal;
			}
			
			//flags
			x.paid = o.paid;
			x.invertSharedOrder = o.flags.has(InvertSharedOrder);
			x.catalogId = c.id;
			x.catalogName = c.name;
			x.canModify = o.canModify(); 
			// Sys.print("A : "+x.total+"<br>");
			
			//recreate a clean float to prevent a strange bug in neko
			//if I dont do that 1.665 will round to 1.66 instead of 1.67
			x.total = Std.string(x.total).parseFloat();

			x.total = Math.round(x.total*100)/100;
			// Sys.print("B : "+x.total+"<br>");
			out.push(x);
		}
		
		return sort(out);
	}

	/**
		Record a temporary basket
	**/
	public static function makeTmpBasket(user:db.User,multiDistrib:db.MultiDistrib, ?tmpBasketData:TmpBasketData):db.Basket {
		//basket with no products is allowed ( init an empty basket )
		if( tmpBasketData==null) tmpBasketData = {products:[]};

		//generate basketRef
		// var ref = (user==null?0:user.id)+"-"+multiDistrib.id+"-"+Date.now().toString().substr(0,10)+"-"+Std.random(1000);

		var tmp = new db.Basket();
		tmp.user = user;
		tmp.multiDistrib = multiDistrib;
		tmp.setData(tmpBasketData);
		// tmp.ref = ref;
		tmp.status = Std.string(BasketStatus.OPEN);
		tmp.insert();
		return tmp;
	}
	
	/**
	 * 	Create real orders from a temporary basket.
		Should not return a basket, because this basket can include older orders.
	 */
	public static function confirmTmpBasket(tmpBasket:db.Basket):Array<db.UserOrder>{

		tmpBasket.lock();

		if(tmpBasket.status != Std.string(BasketStatus.OPEN)) throw "basket should be status=OPEN";

		var t = sugoi.i18n.Locale.texts;
		var orders = [];
		var user = tmpBasket.user;

		// we get an existing basket by user-distrib , it will reuse existing basket
		var basket = db.Basket.getOrCreate(user,tmpBasket.multiDistrib);

		var distributions = tmpBasket.multiDistrib.getDistributions();
		for (o in tmpBasket.getData().products){
			var p = db.Product.manager.get(o.productId,false);

			//find related distrib
			var distrib = null;
			for( d in distributions){
				if(d.catalog.id==p.catalog.id){
					distrib = d;
				}
			}

			if(distrib==null) {
				App.current.session.addMessage('Le produit "${p.getName()}" n\'est pas disponible pour cette distribution, il a été retiré de votre commande.',true);
				continue;
			}

			//check that the distrib is still open.			
			if(!distrib.canOrderNow()){
				App.current.session.addMessage('Il n\'est plus possible de commander le produit "${p.getName()}", il a été retiré de votre commande.',true);
				continue;
			}

			var order = make(user, o.quantity, p, distrib.id, basket );
			if(order!=null) orders.push( order );
		}
		
		//store total price
		if(orders.length>0){
			basket.total = basket.getOrdersTotal();
			basket.update();
		}

		App.current.event(MakeOrder(orders));
		
		//delete tmpBasket
		if(App.current.session.data.tmpBasketId==tmpBasket.id) App.current.session.data.tmpBasketId=null;

		tmpBasket.delete();

		return orders;
	}


	/**
	 *  Send an order-by-products report to the coordinator
	 */
	public static function sendOrdersByProductReport(d:db.Distribution){
		
		var m = new sugoi.mail.Mail();
		m.addRecipient(d.catalog.contact.email , d.catalog.contact.getName());
		m.setSender(App.current.getTheme().email.senderEmail, App.current.getTheme().name);
		m.setSubject('[${d.catalog.group.name}] Distribution du ${Formatting.dDate(d.date)} (${d.catalog.name})');
		var orders = service.ReportService.getOrdersByProduct(d);

		var html = App.current.processTemplate("mail/ordersByProduct.mtt", { 
			contract:d.catalog,
			distribution:d,
			orders:orders,
			formatNum:Formatting.formatNum,
			currency:App.current.view.currency,
			dDate:Formatting.dDate,
			hHour:Formatting.hHour,
			group:d.catalog.group
		} );
		
		m.setHtmlBody(html);
		App.sendMail(m, d.catalog.group);
	}


	/**
	 *  Send Order summary for a member
	 *  WARNING : its for one distrib, not for a whole basket !
	 */
	public static function sendOrderSummaryToMembers(d:db.Distribution){

		var title = '[${d.catalog.group.name}] Votre commande pour le ${App.current.view.dDate(d.date)} (${d.catalog.name})';

		for( user in d.getUsers() ){

			var m = new sugoi.mail.Mail();
			m.addRecipient(user.email , user.getName(),user.id);
			if(user.email2!=null) m.addRecipient(user.email2 , user.getName(),user.id);
			m.setSender(App.current.getTheme().email.senderEmail, App.current.getTheme().name);
			if(d.catalog.contact.email!=null) m.setReplyTo(d.catalog.contact.email, d.catalog.contact.getName());
			m.setSubject(title);
			var orders = prepare(d.catalog.getUserOrders(user,d));

			var html = App.current.processTemplate("mail/orderSummaryForMember.mtt", { 
				contract:d.catalog,
				distribution:d,
				orders:orders,
				formatNum:Formatting.formatNum,
				currency:App.current.view.currency,
				dDate:Formatting.dDate,
				hHour:Formatting.hHour,
				group:d.catalog.group
			} );
			
			m.setHtmlBody(html);
			App.sendMail(m, d.catalog.group);
		}
		
	}
	
	/**
		Order by lastname (+lastname2 if exists), then catalog, the productName
	**/
	public static function sort(orders:Array<UserOrder>){
		var astr=null;
		var bstr=null;
		orders.sort(function(a, b) {
			astr = a.userName + a.userId + a.userName2 + a.userId2 + a.catalogId + a.productName;
			bstr = b.userName + b.userId + b.userName2 + b.userId2 + b.catalogId + a.productName;
			
			if (astr > bstr ) {
				return 1;
			}
			if (astr < bstr ) {
				return -1;
			}
			return 0;
		});
		return orders;
	}

	/**
		Returns tmp basket
	**/
	public static function getTmpBasket(user:db.User,group:db.Group):db.Basket{
		if(user==null) return null;
		if(group==null) throw "should have a group here";
		for( b in db.Basket.manager.search($user==user && $status==Std.string(BasketStatus.OPEN))){
			if(b.multiDistrib.group.id==group.id) return b;
		}
		return null;
	}

	public static function getOrCreateTmpBasket(user:db.User,distrib:MultiDistrib):db.Basket{
		var tb = getTmpBasket(user,distrib.getGroup());
		if(tb==null) getTmpBasketFromSession(distrib.getGroup());

		if(tb!=null && tb.multiDistrib.id==distrib.id){
			return tb;
		} else{
			tb = makeTmpBasket(user,distrib);
			App.current.session.data.tmpBasketId = tb.id;
			return tb;
		}
	}

	/**
		Get a tmpBasket from session.
		Checks that it belongs to the current group.
	**/
	public static function getTmpBasketFromSession(group:db.Group){
		if(group==null) return null;
		var tmpBasketId:Int = App.current.session.data.tmpBasketId; 		
		if ( tmpBasketId != null) {
			var tmpBasket = db.Basket.manager.get(tmpBasketId,true);
			if(tmpBasket!=null && tmpBasket.multiDistrib.getGroup().id==group.id && tmpBasket.status==Std.string(BasketStatus.OPEN)){
				return tmpBasket;
			}else{
				return null;
			}
			
		}else{
			return null;
		}
	}

	/**
	 * get users orders for a distribution
	 */
	public static function getOrders( contract : db.Catalog, ?distribution : db.Distribution, ?csv = false) : Array<UserOrder> {

		var view = App.current.view;
		var orders = new Array<db.UserOrder>();
		orders = contract.getOrders(distribution);	
				
		var orders = prepare(orders);
		
		//CSV export
		if (csv) {
			var t = sugoi.i18n.Locale.texts;			
			var data = new Array<Dynamic>();
			
			for (o in orders) {
				data.push( { 
					"name":o.userName,
					"productName":o.productName,
					"price":view.formatNum(o.productPrice),
					"quantity":view.formatNum(o.quantity),
					"fees":view.formatNum(o.fees),
					"total":view.formatNum(o.total),
					"paid":o.paid
				});				
			}
			
			var exportName = "";
			if (distribution != null){
				exportName = contract.group.name + " - " + t._("Delivery ::contractName:: ", {contractName:contract.name}) + distribution.date.toString().substr(0, 10);					
			}else{
				exportName = contract.group.name + " - " + contract.name;
			}
			
			sugoi.tools.Csv.printCsvDataFromObjects(data, ["name",  "productName", "price", "quantity", "fees", "total", "paid"], exportName+" - " + t._("Per member"));			
			return null;
		}else{
			return orders;
		}
		
	}


	// Get orders of a user for a multi distrib or a catalog
	public static function getUserOrders( user : db.User, ?catalog : db.Catalog, ?multiDistrib : db.MultiDistrib, ?subscription : db.Subscription ) : Array<db.UserOrder> {
	 
		var orders : Array<db.UserOrder>;
		if( catalog == null ) {

			//We edit a whole multidistrib, edit only var orders.
			orders = multiDistrib.getUserOrders(user , db.Catalog.TYPE_VARORDER);
		} else {
			
			//Edit a single catalog, may be CSA or variable
			var distrib = null;
			if( multiDistrib != null ) {
				distrib = multiDistrib.getDistributionForContract(catalog);
			}

			if ( catalog.type == db.Catalog.TYPE_VARORDER ) {
				orders = catalog.getUserOrders( user, distrib, false );
			} else {
				orders = SubscriptionService.getCSARecurrentOrders( subscription, null );
			}
				
		}

		return orders;
		
	}

	/**
		Create or update orders for variable catalogs
		20230723 Adapter Stock ??
	**/ 
	public static function createOrUpdateOrders( user:db.User, multiDistrib:db.MultiDistrib, catalog:db.Catalog, ordersData:Array<{id:Int, productId:Int, qt:Float, paid:Bool}> ) : Array<db.UserOrder> {

		if ( multiDistrib == null && catalog == null ) {
			throw new Error('You should provide at least a catalog or a multiDistrib');
		}

		if ( ordersData.length == 0 ) {
			throw new Error('Il n\'y a pas de commandes définies.');
		}

		var group : db.Group = multiDistrib != null ? multiDistrib.group : catalog.group;
		if ( group == null ) { throw new Error('Impossible de déterminer le groupe.'); }

		var orders : Array<db.UserOrder> = [];
		var existingUserOrders = findExistingUserOrders(user, multiDistrib, catalog);

		var subscriptions = new Array< db.Subscription >();
		if ( catalog != null ) {
			var subscription = db.Subscription.manager.select( $user == user && $catalog == catalog && $startDate <= multiDistrib.distribStartDate && multiDistrib.distribEndDate <= $endDate );
			if ( subscription == null ) { 
				throw new Error('Il n\'y a pas de souscription pour cette personne. Vous devez d\'abord créer une souscription avant de commander.');
			}			
			subscriptions.push( subscription );
		}
		
		for ( order in ordersData ) {
			
			// Get product
			var product = db.Product.manager.get( order.productId, false );
			
			// Find existing order				
			var existingUserOrder = Lambda.find( existingUserOrders, function(x) return x.id == order.id );
			
			// Save order
			if ( existingUserOrder != null ) {

				// Edit existing order
				try {
					var updatedUserOrder = OrderService.edit( existingUserOrder, order.qt, order.paid );
					if ( updatedUserOrder != null ) orders.push( updatedUserOrder );
				} catch(e:tink.core.Error) {
					var msg = e.message;
					App.current.session.addMessage(msg, true);	
				}
				// if ( updatedUserOrder != null ) orders.push( updatedUserOrder );
			} else {

				// Insert new order
				var distrib = null;
				if( multiDistrib != null ) { 
					distrib = multiDistrib.getDistributionFromProduct( product );
				}

				var newOrder : db.UserOrder = null;
				//Let's find the subscription for that user, catalog and distrib
				var subscription : db.Subscription = null;
				if ( catalog != null ) {
					subscription = subscriptions[0];
				} else {
					subscription = db.Subscription.manager.select( $user == user && $catalog == distrib.catalog && $startDate <= distrib.date && distrib.date <= $endDate );
				}
				if ( subscription == null ) { throw new Error('Il n\'y a pas de souscription pour cette personne. Vous devez d\'abord créer une souscription avant de commander.'); }

				try {
					newOrder =  OrderService.make( user, order.qt , product, distrib == null ? null : distrib.id, order.paid, subscription );
				} catch(e:tink.core.Error) {
					var msg = e.message;
					App.current.session.addMessage(msg, true);	
				}

				if ( catalog == null && subscriptions.find( x -> x.id == subscription.id ) == null ) {
					subscriptions.push( subscription );
				}
				
				if ( newOrder != null ) orders.push( newOrder );
				
			}
		}

		App.current.event( MakeOrder( orders ) );

		//update basket total
		if(multiDistrib!=null){
			var b = db.Basket.get(user,multiDistrib,true);
			b.total = b.getOrdersTotal();
			b.update();
		}

		for( subscription in subscriptions ) {
			service.SubscriptionService.createOrUpdateTotalOperation( subscription );				
		}
		
		return orders;
	}

	public static function findExistingUserOrders(user:db.User, multiDistrib:db.MultiDistrib, catalog:db.Catalog) : Array<db.UserOrder> {
		var existingUserOrders = [];
		if (catalog == null) {
			// Edit a whole multidistrib
			existingUserOrders = multiDistrib.getUserOrders( user );
		} else {
			// Edit a single catalog
			var distrib = null;
			if( multiDistrib != null ) {
				distrib = multiDistrib.getDistributionForContract( catalog );
			}
			existingUserOrders = catalog.getUserOrders( user, distrib );			
		}
		return existingUserOrders;
	}

	public static function updateOrderQuantity( 
		user:db.User,
		multiDistrib:db.MultiDistrib, 
		catalog:db.Catalog, 
		userOrder:{id:Int, qt:Float} 
	) : { subTotal: String, total: String, fees: String, basketTotal: String, nextQt: String } {

		if ( multiDistrib == null && catalog == null ) {
			throw new Error('You should provide at least a catalog or a multiDistrib');
		}

		if ( userOrder == null ) {
			throw new Error('Il n\'y a pas de commande définie.');
		}
		
		var group : db.Group = multiDistrib != null ? multiDistrib.group : catalog.group;
		if ( group == null ) { throw new Error('Impossible de déterminer le groupe.'); }

		var updatedUserOrder : db.UserOrder = null;
		var existingUserOrders = findExistingUserOrders(user, multiDistrib, catalog);

		var subscriptions = new Array< db.Subscription >();
		if ( catalog != null ) {
			var subscription = db.Subscription.manager.select( $user == user && $catalog == catalog && $startDate <= multiDistrib.distribStartDate && multiDistrib.distribEndDate <= $endDate );
			if ( subscription == null ) { 
				throw new Error('Il n\'y a pas de souscription pour cette personne. Vous devez d\'abord créer une souscription avant de commander.');
			}			
			subscriptions.push( subscription );
		}
				
		var existingUserOrder = Lambda.find( existingUserOrders, function(x) return x.id == userOrder.id );
		
		// Save order
		if ( existingUserOrder != null ) {
			// Edit existing order
			try {
				updatedUserOrder = OrderService.edit( existingUserOrder, userOrder.qt, null );
				App.current.event( MakeOrder( [updatedUserOrder] ) );
			} catch(e:tink.core.Error) {
				var msg = e.message;
				App.current.session.addMessage(msg, true);	
			}
		} else {
			throw new Error("Order not found.");
		}

		// Update basket total
		if ( multiDistrib != null ) {
			var b = db.Basket.get(user,multiDistrib,true);
			b.total = b.getOrdersTotal();
			b.update();
		}

		for ( subscription in subscriptions ) {
			service.SubscriptionService.createOrUpdateTotalOperation( subscription );				
		}

		var subTotal = updatedUserOrder.product.price * updatedUserOrder.quantity;
		var basketTotal = updatedUserOrder.basket.total;
		var fees : Float = 0;
		var total = subTotal;
		if ( updatedUserOrder.feesRate!=0 ) {
			fees = subTotal * (updatedUserOrder.feesRate/100);
			total += fees;
		}

		return { 
			subTotal: Formatting.formatNum(subTotal), 
			total: Formatting.formatNum(total), 
			fees: fees == 0 ? '' : Formatting.formatNum(fees), 
			basketTotal: Formatting.formatNum(updatedUserOrder.basket.total),
			nextQt: Formatting.formatNum(updatedUserOrder.quantity * updatedUserOrder.product.qt)
		 };
	}
}