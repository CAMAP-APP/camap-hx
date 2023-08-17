package controller.api;
import haxe.Json;
import neko.Web;
import service.OrderService;
import service.SubscriptionService;
import tink.core.Error;

typedef NewSubscriptionDto = {
    userId:Int,
    catalogId:Int,
    defaultOrder:Array<CSAOrder>,
    absentDistribIds:Array<Int>
};

typedef UpdateOrdersDto = { 
    //id is distributionId 
    distributions:Array<{id:Int,orders:Array<{productId:Int,qty:Float}>}>,
};

class Subscription extends Controller
{

    /**
        Get or create a subscription
    **/
	public function doDefault(?sub:db.Subscription){

        // Create a new sub
        var post = sugoi.Web.getPostData();
        if(post!=null && sub==null){
            var newSubData : NewSubscriptionDto = Json.parse(StringTools.urlDecode(post));
            var user = db.User.manager.get(newSubData.userId,false);
            var catalog = db.Catalog.manager.get(newSubData.catalogId,false);

            if(!app.user.isAdmin() && !user.canManageContract(catalog) && app.user.id!=user.id){
                throw new Error(403,"You're not allowed to create a subscription for this user");
            }
			// Ajout Amaury blocage souscriptions sauvages
			if (!catalog.hasOpenOrders() && (!user.canManageContract(catalog) || !app.user.isAdmin() || !app.user.isGroupManager())){
				throw new Error("Les souscriptions à ce catalogue sont fermées. Veuillez contacter le coordinateur du contrat.");
			}

            var ss = new SubscriptionService();
            sub = ss.createSubscription(user,catalog,newSubData.defaultOrder,newSubData.absentDistribIds);
            
        }    

        getSubscription(sub);
    }

    /**
        update Orders of a subscription
    **/
	public function doUpdateOrders(sub:db.Subscription){

        // Create a new sub
        var post = sugoi.Web.getPostData();
        if(post!=null){
            var updateOrdersData : UpdateOrdersDto = Json.parse(StringTools.urlDecode(post));

            if(!app.user.isAdmin() && !app.user.canManageContract(sub.catalog) && app.user.id!=sub.user.id){
                throw new Error(403,"You're not allowed to edit a subscription for this user");
            }
			// Ajout Amaury blocage souscriptions sauvages
			if (!sub.catalog.hasOpenOrders() && (!app.user.canManageContract(sub.catalog) || !app.user.isAdmin() || !app.user.isGroupManager())){
				throw new Error("Les souscriptions à ce catalogue sont fermées. Veuillez contacter le coordinateur du contrat.");
			}

            for( d in updateOrdersData.distributions){
                for( order in d.orders){
                    var p = db.Product.manager.get(order.productId,false);
                    
                    var prevOrder = db.UserOrder.manager.select($product==p && $user==sub.user && $distributionId==d.id, true);
                    if(prevOrder==null){
                        try {
							OrderService.make( sub.user, order.qty, p , d.id , null, sub );
						} catch(e:tink.core.Error) {
							// var msg = e.message;
							// App.current.session.addMessage(msg, true);	
							throw e;
						}	
                    }else{
                        if(p.multiWeight){
                        	try{
								OrderService.editMultiWeight( prevOrder, order.qty );
						    }catch(e:tink.core.Error) {
								throw e;
							}	 
                        }else{
                            try {
								OrderService.edit( prevOrder, order.qty );
							}catch(e:tink.core.Error) {
								// var msg = e.message;
								// App.current.session.addMessage(msg, true);	
								throw e;
							}
                        }
                    }
                }
            }            
                 
			SubscriptionService.createOrUpdateTotalOperation( sub );
            SubscriptionService.areVarOrdersValid( sub );
        }    

        getSubscription(sub);
    }


	public function doUpdateDefaultOrder(sub:db.Subscription){

        // Create a new sub
        var post = sugoi.Web.getPostData();
        if(post!=null){
            var updateDefaultOrderData:Array<CSAOrder> = Json.parse(StringTools.urlDecode(post));

            if(!app.user.isAdmin() && !app.user.canManageContract(sub.catalog) && app.user.id!=sub.user.id){
                throw new Error(403,"You're not allowed to edit a subscription for this user");
            }

            var ss = new SubscriptionService();
            try {
				ss.updateDefaultOrders(sub, updateDefaultOrderData);
			}catch(e:tink.core.Error) {
				throw (e);
			}
            
        }    

        getSubscription(sub);
    }

    /**
        Check default order for constraints, before creating the subscription
    **/
    public function doCheckDefaultOrder(catalog:db.Catalog){
        var post = sugoi.Web.getPostData();
        if(post!=null){
            var defaultOrder:Array<CSAOrder> = Json.parse(StringTools.urlDecode(post));

            //no default order to check in those cases
            if(catalog.isConstantOrdersCatalog() || catalog.distribMinOrdersTotal==0){                
                return json({defaultOrderCheck:true});
            }

            //build ordersByDistrib
            var distribs = db.Distribution.manager.search( $catalog == catalog && $date >= SubscriptionService.getNewSubscriptionStartDate( catalog ) );
            var ordersByDistrib = new Map<db.Distribution,Array<CSAOrder>>();
            for( d in distribs) ordersByDistrib.set(d,defaultOrder);

            if(SubscriptionService.checkVarOrders(ordersByDistrib)){
                json({defaultOrderCheck:true});
            }
        }
    }

    private function getSubscription(sub:db.Subscription){

        var distributionsWithOrders = new Array<{id:Int,orders:Array<{id:Int,productId:Int,qty:Float}>}>();
        for( d in SubscriptionService.getSubscriptionDistributions(sub,"allIncludingAbsences")){
            distributionsWithOrders.push({
                id:d.id,
                orders:d.getUserOrders(sub.user).array().map(o -> {
                    id : o.id,
                    productId : o.product.id,
                    qty : o.quantity
                })
            });
        }

        //merge multiweight products on each distrib
        var distributionsWithOrders2 = [];
        for(d in distributionsWithOrders){
            var orders:Array<{id:Int,productId:Int,qty:Float}> = [];
            for(a in d.orders){
                if(a.qty==0) continue;
                var p = db.Product.manager.get(a.productId,false);
                if(p.multiWeight){
                    var existing = orders.find( a -> a.productId==p.id );
                    if(existing==null){
                        a.qty = 1;
                        orders.push(a);
                    }else{
                        existing.qty++;
                        existing.id = null;
                    }      
                }else{
                    orders.push(a);
                }
            }
            distributionsWithOrders2.push({id:d.id,orders:orders});

        }
        
        json({
            id : sub.id,
            startDate : sub.startDate,
            endDate : sub.endDate,
            user : sub.user.infos(),
            user2 : sub.user2==null ? null : sub.user2.infos(),
            catalogId : sub.catalog.id,
            constraints : SubscriptionService.getSubscriptionConstraints(sub),
            totalOrdered : sub.getTotalPrice(),
            balance : sub.getBalance(),
            distributions:distributionsWithOrders2,
            absentDistribIds:sub.getAbsentDistribIds(),
            defaultOrder : sub.getDefaultOrders()
        });
    }

}