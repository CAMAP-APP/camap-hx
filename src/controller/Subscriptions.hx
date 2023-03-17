package controller;

import sugoi.form.Form;
import sugoi.form.elements.Html;
import service.PaymentService;
import sugoi.Web;
import payment.Check;
import sugoi.db.Cache;
import db.Catalog;
import db.Operation.OperationType;
import service.SubscriptionService;

/**
 * Member subscription controller
 */
class Subscriptions extends controller.Controller
{

    /**
	 * Create or update my CSA subscription 
	 */
	 @tpl("contract/order.mtt")
     function doContract( catalog : db.Catalog ) {
         view.catalog = catalog;
         view.userId = app.user.id;
 
         var sub = SubscriptionService.getCurrentOrComingSubscription(app.user,catalog);
         view.subscriptionId = sub==null ? null : sub.id;
     }

    /**
		the user deletes his subscription
	**/
	function doDelete(subscription:db.Subscription){
		if( subscription.user.id!=app.user.id ) throw Error( '/', t._('Access forbidden') );
		var url = '/subscriptions/contract/${subscription.catalog.id}';
		try {
			SubscriptionService.deleteSubscription( subscription );
		} catch( error : tink.core.Error ) {
			throw Error( url , error.message );
		}
		throw Ok( url , 'La souscription a bien été supprimée.' );		
	}


	@admin
	@tpl('form.mtt')
	function doReattribute(sub:db.Subscription){

		if(sub.user.email!="deleted@camap.tld" && !App.config.DEBUG){
			throw "cette fonction marche uniquement pour l'utilisateur effacé";
		}

		var form = new sugoi.form.Form("reattribute");
		form.addElement( new sugoi.form.elements.IntSelect("user", "Membre" , sub.catalog.group.getMembersFormElementData(), null, true) );	

		if(form.isValid()){

			//update sub
			sub.lock();
			sub.user = db.User.manager.get(form.getValueOf("user"));
			sub.update();

			//update orders
			var orders = db.UserOrder.manager.search($subscription==sub,true);
			for(o in orders){
				o.user = sub.user;
				o.update();

				//update basket
				if(o.basket.user.id != sub.user.id){
					o.basket.lock();
					o.basket.user = sub.user;
					o.basket.update();
				}
			}

			//update ops
			for ( op in SubscriptionService.getOperations(sub,true)){
				op.user = sub.user;
				op.update();
			}

			throw Ok("/contractAdmin/subscriptions/edit/"+sub.id,"souscription réattribuée");
		}

		view.form = form;
		view.title = "Réattribuer une souscription";
	}

}