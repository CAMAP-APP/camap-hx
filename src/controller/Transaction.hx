package controller;
import Common;
import db.Basket;
import db.Operation.OperationType;
import service.OrderService;
import sugoi.form.elements.NativeDatePicker.NativeDatePickerType;
using Lambda;


/**
 * Transaction controller
 * @author fbarbut
 */
class Transaction extends controller.Controller
{

	/**
	 * insert manually a payment
	 */
	@tpl('form.mtt')
	public function doInsertPayment( user : db.User ) {
		if(app.user==null){
			throw Redirect("/");
		}
		if (!app.user.isContractManager()) throw Error("/", t._("Action forbidden"));	
		var t = sugoi.i18n.Locale.texts;

		var group = app.user.getGroup();
		var returnUrl = '/member/payments/' + user.id;
	
		var form = new sugoi.form.Form("payement");

		form.addElement(new sugoi.form.elements.StringInput("name", t._("Label||label or name for a payment"), "Paiement", false));
		form.addElement(new sugoi.form.elements.FloatInput("amount", t._("Amount"), null, true));
		form.addElement(new form.CamapDatePicker("date", t._("Date"), Date.now(), NativeDatePickerType.date, true));
		var paymentTypes = service.PaymentService.getPaymentTypes(PCManualEntry, group);
		var out = [];
		for (paymentType in paymentTypes){
			out.push({label: paymentType.name, value: paymentType.type});
		}
		form.addElement(new sugoi.form.elements.StringSelect("Mtype", t._("Payment type"), out, null, true));
		
		//related operation
		var unpaid = db.Operation.manager.search($user == user && $group == group && $type != Payment ,{limit:20,orderBy:-date});
		var data = unpaid.map(function(x) return {label:x.name, value:x.id}).array();
		form.addElement(new sugoi.form.elements.IntSelect("unpaid", "Paiment rattaché à", data, null, false));
	
		if (form.isValid()){

			var operation = new db.Operation();
			operation.user = user;
			operation.date = Date.now();

			form.toSpod(operation);

			operation.type = db.Operation.OperationType.Payment;			
			operation.setPaymentData({type:form.getValueOf("Mtype")});
			operation.group = group;
			operation.user = user;
			
			if (form.getValueOf("unpaid") != null){
				var t2 = db.Operation.manager.get(form.getValueOf("unpaid"));
				operation.relation = t2;
				if (t2.amount + operation.amount == 0) {
					operation.pending = false;
					t2.lock();
					t2.pending = false;
					t2.update();
				}
			}
			
			operation.insert();
			service.PaymentService.updateUserBalance( user, group );

			throw Ok( returnUrl, "Paiment enregistré");

		}
		
		view.title = t._("Record a payment for ::user::",{user:user.getCoupleName()}) ;
		view.form = form;
	}

	@tpl('form.mtt')
	public function doEdit( operation : db.Operation ) {
		if(app.user==null){
			throw Redirect("/");
		}
		
		var returnUrl = '/contractAdmin/subscriptions/payments/' + operation.subscription.id;
		App.current.session.data.returnUrl = returnUrl;
		
		if ( !app.user.canAccessMembership() || operation.group.id != app.user.getGroup().id ) {
			throw Error( returnUrl, t._("Action forbidden") );
		}

		if( operation.subscription == null ) {
			throw Error( '/', 'Cette opération n\'est rattachée à aucune souscription' );
		}
		
		App.current.event( PreOperationEdit( operation ) );
		
		operation.lock();
		
		var form = new sugoi.form.Form("payement");
		form.addElement(new sugoi.form.elements.StringInput("name", t._("Label||label or name for a payment"), operation.name, true));
		form.addElement(new sugoi.form.elements.FloatInput("amount", t._("Amount"), operation.amount, true));
		form.addElement(new form.CamapDatePicker("date", t._("Date"), operation.date, NativeDatePickerType.date, true));

		
		if ( form.isValid() ) {

			form.toSpod( operation );
			operation.pending = false;
			operation.update();
			service.PaymentService.updateUserBalance( operation.user, operation.group );
			throw Ok( returnUrl, t._("Operation updated"));			
		}
		
		view.form = form;
	}
	
	/**
	 * Delete an operation
	 */
	public function doDelete( operation : db.Operation ) {
		if(app.user==null){
			throw Redirect("/");
		}
		var returnUrl = '/contractAdmin/subscriptions/payments/' + operation.subscription.id;
        App.current.session.data.returnUrl = returnUrl;

		if ( !app.user.canAccessMembership() || operation.group.id != app.user.getGroup().id ) throw Error("/member/payments/" + operation.user.id, t._("Action forbidden"));	
		
		App.current.event( PreOperationDelete( operation ) );

		//only an admin can delete an order op
		if( ( operation.type == db.Operation.OperationType.VOrder || operation.type == db.Operation.OperationType.SubscriptionTotal ) && !app.user.isAdmin() ) {
			throw Error( returnUrl, t._("Action forbidden"));
		}

		if ( checkToken() ) {

			operation.delete();
			service.PaymentService.updateUserBalance( operation.user, operation.group );
			throw Ok( returnUrl, "Operation supprimée" );
			
		}
	}

}