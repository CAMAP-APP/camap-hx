package controller;
import db.User.UserFlags;
import Common;
import db.Catalog;
import db.MultiDistrib;
import haxe.Http;
import haxe.Utf8;
import haxe.macro.Expr.Catch;
import payment.Check;
import service.OrderService;
import service.SubscriptionService;
import sugoi.form.Form;
import sugoi.form.elements.Selectbox;
import sugoi.form.validators.EmailValidator;
import sugoi.tools.Utils;

class Member extends Controller
{

	public function new()
	{
		super();
		if (!app.user.isAdmin() && !app.user.canAccessMembership()) throw Redirect("/");
	}

	@logged
	@tpl('member/default.mtt')
	function doDefault(?args: { ?search:String, ?list:String } ) {
		var group = app.user.getGroup();
		if (group==null) {
			throw Redirect("/");
		}
		
		// Set view.token to pass it to Neolithic componant
		checkToken();
	}
	
	@tpl("member/view.mtt")
	function doView(member:db.User) {
		var group = app.user.getGroup();
		if (group==null) {
			throw Redirect("/");
		}
		view.member = member;
		var userGroup = db.UserGroup.get(member, group);
		if (userGroup == null) throw Error("/member", t._("This person does not belong to your group"));
		
		view.userGroup = userGroup; 
		view.canLoginAs = (db.UserGroup.manager.count($userId == member.id) == 1 && app.user.isAmapManager()) || app.user.isAdmin(); 
		
		var now = Date.now();
		var from = new Date(now.getFullYear(), now.getMonth(), now.getDate()-7, 0, 0, 0);
		var to = DateTools.delta(from, 1000.0 * 60 * 60 * 24 * 28 * 3);
		var timeframe = new tools.Timeframe(from,to);
		var distribs = db.MultiDistrib.getFromTimeRange(app.user.getGroup(),timeframe.from,timeframe.to);

		//variable orders
		view.distribs = distribs;
		view.getUserOrders = function(md:db.MultiDistrib){
			return OrderService.prepare(md.getUserOrders(member,db.Catalog.TYPE_VARORDER));
		}

		//const orders subscriptions
		view.subscriptionService = service.SubscriptionService;
		view.subscriptionsByCatalog = SubscriptionService.getActiveSubscriptionsByCatalog( member, app.user.getGroup() );

		//notifications
		var notifications = [];
		var trans = App.getTranslationArray();
		for ( v in UserFlags.createAll()){
			var vs = Std.string(v);
			notifications.push({
				id: v,
				name:trans.get(vs) == null ? vs : trans.get(vs),
				active:member.flags.has(v)
			});

		}
		view.notifications = notifications;

		checkToken(); //to insert a token in tpl
	
	}


	/**
	 * Admin : Log in as this user for debugging purpose
	 */	
	 @tpl('member/loginAs.mtt')
	 function doLoginas(member:db.User) {
	
		if (!app.user.isAdmin()){
			if (!app.user.isAmapManager()) return;
			if (member.isAdmin()) return;
			if ( db.UserGroup.manager.count($userId == member.id) > 1 ) return;			
		}

		view.userId = member.id;
		view.groupId = App.current.session.data.amapId;

		App.current.session.setUser(member);
		App.current.session.data.amapId = null;
	}
	
	/**
	 * Edit a Member
	 */
	@tpl('form.mtt')
	function doEdit(member:db.User) {
	
	}
	
	/**
	 * Remove a user from this group
	 */
	function doDelete(user:db.User,?args:{confirm:Bool,token:String}) {
		
		if (checkToken()) {
			if (!app.user.canAccessMembership()) throw t._("You cannot do that.");
			if (user.id == app.user.id) throw Error("/member/view/" + user.id, t._("You cannot delete yourself."));
			if ( Lambda.count(user.getOrders(app.user.getGroup()),function(x) return x.quantity>0) > 0 && !args.confirm) {
				throw Error("/member/view/"+user.id, t._("Warning, this account has orders. <a class='btn btn-default btn-xs' href='/member/delete/::userid::?token=::argstoken::&confirm=1'>Remove anyway</a>", {userid:user.id, argstoken:args.token}));
			}
		
			var ua = db.UserGroup.get(user, app.user.getGroup(), true);
			if (ua != null) {
				ua.delete();
				throw Ok("/member", t._("::user:: has been removed from your group",{user:user.getName()}));
			}else {
				throw Error("/member", t._("This person does not belong to \"::amapname::\"", {amapname:app.user.getGroup().name}));
			}	
		}else {
			throw Redirect("/member/view/"+user.id);
		}
	}
	
	/**
	 * user payments history
	 */
	@tpl('member/payments.mtt')
	function doPayments(m:db.User){

		service.PaymentService.updateUserBalance(m, app.user.getGroup());		
    	var browse:Int->Int->List<Dynamic>;
		
		//default display
		browse = function(index:Int, limit:Int) {
			return db.Operation.getOperationsWithIndex(m,app.user.getGroup(),index,limit,true);
		}
		
		var count = db.Operation.countOperations(m,app.user.getGroup());
		var rb = new sugoi.tools.ResultsBrowser(count, 10, browse);
		view.rb = rb;
		view.member = m;
		view.balance = db.UserGroup.get(m, app.user.getGroup()).balance;
		
		checkToken();
	}
	
	@tpl('member/balance.mtt')
	function doBalance(){

		if(app.params.get("refresh")=="1"){
			var group = app.user.getGroup();
			for(m in group.getMembers()){
				service.PaymentService.updateUserBalance(m, group);	
			}
		}

		view.balanced = db.UserGroup.manager.search($group == app.user.getGroup() && $balance == 0.0, false);
		view.credit = db.UserGroup.manager.search($group == app.user.getGroup() && $balance > 0, false);
		view.debt = db.UserGroup.manager.search($group == app.user.getGroup() && $balance < 0, false);
	}

	/**
		invoice for user
	**/
	@tpl('member/invoice.mtt')
	function doInvoice(m:db.User,md:db.MultiDistrib){
		
		//orders grouped by vendors
		var orders = service.OrderService.prepare(md.getUserOrders(m));
		var ordersByVendors = new Map<Int,Array<UserOrder>>();
		for( o in orders) {
			var or = ordersByVendors.get(o.product.vendorId);
			if(or==null) or = [];
			or.push(o);
			ordersByVendors.set(o.product.vendorId,or);
		}

		//grouped by VAT
		var ordersByVat = new Map<Int,{ht:Float,ttc:Float}>();
		for( o in orders){
			var key = Math.round(o.product.vat*100);
			if(ordersByVat[key]==null) ordersByVat[key] = {ht:0.0,ttc:0.0};
			var total = o.quantity * o.productPrice;
			ordersByVat[key].ttc += total;
			ordersByVat[key].ht += (total/(1+o.product.vat/100));
		}
		view.ordersByVat = ordersByVat;

		var basket = md.getUserBasket(m);
		var paymentOps = basket.getPaymentsOperations();

		view.member = m;
		view.ordersByVendors = ordersByVendors;
		view.md = md;
		view.getVendor = function(id) return db.Vendor.manager.get(id,false);
		view.paymentOps = paymentOps;
	}

	/**
	 * Move to waiting list
	 */
	 function doMovetowl(u:db.User){
		try{
			service.WaitingListService.moveBackToWl(u,app.user.getGroup(),"Remis en liste d'attente par "+app.user.getName());
		}catch(e:tink.core.Error){
			throw Error("/member/view/"+u.id, e.message );
		}
		
		throw Ok("/member", u.getName() +" a été remis(e) en liste d'attente");
	}



	
}