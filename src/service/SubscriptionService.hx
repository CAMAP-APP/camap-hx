package service;
import Common;
import controller.Distribution;
import db.Catalog;
import db.Group.RegOption;
import db.Operation.OperationType;
import db.Subscription;
import tink.core.Error;

using Lambda;
using tools.DateTool;

enum SubscriptionServiceError {
	NoSubscription;
	PastDistributionsWithoutOrders;
	PastOrders;
	OverlappingSubscription;
	InvalidParameters;
	CatalogRequirementsNotMet;
	OtherError;
}

typedef CSAOrder = { productId:Int, productPrice:Float, quantity:Float, ?userId2:Int, ?invertSharedOrder:Bool }

/**
 * Subscription service
 * @author web-wizard
 */
class SubscriptionService
{

	public var adminMode:Bool;

	public function new(){}

	/**
		get subscriptions of a catalog
	**/
	public static function getCatalogSubscriptions( catalog : db.Catalog ) {
		return db.Subscription.manager.search( $catalogId == catalog.id, {orderBy:id},false ).array();
	}

	/**
		Get user subscriptions in active catalogs
	**/
	public static function getActiveSubscriptions( user:db.User, group:db.Group ) : Array<db.Subscription> {

		var catalogIds = group.getActiveContracts( true ).map( c -> return c.id );
		return db.Subscription.manager.search( ( $user == user || $user2 == user ) && ( $catalogId in catalogIds ), false ).array();
	}

	/**
		Get user not closed subscriptions for a given vendor
	**/
	public static function getUserVendorNotClosedSubscriptions( subscription : db.Subscription ) : Array<db.Subscription> {

		var notClosedSubscriptions = db.Subscription.manager.search( $user == subscription.user && $endDate >= Date.now(), false ).array();
		var vendorNotClosedSubscriptions = new Array<db.Subscription>();
		for ( sub in notClosedSubscriptions ) {
			if( sub.id != subscription.id && sub.catalog.vendor.id == subscription.catalog.vendor.id ) {
				vendorNotClosedSubscriptions.push( sub );
			}
		}
		return vendorNotClosedSubscriptions;
	}

	/**
		Get user active subscriptions, ordered by catalogs.
		This includes the subscriptions as a secondary user.
	**/
	public static function getActiveSubscriptionsByCatalog( user:db.User, group:db.Group ) : Map< db.Catalog, Array< db.Subscription > > {

		if( user == null || user.id == null ) throw new Error( 'Le membre que vous cherchez n\'existe pas');

		var memberSubscriptions = getActiveSubscriptions( user, group );
		var subscriptionsByCatalog = new Map<Catalog,Array<Subscription>>();
		for ( subscription in memberSubscriptions ) {

			if ( subscriptionsByCatalog[subscription.catalog] == null ) {
				subscriptionsByCatalog[subscription.catalog] = [];
			}
			subscriptionsByCatalog[subscription.catalog].push( subscription );
		}

		return subscriptionsByCatalog;
	}

	/**
		get next open ditrib
	**/
	public static function getComingOpenDistrib( catalog : db.Catalog ) : db.Distribution {
		var now = Date.now();		
		if ( catalog.type == db.Catalog.TYPE_VARORDER ) {
			return db.Distribution.manager.select( $catalog == catalog && $date > now && $orderStartDate <= now && $orderEndDate > now, { orderBy : date }, false );
		} else {
			return db.Distribution.manager.select( $catalog == catalog && $date > now && $orderEndDate > now, { orderBy : date }, false );
		}
	}


	public static function getOpenDistribsForSubscription( user:db.User, catalog:db.Catalog, currentOrComingSubscription:db.Subscription ) : Array<db.Distribution> {

		var openDistribs = new Array< db.Distribution >();

		if ( currentOrComingSubscription != null ) {
			openDistribs = getSubscriptionDistributions( currentOrComingSubscription, "open" );
		} else {
			var now = Date.now();
			openDistribs = db.Distribution.manager.search( $catalog == catalog && $orderStartDate <= now && $orderEndDate > now, { orderBy : date }, false ).array();
		}

		return openDistribs;
    }

	public static function getCurrentOrComingSubscription( user:db.User, catalog:db.Catalog ):db.Subscription
	{
		var comingOpenDistrib = getComingOpenDistrib( catalog );
		var fromDate = comingOpenDistrib != null ? comingOpenDistrib.date : Date.now();
		return db.Subscription.manager.select( $user == user && $catalog == catalog && $endDate >= fromDate, false );
	}

	public static function getUserCatalogSubscriptions( user : db.User, catalog : db.Catalog ) : Array<db.Subscription>
	{		
		if( user == null || user.id == null ) throw new Error( 'Le membre que vous cherchez n\'existe pas');
		return db.Subscription.manager.search( $user == user && $catalog == catalog , false ).array();
	}

	/**
		Get subscription distributions.
		@param type : "all" returns all distribs of subscription - except absence distribs.
	**/
	public static function getSubscriptionDistributions( subscription:db.Subscription, ?type='all' ) : Array<db.Distribution> {

		if( subscription == null ) throw new Error( 'La souscription n\'existe pas' );

		var subscriptionDistribs = new List();
		if ( type == "all" || type=="allIncludingAbsences") {
			subscriptionDistribs = db.Distribution.manager.search( $catalog == subscription.catalog && $date >= subscription.startDate && $end <= subscription.endDate, { orderBy : date }, false );
		} else if ( type == "open" ) {
			var now = Date.now();
			subscriptionDistribs = db.Distribution.manager.search( $catalog == subscription.catalog  && $orderStartDate <= now && $orderEndDate > now && $date >= subscription.startDate && $end <= subscription.endDate, { orderBy : date }, false );
		} else if ( type == "past" ) {
			var now = Date.now();
			var endOfToday = new Date( now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59 );			
			subscriptionDistribs = db.Distribution.manager.search( $catalog == subscription.catalog  && $end <= endOfToday && $date >= subscription.startDate && $end <= subscription.endDate, false );
		}
		
		if ( type != "allIncludingAbsences" && subscriptionDistribs.length>0 && subscription.catalog.hasAbsencesManagement() ) {
			//remove absence distribs
			var absentDistribs = subscription.getAbsentDistribs();
			for ( absentDistrib in absentDistribs ) {
				subscriptionDistribs = subscriptionDistribs.filter( distrib -> distrib.id != absentDistrib.id );
			}
		}
		
		return subscriptionDistribs.array();
	}

	public static function getSubscriptionRemainingDistribsNb( subscription : db.Subscription ) : Int {

		if( subscription == null ) return 0;

		var remainingSubscriptionDistribs = null;
		remainingSubscriptionDistribs = db.Distribution.manager.search( $catalog == subscription.catalog  && $date >= Date.now() && $end <= subscription.endDate, false );
			
		if ( remainingSubscriptionDistribs.length != 0 && subscription.catalog.hasAbsencesManagement() ) {

			var absentDistribs = subscription.getAbsentDistribs();
			for ( absentDistrib in absentDistribs ) {

				remainingSubscriptionDistribs = remainingSubscriptionDistribs.filter( distrib -> return distrib.id != absentDistrib.id );
			}
		}
		
		return remainingSubscriptionDistribs.length;
	}

	public static function getSubscriptionDistribsNb( subscription:db.Subscription, ?type:String, ?excludeAbsences=true ):Int {

		if( subscription == null ) throw new Error( 'La souscription n\'existe pas' );

		var subscriptionDistribsNb = 0;
		if ( type == null ) {
			subscriptionDistribsNb = db.Distribution.manager.count( $catalog == subscription.catalog && $date >= subscription.startDate && $end <= subscription.endDate );
		} else if ( type == "past" ) {
			var now = Date.now();
			var endOfToday = new Date( now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59 );			
			subscriptionDistribsNb = db.Distribution.manager.count( $catalog == subscription.catalog  && $date <= endOfToday && $date >= subscription.startDate && $end <= subscription.endDate );
		}

		if ( excludeAbsences ) {
			subscriptionDistribsNb = subscriptionDistribsNb - subscription.getAbsencesNb();
		}
		
		return subscriptionDistribsNb;
	}

	/**
		Get all the userOrders of a subscription
	**/
	public static function getSubscriptionAllOrders( subscription : db.Subscription ) : Array<db.UserOrder> {
		if( subscription == null || subscription.id == null ) return [];
		return db.UserOrder.manager.search( $subscription == subscription, false ).array();
	}

	/**
		@deprecated
		now the recurrent order is stored in subscription.defaultOrder
	**/
	public static function getCSARecurrentOrders( subscription:db.Subscription, oldAbsentDistribIds:Array<Int> ) : Array<db.UserOrder> {
		
		if( subscription == null || subscription.id == null ) return [];

		/*var oneDistrib = db.Distribution.manager.select( $catalog == subscription.catalog && $date >= subscription.startDate && $end <= subscription.endDate, false );
		if( oneDistrib == null ) return [];

		var oneDistriborders = db.UserOrder.manager.search( $subscription == subscription && $distribution == oneDistrib, false ).array();
		if ( oneDistriborders.length == 0 && subscription.getAbsencesNb() != 0 ) {

			var absentDistribIds = oldAbsentDistribIds;
			if ( absentDistribIds == null ) {

				absentDistribIds = subscription.getAbsentDistribIds();
			}
			var isAbsentDistrib = false;
			var presentDistribFound = false;
			while ( !presentDistribFound ) {

				isAbsentDistrib = false;
				for ( distribId in absentDistribIds ) {

					if ( oneDistrib != null && oneDistrib.id == distribId ) {

						isAbsentDistrib = true;
						oneDistrib = db.Distribution.manager.select( $catalog == subscription.catalog && $date > oneDistrib.date && $end <= subscription.endDate, false );
						break;
					}
				}

				presentDistribFound = !isAbsentDistrib;
			}

			oneDistriborders = db.UserOrder.manager.search( $subscription == subscription && $distribution == oneDistrib, false ).array();
		}
	
		return oneDistriborders;*/

		var distribs = getSubscriptionDistributions(subscription);
		var catalog = subscription.catalog;
		for(d in distribs){
			var orders = catalog.getUserOrders( subscription.user, d, false );
			if(orders.length>0) return orders;
		}

		return [];

	}

	/**
		Get contract constraints (no subscription for the current user)
	**/
	public static function getContractConstraints( catalog:db.Catalog ):String{
		var label = '';
		if ( catalog.isVariableOrdersCatalog() ) {

			if ( catalog.distribMinOrdersTotal>0 ) {				
				label += 'Commande obligatoire à chaque distribution d\'au moins ${catalog.distribMinOrdersTotal} €.';				
			}

			if(catalog.catalogMinOrdersTotal>0){
				var catalogMinOrdersTotal = getCatalogMinOrdersTotal(catalog);
				label += '<br />Total des commandes sur la durée du contrat d\'au moins ${catalogMinOrdersTotal} €.';
				if(catalogMinOrdersTotal != catalog.catalogMinOrdersTotal){
					label += '<br /><span class="disabled">A l\'origine ce minimum était de ${catalog.catalogMinOrdersTotal} € mais un prorata a été appliqué<br/>car des distributions ont déjà eu lieu.</span>';
				}
			}

		} else {
			label += "Contrat AMAP classique : votre commande est identique à chaque distribution.";
		}

		if( label == '' ) return null;
		return label;
	}

	/**
		Get constraints of a subscription
	**/
	public static function getSubscriptionConstraints( subscription:db.Subscription ):String{
		var out = [];
		var catalog = subscription.catalog;
		if ( catalog.isVariableOrdersCatalog() ) {
			//requires ordering + distribMinOrdersTotal
			if ( catalog.distribMinOrdersTotal>0 ) {				
				out.push('Commande obligatoire à chaque distribution d\'au moins ${catalog.distribMinOrdersTotal} €.');
			}

			// catalogMinOrdersTotal
			if(catalog.catalogMinOrdersTotal>0){
				var subscriptionDistribsNb = getSubscriptionDistribsNb( subscription, null, true );
				var catalogAllDistribsNb = db.Distribution.manager.count( $catalog == catalog );
				var ratio = subscriptionDistribsNb / catalogAllDistribsNb;
				// safer to do a "floor" than a "round"
				var catalogMinOrdersTotal = Math.floor(ratio * catalog.catalogMinOrdersTotal);
				var label = 'Total des commandes sur la durée du contrat d\'au moins $catalogMinOrdersTotal€.';
				if(subscriptionDistribsNb < catalogAllDistribsNb){
					label += '<br /><span class="disabled">Calculé au prorata de vos distributions : ${catalog.catalogMinOrdersTotal}€ x ($subscriptionDistribsNb/$catalogAllDistribsNb) = $catalogMinOrdersTotal€</span>';
				}
				out.push(label);
			}

		} else {

			var subscriptionOrders = getCSARecurrentOrders( subscription, null );
			if( subscriptionOrders.length == 0 ) return null;
			var label = "";
			for ( order in subscriptionOrders ) {
				label += tools.FloatTool.clean( order.quantity ) + ' x ' + order.product.name + '<br />';
			}
			label += "à chaque distribution.";
			out.push(label);

		}

		if( out.length==0 ) return null;
		return out.join("<br/>");
	}

	/**
	 * Checks subscription validity
	 */
	public function check( subscription:db.Subscription, ?previousStartDate:Date ) {

		//catalog must have the flag UsersCanOrder or user must have admin rights on catalog
		
		//if (!subscription.catalog.hasOpenOrders() && (!app.user.isContractManager() || !app.user.isAdmin() || !app.user.isGroupManager()))
		if (!subscription.catalog.hasOpenOrders() && !adminMode)
			{
				throw new Error("Les souscriptions à ce catalogue sont fermées. Veuillez contacter le coordinateur du contrat.");
			}
		
		
		//catalog should have distribs
		if(subscription.catalog.getDistribs().length==0){
			throw new Error("Ce catalogue n'a pas de distributions planifiées");
		}

		//startDate should be later than endDate
		if(subscription.startDate.getTime() >= subscription.endDate.getTime()){
			throw TypedError.typed( 'La date de début de la souscription doit être antérieure à la date de fin.', InvalidParameters );
		}

		//If not admin : start date should be next unclosed distrib, or later, but not before.
		if(!adminMode){
			var newSubscriptionStartDate = getNewSubscriptionStartDate( subscription.catalog );
			if ( newSubscriptionStartDate == null ) {
				throw TypedError.typed('Toutes les distributions futures sont déjà fermées, ou il n\'existe aucune distribution dans le futur.', InvalidParameters );
			}
			if( subscription.id == null ) {
				//new sub
				if ( subscription.startDate.getTime() < newSubscriptionStartDate.getTime() ) {
					throw TypedError.typed('La date de début de la souscription ne doit pas être avant la date de la prochaine distribution : ${Formatting.dDate(newSubscriptionStartDate)}', InvalidParameters );
				}
			} else {	
				//existing sub		
				if ( previousStartDate.toString() != subscription.startDate.toString() ) {
					if ( Date.now().getTime() <= subscription.startDate.getTime() && subscription.startDate.getTime() < newSubscriptionStartDate.getTime() ) {
						throw TypedError.typed('La date de début de la souscription ne doit pas être avant la date de la prochaine distribution : ${Formatting.dDate(newSubscriptionStartDate)}', InvalidParameters );
					}
				}
			}
		}
		
		var subName = ' (souscription de ${subscription.user.getName()})';

		//dates should be inside catalog dates
		var catalogStartDate = new Date( subscription.catalog.startDate.getFullYear(), subscription.catalog.startDate.getMonth(), subscription.catalog.startDate.getDate(), 0, 0, 0 );
		var catalogEndDate = new Date( subscription.catalog.endDate.getFullYear(), subscription.catalog.endDate.getMonth(), subscription.catalog.endDate.getDate(), 23, 59, 59 );
		if ( subscription.startDate.getTime() < catalogStartDate.getTime() || subscription.startDate.getTime() >= catalogEndDate.getTime() ) {
			throw new Error( 'La date de début de la souscription doit être comprise entre les dates de début et de fin du catalogue.'+subName );
		}
		if ( subscription.endDate.getTime() <= catalogStartDate.getTime() || subscription.endDate.getTime() > catalogEndDate.getTime() ) {
			throw new Error( 'La date de fin de la souscription doit être comprise entre les dates de début et de fin du catalogue.'+subName );
		}

		//dates overlap check
		var subscriptions1;
		var subscriptions2;	
		var subscriptions3;	
		//We are checking that there is no existing subscription with an overlapping time frame for the same user and catalog
		if ( subscription.id == null ) { //We need to check there the id as $id != null doesn't work in the manager.search

			//Looking for existing subscriptions with a time range overlapping the start of the about to be created subscription
			subscriptions1 = db.Subscription.manager.search( $user == subscription.user && $catalog == subscription.catalog 
															&& $startDate <= subscription.startDate && $endDate >= subscription.startDate, false );
			//Looking for existing subscriptions with a time range overlapping the end of the about to be created subscription
			subscriptions2 = db.Subscription.manager.search( $user == subscription.user && $catalog == subscription.catalog 
															&& $startDate <= subscription.endDate && $endDate >= subscription.endDate, false );	
			//Looking for existing subscriptions with a time range included in the time range of the about to be created subscription		
			subscriptions3 = db.Subscription.manager.search( $user == subscription.user && $catalog == subscription.catalog 
															&& $startDate >= subscription.startDate && $endDate <= subscription.endDate, false );	
		} else {
			//Looking for existing subscriptions with a time range overlapping the start of the about to be created subscription
			subscriptions1 = db.Subscription.manager.search( $user == subscription.user && $catalog == subscription.catalog && $id != subscription.id 
															&& $startDate <= subscription.startDate && $endDate >= subscription.startDate, false );
			//Looking for existing subscriptions with a time range overlapping the end of the about to be created subscription
			subscriptions2 = db.Subscription.manager.search( $user == subscription.user && $catalog == subscription.catalog && $id != subscription.id 
															&& $startDate <= subscription.endDate && $endDate >= subscription.endDate, false );	
			//Looking for existing subscriptions with a time range included in the time range of the about to be created subscription		
			subscriptions3 = db.Subscription.manager.search( $user == subscription.user && $catalog == subscription.catalog && $id != subscription.id 
															&& $startDate >= subscription.startDate && $endDate <= subscription.endDate, false );	
		}
			
		if ( subscriptions1.length != 0 || subscriptions2.length != 0 || subscriptions3.length != 0 ) {
			var subs = subscriptions1.concat(subscriptions2).concat(subscriptions3).array();
			subs = tools.ObjectListTool.deduplicate(subs);
			throw TypedError.typed( 'Il y a déjà une souscription pour ce membre pendant la période choisie.'+"("+subs.join(',')+")", OverlappingSubscription );
		}
	
		if ( subscription.id != null && hasPastDistribOrdersOutsideSubscription(subscription) && subscription.catalog.isVariableOrdersCatalog() ) {
			throw TypedError.typed( 
				'La nouvelle période sélectionnée exclue des commandes déjà passées, Il faut élargir la période sélectionnée $subName.',
				PastOrders
			);
		}
		
		if ( !adminMode && hasPastDistribsWithoutOrders( subscription ) ) {
			throw TypedError.typed(
				'La nouvelle période sélectionnée inclue des distributions déjà passées auxquelles le membre n\'a pas participé, Il faut choisir une date ultérieure $subName.',
				PastDistributionsWithoutOrders
			);
		}

	}

	/**
		Compute catalog minimum orders total.
		Can be used with catalog arg if subscription is not created yet.
	**/
	public static function getCatalogMinOrdersTotal( catalog:db.Catalog, ?subscription:db.Subscription ) : Float {

		if ( catalog.catalogMinOrdersTotal == 0 ) {
			return null;
		}

		var subscriptionDistribsNb = 0;
		if ( subscription != null ) {
			subscriptionDistribsNb = getSubscriptionDistribsNb( subscription, null, true );
		} else {
			subscriptionDistribsNb = db.Distribution.manager.count( $catalog == catalog && $date >= SubscriptionService.getNewSubscriptionStartDate( catalog ) );
		}
		
		var catalogAllDistribsNb = db.Distribution.manager.count( $catalog == catalog );
		if ( catalogAllDistribsNb == 0 ) return null;
		var ratio = subscriptionDistribsNb / catalogAllDistribsNb;

		// safer to do a "floor" than a "round"
		var catalogMinOrdersTotal = Math.floor(ratio * catalog.catalogMinOrdersTotal);

		//si paiements, le minimum à commander correspond à la provision déja payée
		/*if ( subscription != null ) {
			var subscriptionPayments = subscription.getPaymentsTotal();
			if ( subscriptionPayments != 0 && subscriptionPayments > catalogMinOrdersTotal) {
				return subscriptionPayments;
			}
		}*/

		return catalogMinOrdersTotal;
	}

	/**
		Convert orders to a map where the key is the related distribution
	**/
	public static function ordersToOrdersByDistrib(orders:Array<db.UserOrder>):Map<db.Distribution,Array<CSAOrder>>{
		var ordersByDistrib = new Map();

		for( order in orders ){

			var o:CSAOrder = {
				quantity : order.quantity,
				productPrice : order.productPrice,
				productId : order.product.id,
				invertSharedOrder : null,
				userId2 : null
			};     

			var d = order.distribution;
			var existing = ordersByDistrib.get(d);
			if(existing == null){
				ordersByDistrib.set(d,[o]);
			}else{
				existing.push(o);
				ordersByDistrib.set(d, existing );
			}
		}
		return ordersByDistrib;
	}


	/*
	 *	Checks if subscription orders meet all the catalog requirements.
	 */
	public static function areVarOrdersValid( subscription:db.Subscription ) : Bool {

		var catalog = subscription.catalog;		
		
		if ( catalog.distribMinOrdersTotal == 0  && catalog.catalogMinOrdersTotal == 0 ) {
			//nothing to check
			return true;
		}

		//get orders in correct format
		var allOrders = getSubscriptionAllOrders(subscription);
		if(allOrders.length==0) throw "Aucune commande dans cette souscription";
		var ordersByDistrib = ordersToOrdersByDistrib(allOrders);

		checkVarOrders(ordersByDistrib,subscription);

		return true;
	}

	/**
		Check if orders fit the catalog constraints : distribMinOrdersTotal and catalogMinOrdersTotal
		Can be used : 
		- at every order submission
		- but also when defining default order before subscribing
		- or update the default order
	**/
	public static function checkVarOrders(ordersByDistrib:Map<db.Distribution,Array<CSAOrder>>,?subscription:db.Subscription):Bool{
		var keys = [];
		for( k in ordersByDistrib.keys()) keys.push(k);
		if(keys.length==0) throw "Aucune distribution ouverte à la commande pour cette souscription";
		var catalog = keys.find(d -> d!=null).catalog;
		
		//Minimum by distribution
		var now = Date.now().getTime();
		if ( catalog.distribMinOrdersTotal > 0 ) {

			var distribTotal;
			for ( distrib in keys ) {

				//Do not check closed distribs. It allows to have non-fitting passed orders. 
				//(an admin may have modified passed orders, thus making them not fitting the constraint)
				if(distrib.orderEndDate.getTime() < now) continue;

				distribTotal = .0;
				for ( o in ordersByDistrib[distrib] ) {
					distribTotal += Formatting.roundTo( o.quantity * o.productPrice, 2 );
				}

				if ( distribTotal < catalog.distribMinOrdersTotal ) {
					var message = 'Distribution du ${Formatting.hDate( distrib.date )} : ';
					message += 'Le montant de votre commande doit être d\'au moins ${catalog.distribMinOrdersTotal} € par distribution.';
					throw TypedError.typed( message, CatalogRequirementsNotMet );					
				}
			}
		}

		//Catalog minimum orders total
		var catalogMinOrdersTotal = getCatalogMinOrdersTotal( catalog, subscription );
		if ( catalogMinOrdersTotal > 0 ) {

			//Computes orders total
			var ordersTotal = .0;
			var ordersDistribIds = [];
			for ( distrib in ordersByDistrib.keys() ) {
				ordersDistribIds.push( distrib.id );
				for ( o in ordersByDistrib[distrib] ) {
					ordersTotal += Formatting.roundTo( o.quantity * o.productPrice, 2 );
				}
			}

			//Checks that the orders total is higher than the required minimum
			/*var allDistribs = [];
			if(subscription!=null){
				allDistribs = getSubscriptionDistributions( subscription, 'all' );
			}else{
				allDistribs = catalog.getDistribs().array();
			}
			
			var lastDistrib = allDistribs[ allDistribs.length - 1 ];
			if( lastDistrib != null ) {

				var now = Date.now();
				var doCheckMin = false;
				var includeLastDistrib = ordersDistribIds.find( id -> id == lastDistrib.id ) != null;
				var lastDistribIsOpen = lastDistrib.orderStartDate.getTime() <= now.getTime() &&  now.getTime() < lastDistrib.orderEndDate.getTime();
				
				if ( includeLastDistrib && lastDistribIsOpen ) {*/
					if ( ordersTotal < catalogMinOrdersTotal ) {
						var message = 'Le total de vos commandes sur la durée du contrat est de $ordersTotal € '; 
						message += 'alors qu\'il doit être supérieur à $catalogMinOrdersTotal €. Vous devez commander plus pour respecter le contrat.';
						throw TypedError.typed( message, CatalogRequirementsNotMet );						
					}
			//	}
			//}

		}
		
		return true;
	}

	/**
		Find date of next unclosed distribution
	**/
	public static function getNewSubscriptionStartDate( catalog:db.Catalog ):Date {

		var notClosedComingDistrib = getComingOpenDistrib(catalog);
		
		if ( notClosedComingDistrib != null ) {
			return new Date( notClosedComingDistrib.date.getFullYear(), notClosedComingDistrib.date.getMonth(), notClosedComingDistrib.date.getDate(), 0, 0, 0 );
		} else {
			return null;
		}
	}

	 /**
		Creates a new subscription
		@param OrdersData : defaultOrder or recurrent order
	  */
	 public function createSubscription( user:db.User, catalog:db.Catalog, ?ordersData:Array<CSAOrder>, ?absenceDistribIds:Array<Int>,?absenceNb:Int,?startDate:Date, ?endDate:Date ):db.Subscription {

		if ( startDate == null ) startDate = getNewSubscriptionStartDate( catalog );
		if ( startDate == null ) throw "Aucune distribution non fermée dans le futur";
		if ( endDate == null ) 	endDate = catalog.endDate;
		
		//if the user is not a member of the group
		if(!user.isMemberOf(catalog.group)){
			if(catalog.group.regOption==RegOption.Open){
				user.makeMemberOf(catalog.group);
			}else{
				throw new Error(user.getName()+" n'est pas membre de "+catalog.group.name);
			}
		}

		var subscription = new db.Subscription();
		subscription.user = user;
		subscription.catalog = catalog;
		subscription.startDate 	= new Date( startDate.getFullYear(), startDate.getMonth(), startDate.getDate(), 0, 0, 0 );
		subscription.endDate 	= new Date( endDate.getFullYear()  , endDate.getMonth()  , endDate.getDate()  , 23, 59, 59 );

		//is there a secondary user in this subscription
		if( catalog.type == db.Catalog.TYPE_CONSTORDERS ) {
			var user2 = checkUser2( ordersData );
			subscription.user2 = db.User.manager.get( user2, false );
		}
		
		if(absenceDistribIds!=null){
			//absences are defined
			AbsencesService.setAbsences(subscription,absenceDistribIds,false);
		}else{
			//only absence number is defined, thus we get absence dates automatically
			var nb = absenceNb!=null ? absenceNb : 0; 
			AbsencesService.setAbsences(subscription,AbsencesService.getAutomaticAbsentDistribs(catalog, nb).map(d->d.id),false);
		}
		
		check(subscription);
		subscription.insert();

		if(catalog.hasDefaultOrdersManagement()){	
			//default orders is used only in constant orders, or variable orders with distribMinOrdersTotal
			try {
				this.updateDefaultOrders( subscription, ordersData );
			}catch(e:tink.core.Error) {
				throw (e);
			}
		}
		
		//Email notification
		sendSubscriptionCreatedEmail(subscription);
		
		return subscription;
	}

	function sendSubscriptionCreatedEmail(subscription:db.Subscription){
		var catalog = subscription.catalog;
		var html = '<p><b>Vous venez de souscrire au contrat AMAP "${catalog.name}" avec le paysan "${catalog.vendor.name}".</b></p>';
		
		html += "<p>";
		var engagement = SubscriptionService.getSubscriptionConstraints(subscription);
		html += 'Votre engagement : ${(engagement==null?"Aucun":engagement)}<br/>';
		html += 'Nombre de distributions : ${SubscriptionService.getSubscriptionDistribsNb(subscription)}<br/>';
		if(catalog.isVariableOrdersCatalog() && catalog.distribMinOrdersTotal>0){
			html += 'Votre commande par défaut est :<ul>';
			html += subscription.getDefaultOrders().map( o -> {
				var p = db.Product.manager.get(o.productId,false);
				return '<li>${o.quantity} x ${p.getName()} : ${o.quantity*p.price} €</li>';
			} ).join('');
			html += '</ul>C\'est un contrat AMAP variable, votre commande est donc modifiable date par date<br/>';
		}else if(catalog.isConstantOrdersCatalog()){
			html += 'Vous recevrez à chaque distribution les produits suivants :<ul>';
			html += subscription.getDefaultOrders().map( o -> {
				var p = db.Product.manager.get(o.productId,false);
				return '<li>${o.quantity} x ${p.getName()} : ${o.quantity*p.price} €</li>';
			} ).join('');
			html += '</ul>';
		}
		html += "</p>";

		if(catalog.hasAbsencesManagement()){
			var absentDistribs = subscription.getAbsentDistribs();
			var absencesTxt = absentDistribs.map( d -> Formatting.hDate(d.date) ).join(", ");
			html += '<p>Vous avez choisi d\'être absent(e) pendant ${absentDistribs.length} distributions : $absencesTxt.</p>';
		}

		if(catalog.isVariableOrdersCatalog()){
			if(catalog.distribMinOrdersTotal>0){
				html += '<p>Merci de préparer un/des chèque(s) de provision correspondant au total de votre commande par défaut multiplié par le nombre de distributions, soit ${subscription.getTotalPrice()} €. ';
				html += 'Une régularisation pourra être demandée en fin de contrat en fonction de votre solde.</p>';
				html += 'Si un contrat papier est associé à votre souscription, pensez à le compléter et à remettre le(s) chèque(s).</br>';	
			}else if(catalog.catalogMinOrdersTotal>0){
				html += '<p>Merci de préparer un/des chèque(s) correspondant au montant total de votre commande à consulter dans l\'onglet \"Mes contrats\". ';
				html += 'Une régularisation pourra être demandée en fin de contrat en fonction de votre solde si vous modifiez vos commandes.</p>';
				html += 'Si un contrat papier est associé à votre souscription, pensez à le compléter et à remettre le(s) chèque(s).</br>';	
			}
			else {
				html += '<p>Merci de préparer un/des chèque(s) correspondant au montant total de votre commande à consulter dans l\'onglet \"Mes contrats\". ';
				html += 'Une régularisation pourra être demandée en fin de contrat en fonction de votre solde si vous modifiez vos commandes.</p>';
				html += 'Si un contrat papier est associé à votre souscription, pensez à le compléter et à remettre le(s) chèque(s).</br>';	
			}
			
		}else{
			html += '<p>Si un contrat papier est associé à votre souscription, pensez à le compléter et à remettre le(s) chèque(s) pour un total de ${subscription.getTotalPrice()} €.</p>';
		}
		
		App.quickMail(subscription.user.email,'Souscription au contrat "${catalog.name}"',html,catalog.group);
	}

	public static function checkUser2(ordersData:Array<CSAOrder>):Int{
		//check that there is only one secondary user
		var user2 = null;
		for( order in ordersData){
			if(order.userId2!=null){
				if(user2==null){
					user2=order.userId2;
				}else if(user2!=order.userId2){
					throw new Error("Il n'est pas possible d'alterner vos paniers avec plusieurs personnes. Choisissez un seul binôme.");
				}
			}
		}
		return user2;
	}

	/**
		Update an existing subscription.
		Optionnaly updates recurrent order(CONST) or default order(VAR) with ordersData param
	**/
	public function updateSubscription( subscription:db.Subscription, startDate:Date, endDate:Date, ?ordersData:Array<CSAOrder>) {

		if ( startDate == null || endDate == null ) {
			throw new Error( 'La date de début et de fin de la souscription doivent être définies.' );
		}

		subscription.lock();

		var previousStartDate = subscription.startDate;
	
		subscription.startDate = new Date( startDate.getFullYear(), startDate.getMonth(), startDate.getDate(), 0, 0, 0 );
		subscription.endDate = new Date( endDate.getFullYear(), endDate.getMonth(), endDate.getDate(), 23, 59, 59 );
		
		//check secondary user for CONSTORDERS
		if(subscription.catalog.isConstantOrdersCatalog() && ordersData!=null){
			var userId2 = checkUser2(ordersData);
			if(userId2!=null){
				subscription.user2 = db.User.manager.get(userId2,false);
			}
		}
		
		check(subscription,previousStartDate);

		subscription.update();

		if(subscription.catalog.hasDefaultOrdersManagement() && ordersData!=null){
			updateDefaultOrders( subscription, ordersData );						
		}
	}

	public static function getOperations( subscription : db.Subscription, ?lock=false):Array<db.Operation>{
		return db.Operation.manager.search( $subscription == subscription, { orderBy : -date }, lock ).array();
	}

	 /**
	  *  Deletes a subscription if there is no orders that occurred in the past
	  */
	public static function deleteSubscription( subscription : db.Subscription ) {
		
		subscription.lock();

		if ( hasPastDistribOrders( subscription ) ) {
			throw TypedError.typed( 'Impossible de supprimer cette souscription car il y a des distributions passées avec des commandes.', PastOrders );
		}

		//cant delete if some payment has been recorded
		if ( db.Operation.manager.count( $subscription == subscription && $type==Payment ) > 0 ) {
			throw new Error( 'Impossible de supprimer cette souscription car il y a des paiements enregistrés.' );
		}

		//Delete all the orders for this subscription
		var subscriptionOrders = db.UserOrder.manager.search( $subscription == subscription, false );
		for ( order in subscriptionOrders ) {
			OrderService.delete(order,true);
		}

		//Delete all the operations for this subscription
		for ( operation in getOperations(subscription,true) ) operation.delete();
		
		service.PaymentService.updateUserBalance( subscription.user, subscription.catalog.group );
		subscription.delete();
	}

	/**
		*  Checks whether there are orders with non zero quantity in the past
		*/
		
	public static function hasPastDistribOrders( subscription:db.Subscription ) : Bool {
		if ( !hasPastDistributions( subscription ) ) {
			return false;
		} else {
			var pastDistributions = getSubscriptionDistributions( subscription, 'past' );
			for ( distribution in pastDistributions ) {
				if ( db.UserOrder.manager.count( $distribution == distribution && $subscription == subscription && $quantity>0 ) > 0 ) {					
					return true;
				}
			}
		}		
		return false;		
	}

	public static function hasPastDistribOrdersOutsideSubscription( subscription : db.Subscription ) : Bool {
		
		var now = Date.now();
		var endOfToday = new Date( now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59 );
		var orders =  db.UserOrder.manager.search( $subscription == subscription, false ).array();
		for ( order in orders ) {

			if ( order.distribution != null ) {

				if ( order.distribution.date.getTime() <= endOfToday.getTime() && ( order.distribution.date.getTime() < subscription.startDate.getTime() || order.distribution.date.getTime() > subscription.endDate.getTime() ) ) {					
					return true;
				}
			}
			
		}
		
		return false;
		
	}

	public static function hasPastDistribsWithoutOrders( subscription : db.Subscription ) : Bool {

		if ( !hasPastDistributions( subscription ) ) {

			return false;

		} else if ( /*( subscription.catalog.type == db.Catalog.TYPE_VARORDER && subscription.catalog.requiresOrdering ) ||*/ subscription.catalog.type == db.Catalog.TYPE_CONSTORDERS ) {
			//fbarbut 2021-01-13 : on ne veut pas bloquer les commandes si le contrat est variable avec commande obligatoires, et qu'il y a des distributions sans commandes.
			var pastDistributions = getSubscriptionDistributions( subscription, 'past' );
			for ( distribution in pastDistributions ) {
				if ( db.UserOrder.manager.count( $distribution == distribution && $subscription == subscription ) == 0 ) {
					return true;
				}
			}
		}
		return false;
	}

	
	public static function hasPastDistributions( subscription : db.Subscription ) : Bool {
		return getSubscriptionDistribsNb( subscription, 'past' ) != 0;
	}

	/**
		(re)create contract's recurrent orders.
		If contract is CONST : recreate all orders, not possible if there is orders in the past
		if contract is VAR : recreate all orders of future open distribs. 
	**/
	public function createRecurrentOrders(subscription:db.Subscription, ordersData:Array<CSAOrder>) : Array<db.UserOrder> {

		var catalog = subscription.catalog;
		if(ordersData==null) {
			ordersData = subscription.getDefaultOrders();
		}

		//delete existing userOrders
		var subscriptionAllOrders = getSubscriptionAllOrders(subscription);
		var now = Date.now().getTime();
		for ( order in subscriptionAllOrders ) {

			if( catalog.isVariableOrdersCatalog() && order.distribution.orderEndDate.getTime() < now ){
				//if catalog is variable and distrib is closed, do not delete order
				continue;
			}

			OrderService.delete(order,true);
		}
	
		//recreate orders
		var t = sugoi.i18n.Locale.texts;	
		var orders : Array<db.UserOrder> = [];
		for ( distribution in getSubscriptionDistributions(subscription) ) {

			if( catalog.isVariableOrdersCatalog() && distribution.orderEndDate.getTime() < now ){
				//if catalog is variable and distrib is closed, do not recreate order
				continue;
			}

			for ( order in ordersData ) {
				if ( order.quantity > 0 ) {
					var product = db.Product.manager.get( order.productId, false );
					// User2 + Invert
					var user2 : db.User = null;
					var invert = false;
					if ( order.userId2 != null && order.userId2 != 0 ) {

						user2 = db.User.manager.get( order.userId2, false );
						if ( user2 == null ) throw new Error( 'Impossible de trouver l\'utilisateur #${order.userId2}' );
						if ( subscription.user.id == user2.id ) throw new Error( "Les deux comptes sélectionnés doivent être différents" );
						if ( !user2.isMemberOf( product.catalog.group ) ) throw new Error( 'L\'utilisateur #${user2} ne fait pas partie de ce groupe' );
						
						invert = order.invertSharedOrder;
					}
					var newOrder=null;
					try {
						newOrder =  OrderService.make( subscription.user, order.quantity , product,  distribution.id, false, subscription, user2, invert );
					}catch(e:tink.core.Error) {
						throw new Error(e.message);
					}
					if ( newOrder != null ) orders.push( newOrder );
				}
			}
		}
		
		App.current.event( MakeOrder( orders ) );
		
		createOrUpdateTotalOperation( subscription );

		return orders;	
	}	

	/*public static function getLastDistribBeforeAbsences( catalog:db.Catalog ) : db.Distribution {

		if ( !catalog.hasAbsencesManagement() ) return null;
		
		var catalogDistribs = catalog.getDistribs( false ).array();
		var lastDistribBeforeAbsences : db.Distribution = catalogDistribs[0];
		for ( distrib in catalogDistribs ) {

			if ( distrib.date.getTime() < catalog.absencesStartDate.getTime() ) {
				lastDistribBeforeAbsences = distrib;
			} else {
				break;
			}
		}

		return lastDistribBeforeAbsences;
	}*/

	/**
		Update default orders (store it in the subscription entity) and create the recurrent UserOrders
		DefaultOrders can be on a variable contract 
		Or can be the recurring order of a constant CSA contrat
	**/
	public function updateDefaultOrders( subscription:db.Subscription, defaultOrders:Array<CSAOrder>){

		if( subscription == null ) throw new Error( 'La souscription n\'existe pas' );	

		defaultOrders = defaultOrders.filter(o -> o.quantity > 0);

		subscription.lock();	
		/*if( subscription.catalog.isVariableOrdersCatalog()){
			if ( subscription.catalog.distribMinOrdersTotal>0 && (defaultOrders==null || defaultOrders.length==0 ) ) {
				throw new Error('La commande par défaut ne peut pas être vide. (Souscription de ${subscription.user.getName()})');
			}
		}else{*/
			if ( defaultOrders==null || defaultOrders.length==0 ) {
				throw new Error('La commande par défaut ne peut pas être vide. (Souscription de ${subscription.user.getName()})');
			}
		//}	

		//if constantOrders, the user (not admin) cannot edit default orders if sub has past distrib orders
		if(subscription.catalog.isConstantOrdersCatalog()){
			if ( hasPastDistribOrders(subscription) && !adminMode ) {
				throw TypedError.typed( 'Il y a des commandes pour des distributions passées. Les commandes du passé ne pouvant être modifiées, il faut recréer une nouvelle souscription avec une nouvelle commande.', SubscriptionServiceError.PastOrders );
			}
		}
		
		try {
			createRecurrentOrders( subscription, defaultOrders );
		}catch(e:tink.core.Error) {
			throw typedError(e.message,OtherError);
		}

		//check if default Orders meet the catalog requirements
		if( subscription.catalog.isVariableOrdersCatalog()){			
			areVarOrdersValid(subscription);
		}
		
		subscription.defaultOrders = haxe.Json.stringify( defaultOrders );
		subscription.update();

	}

	public static function createOrUpdateTotalOperation( subscription:db.Subscription ) : db.Operation {

		if( subscription == null )  throw new Error( 'Pas de souscription fournie.' );

		var totalOperation = db.Operation.manager.select ( $user == subscription.user && $subscription == subscription && $type == SubscriptionTotal, true );

		if( totalOperation == null ) {
			totalOperation = new db.Operation();
			totalOperation.name = "Total Commandes";
			totalOperation.type = SubscriptionTotal;
			totalOperation.user = subscription.user;
			totalOperation.subscription = subscription;
			totalOperation.group = subscription.catalog.group;
			totalOperation.pending = false;
		}

		//create or update it if needed
		var currentTotalPrice = subscription.getTotalPrice();
		if( totalOperation.id == null || totalOperation.amount != (0 - currentTotalPrice) ) {

			totalOperation.date = Date.now();
			totalOperation.amount = 0 - currentTotalPrice;
	
			if ( totalOperation.id != null ) {
				totalOperation.update();
			} else {		
				totalOperation.insert();
			}
	
			service.PaymentService.updateUserBalance( totalOperation.user, totalOperation.group );
		}			
		
		return totalOperation;
	}

	// public static function updateCatalogSubscriptionsOperation( catalog : db.Catalog ) {
	// 	for ( subscription in SubscriptionService.getCatalogSubscriptions(catalog) ) {
	// 		createOrUpdateTotalOperation( subscription );
	// 	}
	// }

	public static function transferBalance( fromSubscription : db.Subscription, toSubscription : db.Subscription ) {

		var balance = fromSubscription.getBalance();
		
		if( fromSubscription == null || toSubscription == null )  throw new Error( 'Pas de souscriptions fournies.' );
		if( fromSubscription.user.id != toSubscription.user.id )  throw new Error( 'Le transfert est possible uniquement pour un même membre.' );
		/** Permettre de transférer une souscription négative **/
		/*
		if( balance <= 0 ) throw new Error( 'Impossible de transférer un solde négatif ou à zéro.' );
		*/
		var operationFrom = new db.Operation();
		operationFrom.name = "Transfert du solde sur la souscription #" + toSubscription.id + " de " + toSubscription.catalog.name;
		operationFrom.type = Payment;
		operationFrom.setPaymentData( { type : 'transfer' } );
		operationFrom.user = fromSubscription.user;
		operationFrom.subscription = fromSubscription;
		operationFrom.group = fromSubscription.catalog.group;
		operationFrom.pending = false;
		operationFrom.date = Date.now();
		operationFrom.amount = 0 - balance;

		var operationTo = new db.Operation();
		operationTo.name = "Transfert du solde de la souscription #" + fromSubscription.id + " de " + fromSubscription.catalog.name;
		operationTo.type = Payment;
		operationTo.setPaymentData( { type : 'transfer' } );
		operationTo.user = toSubscription.user;
		operationTo.subscription = toSubscription;
		operationTo.group = toSubscription.catalog.group;
		operationTo.pending = false;
		operationTo.date = Date.now();
		operationTo.amount = balance;

		operationFrom.insert();
		operationTo.insert();
	
		service.PaymentService.updateUserBalance( fromSubscription.user, fromSubscription.catalog.group );
		if( fromSubscription.catalog.group.id != toSubscription.catalog.group.id  ) {
			service.PaymentService.updateUserBalance( fromSubscription.user, toSubscription.catalog.group );
		}

	}

	/*public static function getDistribOrdersAverageTotal( subscription : db.Subscription ) : Float {

		if( subscription == null || subscription.id == null )  throw new Error( 'Pas de souscription fournie.' );
		var distribsOrderedNb = sys.db.Manager.cnx.request('SELECT COUNT(DISTINCT distributionId) FROM UserOrder WHERE subscriptionId=${subscription.id}').getIntResult(0);
		if( distribsOrderedNb == 0 ) return 0;
		return subscription.getTotalPrice() / distribsOrderedNb;
	}*/
	
}