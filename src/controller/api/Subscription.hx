package controller.api;

import haxe.Json;
import service.OrderService;
import service.SubscriptionService;
import tink.core.Error;

typedef OrdersDto = Array<{id:Int, orders:Array<{productId:Int, qty:Float}>}>;

typedef NewSubscriptionDto = {
	userId:Int,
	catalogId:Int,
	defaultOrder:Array<CSAOrder>,
	absentDistribIds:Array<Int>,
	initialOrders:OrdersDto
};

typedef UpdateOrdersDto = {
	// id is distributionId
	distributions:OrdersDto,
};

class Subscription extends Controller {
	/**
		Get or create a subscription
	**/
	public function doDefault(?sub:db.Subscription) {
		// Create a new sub
		var post = sugoi.Web.getPostData();
		if (post != null && sub == null) {
			var newSubData:NewSubscriptionDto = Json.parse(StringTools.urlDecode(post));
			var user = db.User.manager.get(newSubData.userId, false);
			var catalog = db.Catalog.manager.get(newSubData.catalogId, false);

      var isAdmin = app.user.isAdmin();
      var isGroupManager = app.user.isGroupManager();
      var canManage = app.user.canManageContract(catalog);
      var isSelf = app.user.id == user.id;

      if (!isAdmin && !canManage && !isSelf && !isGroupManager) {
        throw new Error(403, "Vous ne disposez pas des droits (Gestionnaire de catalogue ou Administrateur) pour créer une souscription pour cet utilisateur");
      }

			// Ajout Amaury blocage souscriptions sauvages
			if (!catalog.hasOpenOrders() && !canManage && !isAdmin && !isGroupManager) {
				throw new Error("Les souscriptions à ce catalogue sont fermées. Veuillez contacter le coordinateur du contrat.");
			}

			var ss = new SubscriptionService();
      ss.adminMode = true;
			sub = ss.createSubscription(user, catalog, newSubData.defaultOrder, newSubData.initialOrders, newSubData.absentDistribIds);
		}

		getSubscription(sub);
	}

	/**
		update Orders of a subscription
	**/
	public function doUpdateOrders(sub:db.Subscription) {
		// Create a new sub
		var post = sugoi.Web.getPostData();
		if (post != null) {
			var updateOrdersData:UpdateOrdersDto = Json.parse(StringTools.urlDecode(post));

			if (!app.user.isAdmin() && !app.user.canManageContract(sub.catalog) && app.user.id != sub.user.id) {
				throw new Error(403, "Vous n'êtes pas autorisé à modifier la souscription de cet utilisateur.");
			}
			// Ajout Amaury blocage souscriptions sauvages
			if (!sub.catalog.hasOpenOrders()
				&& !app.user.canManageContract(sub.catalog) && !app.user.isAdmin() && !app.user.isGroupManager()) {
				throw new Error("Les souscriptions à ce catalogue sont fermées. Veuillez contacter le coordinateur du contrat.");
			}

			var ss = new SubscriptionService();
      ss.adminMode = true;
			ss.updateOrders(sub, updateOrdersData.distributions);
		}

		getSubscription(sub);
	}

	public function doUpdateDefaultOrder(sub:db.Subscription) {
		// Create a new sub
		var post = sugoi.Web.getPostData();
		if (post != null) {
			var updateDefaultOrderData:Array<CSAOrder> = Json.parse(StringTools.urlDecode(post));

			if (!app.user.isAdmin() && !app.user.canManageContract(sub.catalog) && app.user.id != sub.user.id) {
				throw new Error(403, "Vous n'êtes pas autorisé à modifier la souscription de cet utilisateur.");
			}

			var ss = new SubscriptionService();
      if (app.user.isAdmin() || app.user.canManageContract(sub.catalog) || app.user.isGroupManager()) {
        ss.adminMode = true;
      }
			try {
				ss.updateDefaultOrders(sub, updateDefaultOrderData);
			} catch (e:tink.core.Error) {
				// throw (e);
				throw TypedError.typed(e.message, SubscriptionServiceError.InvalidParameters);
			}
		}

		getSubscription(sub);
	}

	/**
		Check default order for constraints, before creating the subscription
	**/
	public function doCheckDefaultOrder(catalog:db.Catalog) {
		var post = sugoi.Web.getPostData();
		if (post != null) {
			var defaultOrder:Array<CSAOrder> = Json.parse(StringTools.urlDecode(post));
			var ordersByDistrib:Map<db.Distribution, Array<CSAOrder>> = null;
			if (catalog.hasStockManagement()) {
				ordersByDistrib = buildOrdersByDistrib(catalog, defaultOrder);
				OrderService.assertStocksAvailable(catalog, ordersByDistrib);
			}

			// no default order to check in those cases
			if (catalog.isConstantOrdersCatalog() || (catalog.distribMinOrdersTotal == 0 && catalog.catalogMinOrdersTotal == 0)) {
				return json({defaultOrderCheck: true});
			}

			if (ordersByDistrib == null)
				ordersByDistrib = buildOrdersByDistrib(catalog, defaultOrder);
			if (SubscriptionService.checkVarOrders(ordersByDistrib)) {
				json({defaultOrderCheck: true});
			}
		}
	}

	private function buildOrdersByDistrib(catalog:db.Catalog, defaultOrder:Array<CSAOrder>) {
		var ordersByDistrib = new Map<db.Distribution, Array<CSAOrder>>();
		var distribs = db.Distribution.manager.search($catalog == catalog
			&& $date >= SubscriptionService.getNewSubscriptionStartDate(catalog));
		var ordersByDistrib = new Map<db.Distribution, Array<CSAOrder>>();
		for (d in distribs) {
			try {
				ordersByDistrib.set(d, defaultOrder);
			} catch (e:tink.core.Error) {
				throw(e);
			}
		}
		return ordersByDistrib;
	}

	private function getSubscription(sub:db.Subscription) {
		var distributionsWithOrders = new Array<{id:Int, orders:Array<{id:Int, productId:Int, qty:Float}>}>();
		for (d in SubscriptionService.getSubscriptionDistributions(sub, "allIncludingAbsences")) {
			distributionsWithOrders.push({
				id: d.id,
				orders: d.getUserOrders(sub.user).array().map(o -> {
					id: o.id,
					productId: o.product.id,
					qty: o.quantity
				})
			});
		}

		// merge multiweight products on each distrib
		var distributionsWithOrders2 = [];
		for (d in distributionsWithOrders) {
			var orders:Array<{id:Int, productId:Int, qty:Float}> = [];
			for (a in d.orders) {
				if (a.qty == 0)
					continue;
				var p = db.Product.manager.get(a.productId, false);
				if (p.multiWeight) {
					var existing = orders.find(a -> a.productId == p.id);
					if (existing == null) {
						a.qty = 1;
						orders.push(a);
					} else {
						existing.qty++;
						existing.id = null;
					}
				} else {
					orders.push(a);
				}
			}
			distributionsWithOrders2.push({id: d.id, orders: orders});
		}

		var minSubscriptionOrder = SubscriptionService.getMinOrdersTotalPoportional(sub.catalog, sub);

		json({
			id: sub.id,
			startDate: sub.startDate,
			endDate: sub.endDate,
			user: sub.user.infos(),
			user2: sub.user2 == null ? null : sub.user2.infos(),
			catalogId: sub.catalog.id,
			constraints: SubscriptionService.getSubscriptionConstraints(sub),
			totalOrdered: sub.getTotalPrice(),
			balance: sub.getBalance(),
			distributions: distributionsWithOrders2,
			absentDistribIds: sub.getAbsentDistribIds(),
			defaultOrder: sub.getDefaultOrders(),
			minSubscriptionOrder: minSubscriptionOrder
		});
	}
}
