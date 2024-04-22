package controller;
import Common;
import datetime.DateTime;
import db.Basket.BasketStatus;
import db.Catalog;
import db.UserOrder;
import form.CamapDatePicker;
import form.CamapDatePicker;
import service.CatalogService;
import service.OrderService;
import service.ProductService;
import service.SubscriptionService;
import sugoi.form.Form;
import sugoi.form.elements.Checkbox;
import sugoi.form.elements.IntInput;
import sugoi.form.elements.NativeDatePicker.NativeDatePickerType;
import sugoi.form.elements.RadioGroup;
import sugoi.form.elements.Selectbox;
import sugoi.form.elements.StringInput;
import tink.core.Error;

using tools.DateTool;
using tools.ObjectListTool;


class ContractAdmin extends Controller
{

	public function new() 
	{
		super();
		if (!app.user.isContractManager()) throw Error("/", t._("You don't have the authorization to manage contracts"));
		view.nav = ["contractadmin"];
		

	}
	
	public function sendNav(c){
		var navbar = new Array<Link>();
		var e = Nav(navbar,"contractAdmin",c.id);
		app.event(e);
		view.navbar = e.getParameters()[0];
	}
	
	/**
	 * Contract admin main page
	 */
	@tpl("contractadmin/default.mtt")
	function doDefault(?args:{old:Bool}) {
		
		view.nav.push("default");

		var now = Date.now();
		
		var contracts;
		if (args != null && args.old) {
			contracts = db.Catalog.manager.search($group == app.user.getGroup() && $endDate < Date.now() ,{orderBy:-startDate},false);	
		}else {
			contracts = db.Catalog.getActiveContracts(app.user.getGroup(), true, false);	
		}

		//filter if current user is not manager
		if (!app.user.isAmapManager()) {
			for ( c in Lambda.array(contracts).copy()) {				
				if(!app.user.canManageContract(c)) contracts.remove(c);				
			}
		}
		
		view.contracts = contracts;
		var vendors = app.user.getGroup().getActiveVendors();
		view.vendors = vendors;
		view.places = app.user.getGroup().getPlaces();
		view.group = app.user.getGroup();
		
		var contractsToFix = contracts.filter(c -> c.hasPercentageOnOrders());

		if(contractsToFix.length>0){
			app.session.addMessage('Attention, la gestion des "frais au pourcentage de la commande" va disparaître le 1er Février 2023.<br/>Les catalogues suivants l\'utilisent : <b>${contractsToFix.map(c->c.name).join(", ")}</b><br/><a href="https://wiki.cagette.net/basculecommissioncatalogue" target="_blank">Cliquez ici pour connaître un alternative.</a>',true);
		}
		

		checkToken();
	}

	/**
	 * Edit a contract/catalog
	 */
	 @logged @tpl("form.mtt")
	 function doEdit( catalog : db.Catalog ) {
		 
		view.category = 'contractadmin';
		if (!app.user.isContractManager( catalog )) throw Error('/', t._("Forbidden action"));

		view.title = 'Modifier le catalogue "${catalog.name}"';

		var group = catalog.group;
		var currentContact = catalog.contact;
		var previousOrderStartDays = catalog.orderStartDaysBeforeDistrib;
		var previousOrderEndHours = catalog.orderEndHoursBeforeDistrib;
		var messages = new Array<String>() ;

		var form = CatalogService.getForm(catalog);
		
		app.event( EditContract( catalog, form ) );
		
		if ( form.checkToken() ) {

			form.toSpod( catalog );
		
			try {

				CatalogService.checkFormData(catalog,  form );
				catalog.update();

				//Update future distribs start and end orders dates
				var newOrderStartDays = catalog.orderStartDaysBeforeDistrib != previousOrderStartDays ? catalog.orderStartDaysBeforeDistrib : null;
				var newOrderEndHours = catalog.orderEndHoursBeforeDistrib != previousOrderEndHours ? catalog.orderEndHoursBeforeDistrib : null;
				var msg = CatalogService.updateFutureDistribsStartEndOrdersDates( catalog, newOrderStartDays, newOrderEndHours );
				if(msg!=null) messages.push(msg);  
				
				//update rights
				if ( catalog.contact != null && (currentContact==null || catalog.contact.id!=currentContact.id) ) {
					var ua = db.UserGroup.get( catalog.contact, catalog.group, true );
					ua.giveRight(ContractAdmin(catalog.id));
					ua.giveRight(Messages);
					ua.giveRight(Membership);
					ua.update();
					
					//remove rights to old contact
					if (currentContact != null) {
						var x = db.UserGroup.get(currentContact, catalog.group, true);
						if (x != null) {
							x.removeRight(ContractAdmin(catalog.id));
							x.update();
						}
					}
				}

			} catch ( e : Error ) {
				throw Error( '/contractAdmin/edit/' + catalog.id, e.message );
			}
			
			
			var text = "Catalogue mis à jour.";
			if(messages.length > 0){
				text += "<br/>" + messages.join(". ");
			} 
			throw Ok( "/contractAdmin/view/" + catalog.id,  text );
		}
		 
		view.form = form;
	}

	/**
	 * Manage products
	 */
	@tpl("contractadmin/products.mtt")
	function doProducts(contract:db.Catalog,?args:{?enable:String,?disable:String}) {
		view.nav.push("products");
		sendNav(contract);
		if (!app.user.canManageContract(contract)) throw Error("/", t._("Access forbidden") );
		if (contract.hasStockManagement()) {
			var now = Date.now();
			var nextDistribs = db.Distribution.manager.search( ($date >= now && $catalogId==contract.id),{orderBy: date}).array();
			
			if (nextDistribs[0] != null){
				view.stockDate = DateTools.format(nextDistribs[0].date,"%d/%m/%Y");
				// debug
				// var msg = "Distri calcul stock: " +DateTools.format(nextDistribs[0].date,"%d/%m/%Y");
				// App.current.session.addMessage(msg, true);
				// end debug
				for (product in contract.getProducts(false)){
					var actualOrders = db.UserOrder.manager.search($productId==product.id && $distributionId==nextDistribs[0].id, true);
					var totOrdersQt : Float = 0;
					for (actualOrder in actualOrders) {
						totOrdersQt += actualOrder.quantity;
					}
					// Stock dispo = stock - commandes en cours
					if (product.stock != null)  {
						var availableStock = product.stock - totOrdersQt;
						product.stock = availableStock;
					}
				}
			}
		}
		view.c = contract;
		// batch enable / disable products
		if (args != null){
			
			if (args.disable != null){
				var pids = Lambda.array(Lambda.map(args.disable.split("|"), function(x) return Std.parseInt(x)));				
				service.ProductService.batchDisableProducts(pids);
			}
			
			if (args.enable != null){
				var pids = Lambda.array(Lambda.map(args.enable.split("|"), function(x) return Std.parseInt(x)));
				service.ProductService.batchEnableProducts(pids);
			}
			
		}
		
		//generate a token
		checkToken();
	}
		
	
	/**
	 *  - hidden page -
	 * copy products from a contract to an other
	 */
	@admin @tpl("form.mtt")
	function doCopyProducts(contract:db.Catalog) {
		view.title = t._("Copy products in: ")+contract.name;
		var form = new Form("copy");
		var contracts = app.user.getGroup().getActiveContracts();
		var contracts  = Lambda.map(contracts, function(c) return {key:Std.string(c.id),value:Std.string(c.name) } );
		form.addElement(new sugoi.form.elements.Selectbox("source", t._("Copy products from: "),Lambda.array(contracts)));
		form.addElement(new sugoi.form.elements.Checkbox("delete", t._("Delete existing products (all orders will be deleted!)")));
		if (form.checkToken()) {
			
			if (form.getValueOf("delete") == "1") {
				for ( p in contract.getProducts()) {
					p.lock();
					p.delete();
				}
			}
			
			var source = db.Catalog.manager.get(Std.parseInt(form.getValueOf("source")), false);
			var prods = source.getProducts();
			for ( source_p in prods) {
				var p = new db.Product();
				p.name = source_p.name;
				p.price = source_p.price;
				p.catalog = contract;
				p.insert();
			}
			
			throw Ok("/contractAdmin/products/" + contract.id, t._("Products copied from ") + source.name);
			
			
		}
		
		
		view.form = form;
	}
	
	/**
	 * global view on orders within a timeframe
	 */
	@tpl('contractadmin/ordersByTimeFrame.mtt')
	function doOrdersByTimeFrame(?from:Date, ?to:Date/*, ?place:db.Place*/){

		 /* if(!app.user.canManageAllContracts())  throw Error('/',"Accès interdit"); */
		
		if (from == null) {
			var contracts = app.user.getGroup().getActiveContracts(true);
			var itsok = "no";
			if(!app.user.canManageAllContracts()) {
				if (!app.user.isAmapManager()) {
					for ( c in Lambda.array(contracts).copy()) {				
						if(app.user.canManageContract(c)) itsok = "yes";				
					}
				}
			} 
		else { 
			itsok = "yes";
		}
			if( itsok == "no" )  throw Error('/',"Accès interdit");
			var f = new sugoi.form.Form("listBydate", null, sugoi.form.Form.FormMethod.GET);
			
			var now = DateTime.now();	
			var from = now.snap(Month(Down)).getDate();			
			var to = now.snap(Month(Up)).add(Day(-1)).getDate();
			
			var el = new form.CamapDatePicker("from", t._("Start date"), from, NativeDatePickerType.date, true);			
			el.format = 'LL';
			f.addElement(el);
			
			var el = new form.CamapDatePicker("to", t._("End date"), to, NativeDatePickerType.date, true);
			el.format = 'LL';
			f.addElement(el);
			
			//var places = Lambda.map(app.user.getGroup().getPlaces(), function(p) return {label:p.name,value:p.id} );
			//f.addElement(new sugoi.form.elements.IntSelect("placeId", "Lieu", Lambda.array(places),app.user.getGroup().getMainPlace().id,true));
			
			view.form = f;
			view.title = t._("Global view of orders");
			app.setTemplate("form.mtt");
			
			if (f.checkToken()) {
				
				var url = '/contractAdmin/ordersByTimeFrame/' + f.getValueOf("from").toString().substr(0, 10) +"/"+f.getValueOf("to").toString().substr(0, 10);
				//var p = f.getValueOf("placeId");
				//if (p != null) url += "/"+p;
				throw Redirect( url );
			}
			
			return;
			
		}else {
			var d1 = tools.DateTool.setHourMinute(from,0,0);
			var d2 = tools.DateTool.setHourMinute(to,23,59);
			var contracts = app.user.getGroup().getActiveContracts(true);
			if(!app.user.canManageAllContracts()) {
				if (!app.user.isAmapManager()) {
					for ( c in Lambda.array(contracts).copy()) {				
						if(!app.user.canManageContract(c)) contracts.remove(c);				
					}
				}
			}
			var cids = contracts.getIds();
			
			//distribs
			var distribs = db.Distribution.manager.search(($catalogId in cids)   && $date >= d1 && $date <= d2 /*&& place.id==$placeId*/, false);					
			
			if (distribs.length == 0) throw Error("/contractAdmin/ordersByTimeFrame", t._("There is no delivery at this date"));
			

			var orders = db.UserOrder.manager.search($distributionId in distribs.getIds()  , { orderBy:userId } );
			var orders = service.OrderService.prepare(orders);
			
			view.orders = orders;
			view.from = from;
			view.to = to;
			view.ctotal = app.params.exists("ctotal");
			
		}
		
		
		
	}
	
	/**
	 * Global view on orders in one day
	 * 
	 * @param	date
	 */
	@tpl('contractadmin/ordersByDate.mtt')
	function doOrdersByDate(?date:Date,?place:db.Place){

		if(!app.user.canManageAllContracts())  throw Error('/',"Accès interdit");

		if (date == null) {
	/*		var contracts = app.user.getGroup().getActiveContracts(true);
			var itsok = "no";
			if(!app.user.canManageAllContracts()) {
				if (!app.user.isAmapManager()) {
					for ( c in Lambda.array(contracts).copy()) {				
						if(app.user.canManageContract(c)) itsok = "yes";				
					}
				}
			}
			if( itsok == "no" )  throw Error('/',"Accès interdit");
	*/
			var f = new sugoi.form.Form("listBydate", null, sugoi.form.Form.FormMethod.GET);
			var el = new form.CamapDatePicker("date", t._("Delivery date"),  NativeDatePickerType.date, true);
			el.format = 'LL';
			f.addElement(el);
			
			var places = Lambda.map(app.user.getGroup().getPlaces(), function(p) return {label:p.name,value:p.id} );
			f.addElement(new sugoi.form.elements.IntSelect("placeId", "Lieu", Lambda.array(places),app.user.getGroup().getMainPlace().id,true));
			
			view.form = f;
			view.title = t._("Global view of orders");
			view.text = t._("This page allows you to have a global view on orders of all catalogs");
			view.text += t._("<br/>Select a delivery date:");
			app.setTemplate("form.mtt");
			
			if (f.checkToken()) {
				
				var url = '/contractAdmin/ordersByDate/' + f.getValueOf("date").toString().substr(0, 10);
				var p = f.getValueOf("placeId");
				if (p != null) url += "/"+p;
				throw Redirect( url );
			}
			
			return;
			
		}else {
			
			var d1 = date.setHourMinute(0, 0);
			var d2 = date.setHourMinute(23,59);
			var contracts = app.user.getGroup().getActiveContracts(true);
	/*		if(!app.user.canManageAllContracts()) {
				if (!app.user.isAmapManager()) {
					for ( c in Lambda.array(contracts).copy()) {				
						if(!app.user.canManageContract(c)) contracts.remove(c);				
					}
				}
			}
	*/
			var cids = contracts.map(x->return x.id);
			
			//distribs
			var distribs = db.Distribution.manager.search(($catalogId in cids) && $date >= d1 && $date <= d2 && place.id==$placeId, false);		
			
			if (distribs.length == 0) throw Error("/contractAdmin/ordersByDate", t._("There is no delivery at this date"));
			
			//orders
			var orders = db.UserOrder.manager.search($distributionId in distribs.getIds()  , { orderBy:userId } );			
			var orders = service.OrderService.prepare(orders);
			
			view.orders = orders;
			view.date = date;
			view.place = place;
			view.ctotal = app.params.exists("ctotal");

			view.distrib = db.MultiDistrib.get(date,place);
		}
	}
	
	
	/**
	 * Global view on orders, producer view
	 */
	/*@tpl('contractadmin/vendorsByDate.mtt')
	function doVendorsByDate(date:Date,place:db.Place) {

	    var vendorDataByVendorId = new Map<Int,Dynamic>();//key : vendor id
		try {
			vendorDataByVendorId = service.ReportService.getMultiDistribVendorOrdersByProduct(date, place);
		} catch(e:tink.core.Error) {
			throw Error("/contractAdmin/ordersByDate", e.message);
		}
		
		view.orders = Lambda.array(vendorDataByVendorId);
		view.date = date;
	}*/
	
	/**
	 * Global view on orders, producer view
	 */
	@tpl('contractadmin/vendorsByTimeFrame.mtt')
	function doVendorsByTimeFrame(from:Date,to:Date){
			
		var d1 = tools.DateTool.setHourMinute(from,0,0);
		var d2 = tools.DateTool.setHourMinute(to,23,59);
		var contracts = app.user.getGroup().getActiveContracts(true);
		/*
		 * Permettre à un gestionnaire de catalogue d'imprimmer sa récap
		 */
		if (!app.user.isAmapManager()) {
			for ( c in Lambda.array(contracts).copy()) {				
				if(!app.user.canManageContract(c)) contracts.remove(c);				
			}
		}
		
		var cids = contracts.getIds();

		
		//distribs for both types in active contracts
		var distribs = db.Distribution.manager.search(($catalogId in cids) && $date >= d1 && $date <= d2 /*&& $place==place*/, false);		
		if ( distribs.length == 0 ) throw Error("/contractAdmin/", t._("There is no delivery during this period"));
		
		var out = new Map<Int,{contract:db.Catalog,distrib:db.Distribution,orders:Array<OrderByProduct>}>();//key : vendor id
		
		for (d in distribs){
			var vid = d.catalog.vendor.id;
			var o = out.get(vid);
			
			if (o == null){
				out.set( vid, {contract:d.catalog,distrib:d,orders:service.ReportService.getOrdersByProduct(d) });	
			}else{
				
				//add orders with existing ones
				for ( x in service.ReportService.getOrdersByProduct(d) ){
					
					//find record in existing orders
					var f : OrderByProduct = Lambda.find(o.orders, function(a:OrderByProduct) return a.pid == x.pid);
					if (f == null){
						//new product order
						o.orders.push(x);						
					}else{
						//increment existing
						f.quantity += x.quantity;
						f.totalHT += x.totalHT;
						f.totalTTC += x.totalTTC;
					}
				}
				out.set(vid, o);
			}
		}
		
		view.orders = Lambda.array(out);
		
		if ( app.params.exists("csv") ){
			var totalHT = 0.0;
			var totalTTC = 0.0;
			
			var orders = [];
			for ( x in out){
				//empty line
				orders.push({"quantity":null, 					"pname":null, "ref":null, "priceHT":null, "priceTTC":null, "totalHT":null, "totalTTC":null});				
				orders.push({"quantity":null, "pname":x.contract.vendor.name, "ref":null, "priceHT":null, "priceTTC":null, "totalHT":null, "totalTTC":null});				
				
				for (o in x.orders){
					if(o.vat==null) o.vat = 0;
					orders.push({
						"quantity":view.formatNum(o.quantity),
						"pname":o.pname,
						"ref":o.ref,
						"priceHT":view.formatNum(o.priceTTC / (1 + o.vat / 100) ),
						"priceTTC":view.formatNum(o.priceTTC),
						"totalHT":view.formatNum(o.totalHT),					
						"totalTTC":view.formatNum(o.totalTTC)					
					});
					totalTTC += o.totalTTC;
					totalHT += o.totalHT;
				}
				
				//total line
				orders.push({
					"quantity":null,
					"pname":null,
					"ref":null,
					"priceHT":null,
					"priceTTC":null,
					"totalHT":view.formatNum(totalHT) + "",
					"totalTTC":view.formatNum(totalTTC)+""					
				});								
				totalTTC = 0;
				totalHT = 0;
				
			}			
			var fileName = t._("Orders from the ::fromDate:: to the ::toDate:: per supplier.csv", {fromDate:from.toString().substr(0, 10), toDate:to.toString().substr(0, 10)});
			sugoi.tools.Csv.printCsvDataFromObjects(orders, ["quantity", "pname", "ref", "priceHT", "priceTTC", "totalHT","totalTTC"], fileName);
			return;
		}
		
		view.from = from;
		view.to = to;
	}
	
	
	/**
	 * Overview of orders for this contract in backoffice
	 */
	@tpl("contractadmin/orders.mtt")
	function doOrders( catalog:db.Catalog, ?args:{ d:db.Distribution, ?delete:db.UserOrder } ) {

		view.nav.push( "orders" );
		sendNav( catalog );
		
		//Checking permissions
		if ( !app.user.canManageContract( catalog ) ) throw Error( "/", t._("You do not have the authorization to manage this contract") );
		if ( args == null || args.d == null ) throw Redirect( "/contractAdmin/selectDistrib/" + catalog.id );

		//Delete specified order with quantity of zero
		if ( checkToken() && args != null && args.delete != null ) {

			try {
				service.OrderService.delete(args.delete);
			}	catch( e : tink.core.Error ) {
				throw Error( "/contractAdmin/orders/" + catalog.id, e.message );
			}
			if( args.d != null ) {
				throw Ok("/contractAdmin/orders/" + catalog.id + "?d="+args.d.id, t._("The order has been deleted."));
			} else {
				throw Ok("/contractAdmin/orders/" + catalog.id, t._("The order has been deleted."));
			}
			
		}
		
		view.distribution = args.d;
		view.multiDistribId = args.d.multiDistrib.id;
		view.c = view.catalog = catalog;		

		if ( App.current.params.get("csv")=="1" ) {

			var data = [];			
			for( basket in args.d.multiDistrib.getBaskets()){
				for(o in service.OrderService.prepare(basket.getDistributionOrders(args.d))){
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
			}
			
			var exportName = catalog.group.name + " - " + t._("Delivery ::contractName:: ", {contractName:catalog.name}) + args.d.date.toString().substr(0, 10);								
			sugoi.tools.Csv.printCsvDataFromObjects(data, ["name",  "productName", "price", "quantity", "fees", "total", "paid"], exportName+" - " + t._("Per member"));			
		}
	}
	
	/**
	 * hidden feature : updates orders by setting current product price.
	 */
	function doUpdatePrices(contract:db.Catalog, args:{?d:db.Distribution}) {
		
		sendNav(contract);
		
		if (!app.user.canManageContract(contract)) throw Error("/", t._("You do not have the authorization to manage this contract"));
		if (contract.type == db.Catalog.TYPE_VARORDER && args.d == null ) { 
			throw Redirect("/contractAdmin/selectDistrib/" + contract.id); 
		}
		var d = null;
		if (contract.type == db.Catalog.TYPE_VARORDER ){
			view.distribution = args.d;
			d = args.d;
		}
		
		for ( o in contract.getOrders(d)){
			o.lock();
			o.productPrice = o.product.price;
			if (contract.hasPercentageOnOrders()){
				o.feesRate = contract.percentageValue;
			}
			o.update();
			
		}
		throw Ok("/contractAdmin/orders/"+contract.id+"?d="+args.d.id, t._("Prices are now up to date."));
	}
	
	/**
	 *  Duplicate a catalog
	 */
	@tpl("form.mtt")
	function doDuplicate(catalog:db.Catalog) {

		sendNav(catalog);
		if (!app.user.canManageContract(catalog)) throw Error("/", t._("You do not have the authorization to manage this catalog"));
		
		view.title = "Dupliquer le contrat '"+catalog.name+"'";
		var form = new Form("duplicate");
		
		form.addElement(new StringInput("name", t._("Name of the new catalog"), catalog.name.substr(0,50)  + " - copie"));	
		var catalogTypes = [ { label : 'Contrat AMAP classique', value : 0 }, { label : 'Contrat AMAP variable', value : 1 } ];
		form.addElement( new sugoi.form.elements.IntSelect( 'catalogtype', 'Type de catalogue', catalogTypes, catalog.type, true ) );
		form.addElement(new sugoi.form.elements.RadioGroup('copyProducts', t._("Copy products"), [
			{value: "none", label: t._("None")},
			{value: "all", label: t._("All Products")},
			{value: "onlyActiveProducts", label: t._("Only active products")},
			], "all"));

		/* Pour superadmin et admin groupe seulement, décoché par défaut v1.0.5 */
		if (app.user.isAdmin() || app.user.isGroupManager()){
			
			form.addElement(new Checkbox("copyDeliveries", t._("Copy deliveries"),false));
		}
		
		
		/* Création des roles de volontaires pour la copie v1.0.5 */
		
		if (form.checkToken()) {

			var nc = new db.Catalog();
			nc.name = form.getValueOf("name");
			nc.startDate = catalog.startDate;
			nc.endDate = catalog.endDate;
			nc.group = catalog.group;
			nc.contact = catalog.contact;
			nc.description = catalog.description;
			nc.distributorNum = catalog.distributorNum;
			nc.flags = catalog.flags;
			nc.type = form.getValueOf("catalogtype");

			nc.orderEndHoursBeforeDistrib = catalog.orderEndHoursBeforeDistrib;
			nc.absentDistribsMaxNb = catalog.absentDistribsMaxNb;
			// nc.absencesStartDate = catalog.absencesStartDate;
			// nc.absencesEndDate = catalog.absencesEndDate;

			if ( nc.type == Catalog.TYPE_VARORDER ) {

				nc.orderStartDaysBeforeDistrib = catalog.type == Catalog.TYPE_VARORDER ? catalog.orderStartDaysBeforeDistrib : 365;
				// nc.requiresOrdering = catalog.requiresOrdering;
				nc.distribMinOrdersTotal = catalog.distribMinOrdersTotal;
				nc.catalogMinOrdersTotal = catalog.catalogMinOrdersTotal;
				// nc.allowedOverspend = catalog.type == Catalog.TYPE_VARORDER ? catalog.allowedOverspend : defaultAllowedOverspend;
			}
			nc.vendor = catalog.vendor;
			nc.percentageName = catalog.percentageName;
			nc.percentageValue = catalog.percentageValue;
			nc.insert();
			
			//give rights to this contract
			if(catalog.contact!=null){
				if (catalog.contact.isMemberOf(catalog.group)){
					var ua = db.UserGroup.get(catalog.contact, catalog.group);				
					ua.giveRight(ContractAdmin(nc.id));
				} else {
					var ua = db.UserGroup.get(app.user, catalog.group);
					ua.giveRight(ContractAdmin(nc.id));
					nc.contact = app.user;
					nc.update();
				}
			}

			if(catalog.contact==null || app.user.id!=catalog.contact.id){
				var ua = db.UserGroup.get(app.user, catalog.group);
				ua.giveRight(ContractAdmin(nc.id));
			}
			
			var copyProducts = form.getValueOf("copyProducts");
			switch (copyProducts) {
				case "all":
					var prods = catalog.getProducts(false);
					for ( source_p in prods) {
						var p = ProductService.duplicate(source_p);
						p.catalog = nc;
						p.update();
					}
				case "onlyActiveProducts":
					var prods = catalog.getProducts(true);
					for ( source_p in prods) {
						var p = ProductService.duplicate(source_p);
						p.catalog = nc;
						p.update();
					}
			}

					
			if (app.user.isAdmin() || app.user.isGroupManager()){
				if (form.getValueOf("copyDeliveries") == true) {
					for ( ds in catalog.getDistribs()) {
						var d = new db.Distribution();
						d.catalog = nc;
						d.date = ds.date;
						d.multiDistrib = ds.multiDistrib;
						d.orderStartDate = ds.orderStartDate;
						d.orderEndDate = ds.orderEndDate;
						d.end = ds.end;
						d.place = ds.place;
						d.insert();
					}
				}
			}
			
			app.event(DuplicateContract(catalog));
			
			throw Ok("/contractAdmin/view/" + nc.id, t._("The catalog has been duplicated"));
		}
		
		view.form = form;
	}
	
	
	
	/**
	 * Orders grouped by product
	 */
	@tpl("contractadmin/ordersByProduct.mtt")
	function doOrdersByProduct(contract:db.Catalog, args:{?d:db.Distribution}) {
		
		sendNav(contract);		
		if (!app.user.canManageContract(contract)) throw Error("/", t._("You do not have the authorization to manage this contract"));
		if (contract.type == db.Catalog.TYPE_VARORDER && args.d == null ) throw Redirect("/contractAdmin/selectDistrib/" + contract.id); 
		
		var d = args != null ? args.d : null;
		if (d == null) d = contract.getDistribs(false).first();
		if (d == null) throw Error("/contractAdmin/orders/"+contract.id,t._("There is no delivery in this catalog, please create at least one distribution."));

		var orders = service.ReportService.getOrdersByProduct(d,app.params.exists("csv"));
		view.orders = orders;
		view.distribution = d; 
		view.c = contract;
		
	}
	
	/**
	 * Purchase order to print
	 */
	@tpl("contractadmin/ordersByProductList.mtt")
	function doOrdersByProductList(contract:db.Catalog, args:{d:db.Distribution}) {
		
		sendNav(contract);		
		if (!app.user.canManageContract(contract)) throw Error("/", t._("Forbidden access"));
		if(args.d.catalog.id!=contract.id) throw 'Distribution does not belong to this catalog';
				
		view.distribution = args.d;
		view.c = contract;
		view.group = contract.group;
		view.orders = service.ReportService.getOrdersByProduct(args.d,false);
	}
	
	/**
	 * Lists deliveries for this contract
	 */
	@tpl("contractadmin/distributions.mtt")
	function doDistributions(contract:db.Catalog, ?args: { ?participateToAllDistributions:Bool } ) {

		view.nav.push("distributions");
		sendNav(contract);
		
		if (!app.user.canManageContract(contract)) throw Error("/", t._("You do not have the authorization to manage this contract"));

		var now = Date.now();
		//snap to beggining of the month , end is 3 month later 
		var from = new Date(now.getFullYear(),now.getMonth(),1,0,0,0);
		var to = new Date(now.getFullYear(),now.getMonth()+3,-1,23,59,59);
		var timeframe = new tools.Timeframe(from,to);

		var multidistribs =  db.MultiDistrib.getFromTimeRange(contract.group,timeframe.from , timeframe.to);

		if(args!=null && args.participateToAllDistributions){
			for( d in multidistribs){
				if( d.getDistributionForContract(contract)==null ){
					try{
						service.DistributionService.participate(d,contract);
					}catch(e:Error){
						app.session.addMessage(e.message,true);
					}
				}				
			}
			app.session.addMessage(contract.vendor.name+" participe maintenant à toutes les distributions");
		}
		
		view.multidistribs = multidistribs;
		view.c = contract;
		view.contract = contract;
		view.timeframe = timeframe;

				
	}

	function doParticipate(md:db.MultiDistrib,contract:db.Catalog){
		try{
			service.DistributionService.participate(md,contract);
		}catch(e:tink.core.Error){
			throw Error("/contractAdmin/distributions/"+contract.id,e.message);
		}
		
		throw Ok('/contractAdmin/distributions/${contract.id}?_from=${app.params.get("_from")}&_to=${app.params.get("_to")}',t._("Distribution date added"));
	}
	
	@tpl("contractadmin/view.mtt")
	function doView( catalog : db.Catalog ) {

		view.nav.push("view");
		sendNav(catalog);
		checkToken();

		catalog.check();

		if ( !app.user.canManageContract( catalog ) ) throw Error("/", t._("You do not have the authorization to manage this contract"));

		view.c = view.contract = catalog;
	}	

	function doDocuments( dispatch : haxe.web.Dispatch ) {
		dispatch.dispatch( new controller.Documents() );
	}

	function doSubscriptions( dispatch : haxe.web.Dispatch ) {
		dispatch.dispatch( new controller.SubscriptionAdmin() );
	}
	
	@tpl("contractadmin/stats.mtt")
	function doStats(contract:db.Catalog, ?args: { stat:Int } ) {
		sendNav(contract);
		if (!app.user.canManageContract(contract)) throw Error("/", t._("You do not have the authorization to manage this contract"));
		view.c = contract;
		
		if (args == null) args = { stat:0 };
		view.stat = args.stat;
		var pids = contract.getProducts().map(function(x) return x.id);
		switch(args.stat) {
			case 0 : 
				//ancienneté des amapiens
				
				if(pids.length==0){
					view.anciennete = new List();
				}else{
					view.anciennete = sys.db.Manager.cnx.request("select YEAR(u.cdate) as uyear ,count(DISTINCT u.id) as cnt from User u, UserOrder up where up.userId=u.id and up.productId IN (" + pids.join(",") + ") group by uyear;").results();
				}
				
			case 1 : 
				//repartition des commandes
				var repartition = new List();
				var total = 0;
				var totalPrice = 0;
				if(pids.length!=0){	
					var repartition = sys.db.Manager.cnx.request("select sum(quantity) as quantity,productId,p.name,p.price from UserOrder up, Product p where up.productId IN (" + contract.getProducts().map(function(x) return x.id).join(",") + ") and up.productId=p.id group by productId").results();
					for ( r in repartition) {
						total += r.quantity;
						totalPrice += r.price*r.quantity; 
					}
					for (r in repartition) {
						Reflect.setField(r, "percent", Math.round((r.quantity/total)*100)  );
					}
					
					if ( app.params.exists("csv") ){					
						sugoi.tools.Csv.printCsvDataFromObjects(Lambda.array(repartition), ["quantity","productId","name","price","percent"], "stats-" + contract.name+".csv");
					}
				}				
				
				view.repartition = repartition;
				view.totalQuantity = total;
				view.totalPrice = totalPrice;
				
		}
		
	}
	
	@tpl("contractadmin/selectDistrib.mtt")
	function doSelectDistrib(c:db.Catalog, ?args:{old:Bool}) {
		view.nav.push("orders");
		sendNav(c);
		
		view.c = c;
		if (args != null && args.old){
			view.distributions = c.getDistribs(false);	
		}else{
			view.distributions = c.getDistribs(true);
		}
		
	}

	@tpl("contractadmin/tmpBaskets.mtt")
	function doTmpBaskets(md:db.MultiDistrib){
		view.md = md;
		view.tmpBaskets = db.Basket.manager.search($multiDistrib == md && $status==Std.string(BasketStatus.OPEN),false);
	}


	/**
		the catalog admin updates absences options
	**/
	@tpl("contractadmin/form.mtt")
	function doAbsences(catalog:db.Catalog){
		view.category = 'contractadmin';
		view.nav.push("absences");
		if (!app.user.isContractManager( catalog )) throw Error('/', t._("Forbidden action"));

		view.title = 'Période d\'absences du contrat \"${catalog.name}\"';

		var form = new sugoi.form.Form("absences");
	
		var html = "<div class='alert alert-warning'><p><i class='icon icon-info'></i> 
		Vous pouvez définir une période pendant laquelle les membres pourront choisir d'être absent.<br/>
		<b>Saisissez la période d'absence uniquement après avoir défini votre planning de distribution définitif sur toute la durée du contrat.</b><br/>
		<a href='https://wiki.amap44.org/fr/app/admin-gestion-absences' target='_blank'>Consulter la documentation.</a>
		</p></div>";
		
		form.addElement( new sugoi.form.elements.Html( 'absences', html, '' ) );
		form.addElement(new IntInput("absentDistribsMaxNb","Nombre maximum d'absences autorisées",catalog.absentDistribsMaxNb,true));
		var start = catalog.absencesStartDate==null ? catalog.startDate : catalog.absencesStartDate;
		var end = catalog.absencesEndDate==null ? catalog.endDate : catalog.absencesEndDate;
		form.addElement(new CamapDatePicker("absencesStartDate","Début de la période d'absence",start));
		form.addElement(new CamapDatePicker("absencesEndDate","Fin de la période d'absence",end));
		
		if ( form.checkToken() ) {
			catalog.lock();
			form.toSpod( catalog );
			var absencesStartDate : Date = form.getValueOf('absencesStartDate');
			var absencesEndDate : Date = form.getValueOf('absencesEndDate');
			catalog.absencesStartDate = new Date( absencesStartDate.getFullYear(), absencesStartDate.getMonth(), absencesStartDate.getDate(), 0, 0, 0 );
			catalog.absencesEndDate = new Date( absencesEndDate.getFullYear(), absencesEndDate.getMonth(), absencesEndDate.getDate(), 23, 59, 59 );
			catalog.update();
		
			try{
				
				CatalogService.checkAbsences(catalog);

			} catch ( e : Error ) {
				throw Error( '/contractAdmin/absences/'+catalog.id, e.message );
			}
			
			throw Ok( "/contractAdmin/view/" + catalog.id,  "Catalogue mis à jour." );
		}
		 
		view.form = form;
		view.c = catalog;
		
	}

	/**
	 * Delete a catalog (... and its products, orders & distributions)
	 */
	@logged
	function doDelete(c:db.Catalog) {
		
		if (!app.user.canManageAllContracts()) throw Error("/contractAdmin", t._("Forbidden access"));
		
		if (checkToken()) {
			c.lock();
			
			//check if there is orders in this contract
			var pids = c.getProducts().map(p -> p.id);
			var orders = db.UserOrder.manager.search($productId in pids);
			var qt = 0.0;
			for ( o in orders) qt += o.quantity; //there could be "zero c qt" orders
			if (qt > 0) {
				throw Error("/contractAdmin", t._("You cannot delete this catalog because some orders are linked to it."));
			}
			
			//remove admin rights and delete contract	
			if(c.contact!=null){
				var ua = db.UserGroup.get(c.contact, c.group, true);
				if (ua != null) {
					ua.removeRight(ContractAdmin(c.id));
					ua.update();	
				}			
			}
			
			app.event(DeleteContract(c));
			
			c.delete();
			throw Ok("/contractAdmin", t._("Catalog deleted"));
		}
		
		throw Error("/contractAdmin", t._("Token error"));
	}

	
	
}
