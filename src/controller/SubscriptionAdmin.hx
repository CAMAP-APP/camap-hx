package controller;
import service.AbsencesService;
import sugoi.form.elements.Html;
import service.PaymentService;
import sugoi.Web;
import payment.Check;
import sugoi.db.Cache;
import db.Catalog;
import db.Operation.OperationType;
import service.SubscriptionService;
import tink.core.Error;

class SubscriptionAdmin extends controller.Controller
{
	public function new(){
		super();		
	}
	
	/**
		View all the subscriptions for a catalog
	**/
	@tpl("contractadmin/subscriptionadmin/default.mtt")
	function doDefault( catalog : db.Catalog ) {

		if ( !app.user.canManageContract( catalog ) ) throw Error( '/', t._('Access forbidden') );

		var catalogSubscriptions = SubscriptionService.getCatalogSubscriptions(catalog);

		//subs sorting
		var orderBy = app.params.get("orderBy");
		if(orderBy=="userName" || orderBy==null){
			catalogSubscriptions.sort( (a,b) -> a.user.lastName.toUpperCase() > b.user.lastName.toUpperCase() ? 1 : -1);
			orderBy = "userName";
		}
		view.orderBy = orderBy;
		view.catalog = catalog;
		view.c = catalog;
		view.subscriptions = catalogSubscriptions;
		view.negativeBalanceCount = catalogSubscriptions.count( sub -> sub.getBalance() < 0 );
		view.subscriptionService = SubscriptionService;
		view.nav.push( 'subscriptions' );

		//generate a token
		checkToken();
	}
	
	public function doDelete( subscription : db.Subscription ) {
		
		if ( !app.user.canManageContract( subscription.catalog ) ) throw Error( '/', t._('Access forbidden') );
		
		var subscriptionUser = subscription.user;
		if ( checkToken() ) {
			try {
				SubscriptionService.deleteSubscription( subscription );
			} catch( error : Error ) {
				throw Error( '/contractAdmin/subscriptions/' + subscription.catalog.id, error.message );
			}
			throw Ok( '/contractAdmin/subscriptions/' + subscription.catalog.id, 'La souscription pour ${subscriptionUser.getName()} a bien été supprimée.' );
		}
		throw Error( '/contractAdmin/subscriptions/' + subscription.catalog.id, t._("Token error") );
	}

	@tpl("contractadmin/subscriptionadmin/editsubscription.mtt")
	public function doInsert( catalog : db.Catalog ) {

		if ( !app.user.canManageContract( catalog ) ) throw Error( '/', "Accès interdit" );

		var subscriptionService = new SubscriptionService();
		subscriptionService.adminMode = true;

		var catalogProducts = catalog.getProducts();

		var startDateDP = new form.CamapDatePicker("startDate","Date de début", SubscriptionService.getNewSubscriptionStartDate( catalog ) );
		view.startDate = startDateDP;
		var endDateDP = new form.CamapDatePicker("endDate","Date de fin",catalog.endDate);
		view.endDate = endDateDP;

		if ( checkToken() ) {

			try {				
				var userId = Std.parseInt( app.params.get( "user" ) );
				if ( userId == null || userId == 0 ) {
					throw Error( '/contractAdmin/subscriptions/insert/' + catalog.id, 'Veuillez sélectionner un membre.' );
				}
				var user = db.User.manager.get( userId, false );
				if ( user == null ) {
					throw Error( '/contractAdmin/subscriptions/insert/' + catalog.id, 'impossible de trouver l\'utilisateur $userId' );
				}
				if ( !user.isMemberOf( catalog.group ) ) {
					throw Error( '/contractAdmin/subscriptions/insert/'+catalog.id, user + " ne fait pas partie de ce groupe" );
				}
				
				startDateDP.populate();
				endDateDP.populate();
				var startDate = startDateDP.getValue();
				var endDate = endDateDP.getValue();

				if ( startDate == null || endDate == null ) {
					throw Error( '/contractAdmin/subscriptions/insert/' + catalog.id, "Vous devez sélectionner une date de début et de fin pour la souscription." );
				}
				
				var ordersData = new Array<CSAOrder>();
				if(catalog.hasDefaultOrdersManagement()){
					for ( product in catalogProducts ) {

						var quantity : Float = 0;
						var qtyParam = app.params.get( 'quantity' + product.id );
						if ( qtyParam != "" ) quantity = Std.parseFloat( qtyParam );
						var user2 : db.User = null;
						var userId2 : Int = null;
						if( catalog.type == Catalog.TYPE_CONSTORDERS ) {
							userId2 = Std.parseInt( app.params.get( 'user2' + product.id ) );
						}
						var invert = false;
						if ( userId2 != null && userId2 != 0 ) {
	
							user2 = db.User.manager.get( userId2, false );
							if ( user2 == null ) {
								throw Error( '/contractAdmin/subscriptions/insert/' + catalog.id, 'impossible de trouver l\'utilisateur $userId2' );
							}
							if ( !user2.isMemberOf( catalog.group ) ) {
								throw Error( '/contractAdmin/subscriptions/insert/' + catalog.id, user + " ne fait pas partie de ce groupe." );
							}
							if ( user.id == user2.id ) {
								throw Error( '/contractAdmin/subscriptions/insert/' + catalog.id, "Vous ne pouvez pas alterner avec la personne qui a la souscription." );
							}
							invert = app.params.get( 'invert' + product.id ) == "true";
						}
	
						if ( quantity != 0 ) {
							if( catalog.isConstantOrdersCatalog() ) {
								ordersData.push({ 
									productId : product.id,
									productPrice : product.price,
									quantity : quantity,
									userId2 : userId2,
									invertSharedOrder : invert
								});
							} else {
								ordersData.push({ 
									productId : product.id,
									productPrice : product.price,
									quantity : quantity 
								});
							}
						}					
					}
				}

				//absences
				var absenceDistribIds = [];
				for( i in 1...catalog.absentDistribsMaxNb+1){
					var p = app.params.get('absence'+i).parseInt();
					if(p!=null && p>0){
						absenceDistribIds.push(p);
					}
				}
		
				subscriptionService.createSubscription( user, catalog, ordersData, absenceDistribIds, null, startDate, endDate );
				throw Ok( '/contractAdmin/subscriptions/' + catalog.id, 'La souscription pour ' + user.getName() + ' a bien été ajoutée.' );

			} catch( error : Error ) {
				throw Error( '/contractAdmin/subscriptions/insert/' + catalog.id, error.message );
			}
		}
			
		view.edit = false;
		view.canOrdersBeEdited = true;
		view.c = catalog;
		view.catalog = catalog;
		view.members = app.user.getGroup().getMembersFormElementData();
		view.products = catalogProducts;
		view.subscriptionService = SubscriptionService;
		view.nav.push( 'subscriptions' );

		if(catalog.hasAbsencesManagement()){
			
			//possible absences of this catalog
			var absences = AbsencesService.getContractAbsencesDistribs(catalog);
			var now = Date.now().getTime();
			view.possibleAbsences = absences.filter(d -> d.orderEndDate.getTime() > now);
			view.lockedDistribs = absences.filter( d -> d.orderEndDate.getTime() < now);	//absences that are not editable anymore

			//no select absentDistribs because we're creating a subscription
			view.absentDistribs = [];	
			
			view.isSelected = function(i:Int,d:db.Distribution){
				return false;
			};	
		}
	}

	/**
		An admin user edits a subscription
	**/
	@tpl("contractadmin/subscriptionadmin/editsubscription.mtt")
	public function doEdit( subscription:db.Subscription ) {

		if ( !app.user.canManageContract( subscription.catalog ) ) throw Error( '/', t._('Access forbidden') );

		var catalogProducts = subscription.catalog.getProducts();

		var startDateDP = new form.CamapDatePicker("startDate","Date de début",subscription.startDate);
		var endDateDP = new form.CamapDatePicker("endDate","Date de fin",subscription.endDate);
		view.endDate = endDateDP;
		view.startDate = startDateDP;

		var subscriptionService = new service.SubscriptionService();
		subscriptionService.adminMode = true;

		if ( checkToken() ) {

			try {
				startDateDP.populate();
				endDateDP.populate();
				var startDate = startDateDP.getValue();
				var endDate = endDateDP.getValue();
				subscription.lock();

				if ( startDate == null || endDate == null ) {
					throw Error( '/contractAdmin/subscriptions/edit/' + subscription.id, "Vous devez sélectionner une date de début et de fin pour la souscription." );
				}

				var ordersData = new Array<CSAOrder>();
				if(subscription.catalog.hasDefaultOrdersManagement()){
					//get default orders from the form 					
					for ( product in catalogProducts ) {

						var quantity : Float = 0;
						var qtyParam = app.params.get( 'quantity' + product.id );
						if ( qtyParam != "" ) quantity = Std.parseFloat( qtyParam );
						var user2 : db.User = null;
						var userId2 : Int = null;
						if( subscription.catalog.type == Catalog.TYPE_CONSTORDERS ) {							
							userId2 = Std.parseInt( app.params.get( 'user2' + product.id ) );
						}
						var invert = false;
						if ( userId2 != null && userId2 != 0 ) {

							user2 = db.User.manager.get( userId2, false );
							if ( user2 == null ) {
								throw Error( '/contractAdmin/subscriptions/edit/' + subscription.id, 'impossible de trouver l\'utilisateur $userId2' );
							}

							if ( !user2.isMemberOf( subscription.catalog.group ) ) {
								throw Error( '/contractAdmin/subscriptions/edit/' + subscription.id, subscription.user + " ne fait pas partie de ce groupe." );
							}

							if ( subscription.user.id == user2.id ) {
								throw Error( '/contractAdmin/subscriptions/edit/' + subscription.id, "Vous ne pouvez pas alterner avec la personne qui a la souscription." );
							}

							invert = app.params.get( 'invert' + product.id ) == "true";
						}

						if ( quantity!=null && quantity > 0 ) {
							if( subscription.catalog.isConstantOrdersCatalog() ) {
								ordersData.push( { 
									productId : product.id,
									productPrice : product.price,
									quantity : quantity,
									userId2 : userId2,
									invertSharedOrder : invert
								} );
							} else {
								ordersData.push( { 
									productId : product.id,
									productPrice: product.price,
									quantity : quantity
								} );
							}
						}						
					}
				}
				
				//absences
				var absenceDistribIds = [];
				for( i in 1...subscription.catalog.absentDistribsMaxNb+1){
					var p = app.params.get('absence'+i).parseInt();
					if(p!=null && p>0){
						absenceDistribIds.push(p);
					}
				}

				// Vérifier qu'on n'a pas d'absence postérieure à la date de fin de souscription
				// en cas de modification de la souscription

				for (id in absenceDistribIds){
					var d = db.Distribution.manager.get(id,false);
					if(d!=null && d.date.getTime()>subscription.endDate.getTime()){
						throw Error( '/contractAdmin/subscriptions/edit/' + subscription.id, "Vous ne pouvez pas sélectionner une absence postérieure à la date de fin de souscription. Vous devez d'abord modifier l'absence." );
					}
				}

				subscriptionService.updateSubscription( subscription, startDate, endDate, ordersData);
				
				// Test if absences have been updated
				var oldDistributionIds = subscription.getAbsentDistribIds();
				
				if(absenceDistribIds.join("-") != oldDistributionIds.join("-")){
					AbsencesService.updateAbsencesDates(subscription,absenceDistribIds, true);
				}
				subscription.update();

			} catch( error : Error ) {				
				throw Error( '/contractAdmin/subscriptions/edit/${subscription.id}', error.message );
			}

			throw Ok( '/contractAdmin/subscriptions/${subscription.catalog.id}', 'La souscription de ${subscription.user.getName()} a bien été mise à jour.' );
		}

		view.edit = true;
		// view.canOrdersBeEdited = canOrdersBeEdited;
		view.c = subscription.catalog;
		view.catalog = subscription.catalog;
		view.members = app.user.getGroup().getMembersFormElementData();
		view.products = catalogProducts;
		var defaultOrders = subscription.getDefaultOrders();
		view.getProductOrder = function( productId : Int ) {
			var csaOrder = null;
			for (o in defaultOrders) {
				if (o.productId == productId) {
					if (csaOrder == null) {
						csaOrder = o;
					} else {
						// if multiple lines for the same product (ie. multiWeight), then accumulate quantities.
						csaOrder.quantity += o.quantity;
					}
				}
			}
			return csaOrder;
		};
		view.startdate = subscription.startDate;
		view.enddate = subscription.endDate;
		view.subscription = subscription;
		view.nav.push( 'subscriptions' );
		view.subscriptionService = SubscriptionService;
		
		// if ( subscription.catalog.hasAbsencesManagement() ) {
		// 	view.absencesDistribDates = Lambda.map( SubscriptionService.getAbsencesDistribs( subscription.catalog, subscription ), function( distrib ) return Formatting.dDate( distrib.date ) );
		// 	view.absentDistribs = subscription.getAbsentDistribs();		
		// }
		if(subscription.catalog.hasAbsencesManagement()){
			
			//possible absences of this catalog
			var absences = subscription.getPossibleAbsentDistribs();
			var now = Date.now().getTime();
			view.possibleAbsences = absences.filter(d -> d.orderEndDate.getTime() > now);
			view.lockedDistribs = absences.filter( d -> d.orderEndDate.getTime() < now);	//absences that are not editable anymore

			//subscription absences
			var absentDistribs = subscription.getAbsentDistribIds();
			view.absentDistribs = absentDistribs;
			view.isSelected = function(i:Int,d:db.Distribution){
				return absentDistribs[i-1]==d.id;
			};	
		}

	}

	@tpl("contractadmin/subscriptionpayments.mtt")
	public function doPayments( subscription : db.Subscription ) {

		if ( !app.user.canManageContract( subscription.catalog ) ) throw Error( '/', t._('Access forbidden') );

		var totalOperation;
		if(subscription.catalog.isActive()){
			totalOperation = SubscriptionService.createOrUpdateTotalOperation( subscription );
		}else{
			totalOperation = subscription.getTotalOperation();
		}
		
		view.subscriptionTotal = totalOperation;

		var user = subscription.user;
		view.payments = db.Operation.manager.search( $user == user && $subscription == subscription && $type == Payment, { orderBy : -date }, false );
		view.member = user;
		view.subscription = subscription;
		
		view.nav.push( 'subscriptions' );
		view.c = subscription.catalog;
		
		checkToken();
	}

	@tpl("contractadmin/subscriptionbalancetransfer.mtt")
	public function doBalanceTransfer( subscription : db.Subscription ) {

		if ( !app.user.canManageContract( subscription.catalog ) ) throw Error( '/', t._('Access forbidden') );
		/** Permettre le transfert de souscriptions négatives 
		*/
		/*
		 if ( subscription.getBalance() <= 0 ) throw Error( '/contractAdmin/subscriptions/payments/' + subscription.id, 'Le solde doit être positif pour pouvoir le transférer sur une autre souscription.' );
		*/
		var subscriptionsChoices = SubscriptionService.getUserVendorNotClosedSubscriptions( subscription );
		if ( subscriptionsChoices.length == 0  ) throw Error( '/contractAdmin/subscriptions/payments/' + subscription.id, 'Ce membre n\'a pas d\'autre souscription. Veuillez en créer une nouvelle avec le même producteur.' );

		if ( checkToken() ) {
			try {
				var subscriptionId = Std.parseInt( app.params.get( 'subscription' ) );
				if ( subscriptionId == null ) throw Error( '/contractAdmin/subscriptions/balanceTransfer/' + subscription.id, "Vous devez sélectionner une souscription." );

				var selectedSubscription = db.Subscription.manager.get( subscriptionId );
				SubscriptionService.transferBalance( subscription, selectedSubscription );
				
			} catch( error : Error ) {
				throw Error( '/contractAdmin/subscriptions/balanceTransfer/' + subscription.id, error.message );
			}

			throw Ok( '/contractAdmin/subscriptions/payments/' + subscription.id, 'Le transfert a bien été effectué.' );
		}

		view.title = "Report de solde pour " + subscription.user.getName();
		view.c = subscription.catalog;
		view.subscriptions = subscriptionsChoices;
		view.nav.push( 'subscriptions' );
	}

	/**
	 * inserts a payment for a CSA contract
	 */
	@tpl('form.mtt')
	public function doInsertPayment( subscription : db.Subscription ) {
		
		if (!app.user.isContractManager()) throw Error("/", t._("Action forbidden"));	
		var t = sugoi.i18n.Locale.texts;

		var group = subscription.catalog.group;
		
		var returnUrl = '/contractAdmin/subscriptions/payments/${subscription.id}';
		var form = new sugoi.form.Form("payement");

		form.addElement( new sugoi.form.elements.Html( "subscription", '<div class="control-label" style="text-align:left;"> ${ subscription.catalog.name } - ${ subscription.catalog.vendor.name } </div>', 'Souscription' ) );
		
		form.addElement(new sugoi.form.elements.StringInput("name", "Libellé", "Paiement", false));
		var amount:Float = null;
		if(subscription.getBalance()<0) amount = Math.abs(subscription.getBalance());
		form.addElement(new sugoi.form.elements.FloatInput("amount", t._("Amount"), amount, true));
		form.addElement(new form.CamapDatePicker("date", t._("Date"), Date.now(), sugoi.form.elements.NativeDatePicker.NativeDatePickerType.date, true));
		var paymentTypes = service.PaymentService.getPaymentTypes(PCManualEntry, group);
		var out = [];
		var selected = null;
		for (paymentType in paymentTypes){
			out.push({label: paymentType.name, value: paymentType.type});
			if(paymentType.type==Check.TYPE) selected=Check.TYPE;
		}
		form.addElement(new sugoi.form.elements.StringSelect("Mtype", t._("Payment type"), out, selected, true));
		
		if (form.isValid()){

			var operation = new db.Operation();
			form.toSpod(operation);
			operation.type = db.Operation.OperationType.Payment;			
			operation.setPaymentData({type:form.getValueOf("Mtype")});
			operation.group = group;
			operation.user = subscription.user;
			operation.subscription = subscription;
			operation.pending = false;
			operation.insert();
			service.PaymentService.updateUserBalance( subscription.user, group );
			throw Ok( returnUrl, t._("Payment recorded") );
		}
		
		view.title = t._("Record a payment for ::user::",{user:subscription.user.getCoupleName()}) ;
		view.form = form;
	}

	@tpl("contractadmin/masspayments.mtt")
	function doMassPayments(catalog:db.Catalog){

		if ( !app.user.canManageContract( catalog ) ) throw Error( '/', t._('Access forbidden') );
		var catalogSubscriptions = SubscriptionService.getCatalogSubscriptions(catalog);

		view.catalog = catalog;
		view.c = catalog;
		view.subscriptions = catalogSubscriptions;
		catalogSubscriptions.sort(function(a,b){
			if( a.user.lastName.toUpperCase() > b.user.lastName.toUpperCase() ){
				return 1;
			}else{
				return -1;
			}
		});
		
		var paymentTypes = service.PaymentService.getPaymentTypes(PCManualEntry, catalog.group);
		var out = [];
		var selected = null;
		for (paymentType in paymentTypes){
			out.push({label: paymentType.name, value: paymentType.type});
			if(paymentType.type==Check.TYPE) selected=Check.TYPE;
		}
		view.paymentTypes = out;
		view.selected = selected;
		view.dateToString = Formatting.shortDate;
		view.subscriptionService = SubscriptionService;
		view.nav.push( 'subscriptions' );

		if(checkToken()){
			var params = Web.getParams();
			for( sub in catalogSubscriptions.copy() ){
				var amount = 0.0;
				if(params.get('sub${sub.id}_amount')==null || params.get('sub${sub.id}_amount')==""){
					amount = null;
				}else{
					amount = params.get('sub${sub.id}_amount').parseFloat();
				}				
				if(amount!=null){
					
					var paymentType = params.get('sub${sub.id}_paymentType');
					var label = params.get('sub${sub.id}_label');

					var op = PaymentService.makePaymentOperation(sub.user,catalog.group,paymentType,amount,label);
					op.subscription = sub;
					op.pending = false;
					op.update();

				}else{
					catalogSubscriptions.remove(sub);
				}
			}

			throw Ok(sugoi.Web.getURI(),catalogSubscriptions.length+" paiements saisis, les soldes ont été mis à jour.");
		}
	}
}