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
			throw Ok( returnUrl, t._("Operation deleted") );
			
		}
	}

}