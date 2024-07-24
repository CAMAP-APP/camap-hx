package controller.api;
import Common.StockTracking;
import haxe.Json;
import neko.Web;
import service.AbsencesService;
import service.SubscriptionService;
import tink.core.Error;

class Catalog extends Controller
{

    /**
        get a catalog
    **/
	public function doDefault(catalog:db.Catalog){
		var distributions = catalog.getDistribs(false).array().map(d -> d.getInfos());
		var products = catalog.getProducts();

        var ss = new SubscriptionService();
        var out = {
            id : catalog.id,
            name : catalog.name,
            description : catalog.description,
            type : catalog.type,
            startDate   : catalog.startDate,
            endDate     : catalog.endDate,
            vendor:catalog.vendor.getInfos(),
            products: products.array().map( p -> p.infos() ),
            contact: catalog.contact==null ? null : catalog.contact.infos(),
            documents : catalog.getVisibleDocuments(app.user).array().map(ef -> {name:ef.file.name,url:"/file/"+sugoi.db.File.makeSign(ef.file.id)}),
            distributions : distributions,
            constraints : SubscriptionService.getContractConstraints(catalog),
            absences : AbsencesService.getAbsencesDescription(catalog),
            absentDistribsMaxNb : catalog.absentDistribsMaxNb,
            distribMinOrdersTotal : catalog.distribMinOrdersTotal,
            hasStockManagement: catalog.hasStockManagement()
        }

        json(out);

    }

    /**
        absences infos when there is no subscription
    **/
    public function doCatalogAbsences(catalog:db.Catalog){
        json({
            startDate : catalog.absencesStartDate,
            endDate : catalog.absencesEndDate,
            absentDistribsMaxNb : catalog.absentDistribsMaxNb,
            possibleAbsentDistribs : AbsencesService.getContractAbsencesDistribs(catalog).map(d -> d.getInfos())
        });
    }
    
	public function doStocksPerProductDistribution( catalog:db.Catalog ) {

		var stocksPerProductDistribution:Map<Int, Map<Int, Float>> = null;
        if (catalog.hasStockManagement()) {
			stocksPerProductDistribution = new Map<Int, Map<Int, Float>>();
			for (product in catalog.getProducts()) {
				var stocksPerDistrib = new Map<Int, Float>();
				for (distrib in catalog.getDistribs()) {
					if (product.stockTracking != StockTracking.Disabled) {
						stocksPerDistrib.set(distrib.id, product.getAvailableStock(distrib.id));
					}
				}
				stocksPerProductDistribution.set(product.id, stocksPerDistrib);
			}
		}
		json(Formatting.mapToObject(stocksPerProductDistribution));

	}


    /**
        Get and set asbences of a Subscription
    **/
    public function doSubscriptionAbsences(sub:db.Subscription){

		if ( !app.user.canManageContract(sub.catalog) && !(app.user.id==sub.user.id) ){
			throw new Error(Forbidden,t._('Access forbidden') );
		} 
		
		if( !sub.catalog.hasAbsencesManagement() ) {
			throw new Error(Forbidden,t._('no absences management in this catalog') );
		}
		
		var absenceDistribs = sub.getAbsentDistribs();
		var possibleAbsences = sub.getPossibleAbsentDistribs();
		var now = Date.now().getTime();
		possibleAbsences = possibleAbsences.filter(d -> d.orderEndDate.getTime() > now);
		var lockedDistribs = absenceDistribs.filter( d -> d.orderEndDate.getTime() < now);	//absences that are not editable anymore
		
        var post =  sugoi.Web.getPostData();
        if(post!=null){
					  // we pass adminMode in absencesServicesbecause admin can add absences, contrary to target user
						// this is used in batchOrders page
						var adminMode = app.user.canManageContract( sub.catalog );

            /*
            POST payload should be like {"absentDistribIds":[1,2,3]}
            */
            var newAbsentDistribIds:Array<Int> = Json.parse(StringTools.urlDecode(post)).absentDistribIds;
            
						if (newAbsentDistribIds==null || (newAbsentDistribIds.length==0 && !adminMode)) {
                throw new Error(BadRequest,"bad parameter");
            }
						
            AbsencesService.updateAbsencesDates( sub, newAbsentDistribIds, adminMode );
        }

        /**
            once the sub is created, absent distribs number cannot be changed.
            But asbence distribs can be chosen, until they are not-yet-closed distribs
        **/
        var catalog = sub.catalog;
        json({
            startDate : catalog.absencesStartDate,
            endDate : catalog.absencesEndDate,
            absentDistribsNb : sub.getAbsencesNb(),
            absentDistribIds : sub.getAbsentDistribIds(),
            closedDistribIds : lockedDistribs.map(d -> d.id),
            possibleAbsentDistribs : possibleAbsences.map(d -> d.getInfos())
        });
    }

}