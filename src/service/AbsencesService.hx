package service;
import tink.core.Error;

/**
    Manage absences in CSA subscriptions
**/
class AbsencesService {

    /**
		get possible absence distribs of this catalog
	**/
	public static function getContractAbsencesDistribs( catalog:db.Catalog ) : Array<db.Distribution> {
		if ( !catalog.hasAbsencesManagement() ) return [];
		return db.Distribution.manager.search( $catalog == catalog && $date >= catalog.absencesStartDate && $end <= catalog.absencesEndDate, { orderBy : date }, false ).array();
	}

    public static function getAbsencesDescription( catalog : db.Catalog ) {
		if( catalog.isVariableOrdersCatalog() && catalog.distribMinOrdersTotal==0 ) return "Pas de gestion des absences car la commande n'est pas obligatoire à chaque distribution";
		if ( catalog.absentDistribsMaxNb==0 || catalog.absentDistribsMaxNb==null ) return "Pas d'absences autorisées";
		if(catalog.absentDistribsMaxNb>0 && catalog.absencesStartDate==null ) throw "Une période d'absence doit être définie pour ce contrat";
		return '${catalog.absentDistribsMaxNb} absences maximum autorisées  du ${DateTools.format( catalog.absencesStartDate, "%d/%m/%Y" )} au ${DateTools.format( catalog.absencesEndDate, "%d/%m/%Y")} ';
	}

    /**
		set subscriptions absence distributions
	**/
	public static function setAbsences( subscription:db.Subscription, distribIds:Array<Int>, adminMode:Bool ) {

		//check there is no duplicates
		if(tools.ArrayTool.deduplicate(distribIds).length != distribIds.length){
			throw new Error(500,"Vous ne pouvez pas choisir deux fois la même distribution");
		}

		//check if absence number is correct
		if(subscription.id!=null && distribIds.length != subscription.getAbsencesNb() && !adminMode){
			throw new Error('Cette souscription ne prend que ${subscription.getAbsencesNb()} absences');
		}

		//check if absent distribs are correct
		var possibleDistribs = subscription.getPossibleAbsentDistribs().map(d -> d.id);
		for(did in distribIds){
			if(!possibleDistribs.has(did)){
				throw new Error('Distrib #${did} is not in possible absent distribs');
			} 
		}

		// /!\ we dont check here if a *new* absence has been set on a closed distribution !
		// --> On the frontend, closed distributions are disabled and cannot be selected.
		
		if( distribIds != null && distribIds.length != 0 ) {
			distribIds.sort( function(b, a) { return  a < b ? 1 : -1; } );
			subscription.absentDistribIds = distribIds.join(',');
		} else {
			subscription.absentDistribIds = null;
		}
	}

	public static function getAbsentDistribsMaxNb( catalog:db.Catalog/*, ?subscription:Subscription*/ ) {


		if ( !catalog.hasAbsencesManagement() ) return 0;
		return catalog.absentDistribsMaxNb;

		/*if ( subscription == null || subscription.startDate == null || subscription.endDate == null ||
			( subscription.startDate.getTime() <= catalog.absencesStartDate.getTime() && subscription.endDate.getTime() >= catalog.absencesEndDate.getTime() ) ) {
			return catalog.absentDistribsMaxNb;
		} else {

			var absencesDistribsNbDuringSubscription = 0;
			if ( subscription.startDate.getTime() > catalog.absencesStartDate.getTime() && subscription.endDate.getTime() < catalog.absencesEndDate.getTime() ) {
				absencesDistribsNbDuringSubscription = db.Distribution.manager.count( $catalog == catalog && $date >= subscription.startDate && $end <= subscription.endDate );
			} else if ( subscription.startDate.getTime() > catalog.absencesStartDate.getTime() ) {
				absencesDistribsNbDuringSubscription = db.Distribution.manager.count( $catalog == catalog && $date >= subscription.startDate && $end <= catalog.absencesEndDate );
			} else {
				absencesDistribsNbDuringSubscription = db.Distribution.manager.count( $catalog == catalog && $date >= catalog.absencesStartDate && $end <= subscription.endDate );
			}

			if ( absencesDistribsNbDuringSubscription <= catalog.absentDistribsMaxNb ) {
				return absencesDistribsNbDuringSubscription;
			} else {
				return catalog.absentDistribsMaxNb;
			}
		}*/
	}

	/**
		get automatically absence distributions from an asbence number ( last distributions of the subscription )
	**/
	public static function getAutomaticAbsentDistribs(catalog:db.Catalog, absencesNb:Int):Array<db.Distribution>{		
		if( !catalog.hasAbsencesManagement() ) return [];
		if(absencesNb==null) return [];
		
		if ( absencesNb > catalog.absentDistribsMaxNb ) {
			throw new Error( 'Nombre de jours d\'absence invalide, vous avez droit à ${catalog.absentDistribsMaxNb} jours d\'absence maximum.' );
		}

		var distribs = AbsencesService.getContractAbsencesDistribs(catalog);
		if ( absencesNb > distribs.length ) {
			throw new Error( 'Nombre de jours d\'absence invalide, il n\'y a que ${distribs.length} distributions pendant le période d\'absence de cette souscription.' );
		}

		//sort from later to sooner distrib
		distribs.sort( (a,b)-> Math.round(b.date.getTime()/1000) - Math.round(a.date.getTime()/1000) );

		return distribs.slice(0,absencesNb);
	}

	/**
		Update Absences Number on an existing subscription
	**/
	/*public static function setAbsencesNb( subscription:db.Subscription, absencesNb:Int, adminMode:Bool ) {

		if( subscription == null ) throw new Error( 'La souscription n\'existe pas' );
		if( !subscription.catalog.hasAbsencesManagement() ) return;
		if(absencesNb==null) return;
		
		//a user can only choose absenceNb on subscription creation
		//an admin can change it at anytime
		if ( subscription.id == null || adminMode) {
			
			if(absencesNb == subscription.getAbsencesNb()){
				return;
			}
			
			if ( absencesNb > subscription.catalog.absentDistribsMaxNb ) {
				throw new Error( 'Nombre de jours d\'absence invalide, vous avez droit à ${subscription.catalog.absentDistribsMaxNb} jours d\'absence maximum.' );
			}

			var distribs = subscription.getPossibleAbsentDistribs();
			if ( absencesNb > distribs.length ) {
				throw new Error( 'Nombre de jours d\'absence invalide, il n\'y a que ${distribs.length} distributions pendant le période d\'absence de cette souscription.' );
			}


			//sort from later to sooner distrib
			distribs.sort( (a,b)-> Math.round(b.date.getTime()/1000) - Math.round(a.date.getTime()/1000) );

			subscription.setAbsences( distribs.slice(0,absencesNb).map(d -> d.id) );

		} else {
			throw new Error('Il n\'est pas possible de modifier le nombre de jours d\'absence sur une souscription déjà créée.' );			
		}
	}*/

	/**
		can change absences number ?
	**/
	public static function canAbsencesNbBeEdited( catalog:db.Catalog, subscription:db.Subscription ):Bool {

		if( !catalog.hasAbsencesManagement() ) return false;

		if(subscription!=null){
			if(subscription.id==null){
				//can edit absence number only on creation
				return true;
			}else{
				return false;
			}

		}else{
			return true;
		}
		// var lastDistribBeforeAbsences = getLastDistribBeforeAbsences( catalog );
		// if( lastDistribBeforeAbsences == null ) return false;

		// var deadline = lastDistribBeforeAbsences.date.getTime();
		// var beforeDeadline = Date.now().getTime() < deadline;
		// var subscriptionInAbsencesPeriod = subscription == null || ( subscription.startDate.getTime() < deadline && subscription.endDate.getTime() > catalog.absencesStartDate.getTime() );
		// var forbidden = catalog.type == db.Catalog.TYPE_CONSTORDERS && subscription != null && subscription.paid();

		// return !forbidden && beforeDeadline && subscriptionInAbsencesPeriod;
		
	}

	/**
		Updates a subscription's absences
	**/
	public static function updateAbsencesDates( subscription:db.Subscription, newAbsentDistribIds:Array<Int>,adminMode:Bool ) {
		var oldAbsentDistribIds = subscription.getAbsentDistribIds();

		subscription.lock();
		setAbsences( subscription, newAbsentDistribIds, adminMode );
		subscription.update();

		if ( subscription.catalog.isConstantOrdersCatalog() ) {
			//regen recurrent orders
			var ss = new SubscriptionService();
			ss.createRecurrentOrders( subscription, subscription.getDefaultOrders());
		} else {
			//remove orders in new absence dates
			var absentDistribsOrders = db.UserOrder.manager.search( $subscription == subscription && $distributionId in newAbsentDistribIds, false );
			for ( order in absentDistribsOrders ) {
				order.lock();
				order.delete();
			}
			
			// create the default order on the new date
			if(subscription.catalog.hasDefaultOrdersManagement()) {
				
				// check the dates of previous absence that becomes presence
				var newDistribPresence:Array<Int> = new Array<Int>();
			for (i in 0...oldAbsentDistribIds.length) {
				var distributionId = oldAbsentDistribIds[i];
				if (!newAbsentDistribIds.has(distributionId)) {
						newDistribPresence.push(distributionId);
					}
				}
				var ordersData = subscription.getDefaultOrders();
				
				// used to be absent at the distrib but not anymore: create the default order
				for (i in 0...newDistribPresence.length) {
					var distribution = db.Distribution.manager.get(newDistribPresence[i]);
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
							try {
								OrderService.make( subscription.user, order.quantity , product,  distribution.id, false, subscription, user2, invert );
							} catch (e : Error) {
								throw new Error(Forbidden, 'Impossible de créer la commande par défaut sur la date où vous n\'êtes plus absent (${DateTools.format(distribution.date,"%d/%m/%Y")}): ${e.message}');
							}
 						}
					}
				}
			}

		}

	}
}