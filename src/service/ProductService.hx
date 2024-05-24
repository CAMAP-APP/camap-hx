package service;

import Common.StockTracking;
import controller.Product;
import sugoi.form.elements.Html;
import tink.core.Error;

class ProductService{


	/**
	 * Batch disable products
	 */
	public static function batchDisableProducts(productIds:Array<Int>){

		var data = {pids:productIds,enable:false};
		var contract = db.Product.manager.get(productIds[0], true).catalog;
		var products = contract.getProducts(false);

		App.current.event( BatchEnableProducts(data) );
		
		for ( pid in data.pids){
			
			var p = db.Product.manager.get(pid, true);

			if ( Lambda.find(products,function(p) return p.id==pid)==null ) throw 'product $pid is not in this contract !';
			
			p.active = false;
			p.update();
		}
	}


	/**
	 * Batch enable products
	 */
	public static function batchEnableProducts(productIds:Array<Int>){

		var data = {pids:productIds,enable:true};
		var contract = db.Product.manager.get(productIds[0], true).catalog;
		var products = contract.getProducts(false);

		App.current.event( BatchEnableProducts(data) );
		
		for ( pid in data.pids){
			
			var p = db.Product.manager.get(pid, true);

			if ( Lambda.find(products,function(p) return p.id==pid)==null ) throw 'product $pid is not in this contract !';
			
			p.active = true;
			p.update();
		}
	}

	inline public static function getHTPrice(ttcPrice:Float,vatRate:Float):Float{
		return ttcPrice / (1 + vatRate / 100);
	}

	/**
		duplicate a product
	**/
	public static function duplicate(source_p:db.Product):db.Product{
		var p = new db.Product();
		p.name = source_p.name;
		p.qt = source_p.qt;
		p.price = source_p.price;
		p.catalog = source_p.catalog;
		p.image = source_p.image;
		p.desc = source_p.desc;
		p.ref = source_p.ref;
		p.stock = source_p.stock;
		p.vat = source_p.vat;
		p.organic = source_p.organic;
		p.unitType = source_p.unitType;
		p.multiWeight = source_p.multiWeight;
		p.variablePrice = source_p.variablePrice;
		p.insert();
		
		//custom categs
		// for (source_cat in source_p.getCategories()){
		// 	var cat = new db.ProductCategory();
		// 	cat.product = p;
		// 	cat.category = source_cat;
		// 	cat.insert();
		// }
		return p;
	}

	public static function getForm(?product:db.Product,?catalog:db.Catalog):sugoi.form.Form{

		if(product==null){
			product = new db.Product();
			product.catalog = catalog;
		} 

		var f = form.CamapForm.fromSpod(product);
		f.getElement("bulk").description = "Ce produit est vendu en vrac ( sans conditionnement ). Le poids/volume commandé peut être corrigé après pesée.";
		f.getElement("bulk").docLink = "https://wiki.amap44.org/fr/app/admin-gestion-produits#option-vrac-uniquement-contrat-variable";
		f.getElement("variablePrice").description = "Le prix final sera calculé en fonction du poids/volume réel après pesée.";
		f.getElement("variablePrice").docLink = "https://wiki.amap44.org/fr/app/admin-gestion-produits#option-prix-variable-selon-pes%C3%A9e-uniquement-contrat-variable";
		f.getElement("multiWeight").description = "Permet d'avoir une ligne de commande par exemplaire du produit commandé (sans cumul).";
		f.getElement("multiWeight").docLink = "https://wiki.amap44.org/fr/app/admin-gestion-produits#option-multi-pes%C3%A9e";

		if (product.catalog.isConstantOrdersCatalog()){
			f.removeElementByName ('bulk');
			f.removeElementByName ('variablePrice');
		}

		//stock mgmt ?
		if (!product.catalog.hasStockManagement()){
			f.removeElementByName('stock');
			f.removeElementByName('currentStock');
			f.removeElementByName('stockTracking');	
			f.removeElementByName('stockTrackingPerDistrib');	
		} 
		else 
		{
			//manage stocks by distributions for CSA contracts
			var stock = f.getElement("stock");
			var now = Date.now();

			//Nbre de distri restantes
			var distLeft = db.Distribution.manager.count( $date >= now && $catalogId==product.catalog.id);
			// Si distri > 0
			if (distLeft > 0) {
				stock.label = "Stock par distribution ("+distLeft+ " distributions restantes)";				 
				if (product.stock!=null){
					stock.value = product.stock;
				}

				// Si catalog, on est en mode création et on a pas encore configuré de stock
				// Si catalog == null, on est en mode modification et c'est intéressant d'afficher une info de stock
				if (catalog == null) {
					var stockElem = f.getElement("stock");
					var nextDistribs = db.Distribution.manager.search( ($date >= now && $catalogId==product.catalog.id),{orderBy: date}).array();
					if (nextDistribs[0] != null) {
						var stockDate = DateTools.format(nextDistribs[0].date,"%d/%m/%Y");
						var t = sugoi.i18n.Locale.texts;
						f.addElement(
							new sugoi.form.elements.Html(
								"avalaibleStockInfo", 
								'<div style="padding-top:6px">${product.getAvailableStock(nextDistribs[0].id, null)}</div>', 
								t._("Available stock") + ' <i class="icon icon-info" data-toggle="tooltip" data-placement="left" title="Stock pour la distribution du ${stockDate}">&nbsp;</i>'
							), 
							f.elements.indexOf(stockElem) + 1 // after "stocks"
						);
					}
				}
			} else {
				// Sinon (pas distri planifiées)
				stock.label = "Stock (par distribution): vous devez planifier au moins une distribution avant de définir le stock";				 
				product.stock = null;
				stock.value = product.stock;
			}
			
		}
			
			
		var group = product.catalog.group;
		
		//VAT selector
		f.removeElement( f.getElement('vat') );		
		var data:sugoi.form.ListData.FormData<Float> = group.getVatRates().map(r -> {label:r.label,value:r.value,desc:null,docLink:null});
		f.addElement( new sugoi.form.elements.FloatSelect("vat", "TVA", data, product.vat ) );

		f.removeElementByName("catalogId");
		
		return f;
	}


	/**
		check that a product is well configured
	**/
	public static function check(product:db.Product){
		if(product.bulk){			
			if(product.unitType==null) throw new Error("Vous devez définir l'unité de votre produit si l'option 'vrac' est activée");
			if(product.qt==null) throw new  Error("Vous devez définir une quantité si l'option 'vrac' est activée");
			if(product.multiWeight) throw new Error("Un produit en vrac ne peut pas être aussi en multi-pesée.");			
		}
	}
}