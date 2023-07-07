package controller;
import service.ProductService;
import sys.db.RecordInfos;
import neko.Utf8;
import haxe.io.Encoding;
import haxe.io.Bytes;
import sugoi.form.Form;
import Common;
import sugoi.form.ListData.FormData;
import sugoi.form.elements.FloatInput;
import sugoi.form.elements.FloatSelect;
import sugoi.form.elements.IntSelect;
using Std;

class Product extends Controller
{
	public function new()
	{
		super();
		view.nav = ["contractadmin","products"];
	}
	
	@tpl('form.mtt')
	function doEdit(product:db.Product) {
		
		if (!app.user.canManageContract(product.catalog)) throw t._("Forbidden access");
		
		var f = ProductService.getForm(product);		
		
		if (f.isValid()) {

			f.toSpod(product);

			//manage stocks by distributions for CSA contracts
			if(product.catalog.hasStockManagement() && f.getValueOf("stock")!=null){
				var distribNum = product.catalog.getDistribs(false).length;
				distribNum = distribNum == 0 ? 1 : distribNum;
				product.stock = (f.getValueOf("stock"):Float) * distribNum;
			}

			try{
				ProductService.check(product);
			}catch(e:tink.core.Error){
				throw Error(sugoi.Web.getURI(),e.message);
			}

			app.event(EditProduct(product));
			product.update();
			throw Ok('/contractAdmin/products/'+product.catalog.id, t._("The product has been updated"));
		} else {
			app.event(PreEditProduct(product));
		}
		
		view.form = f;
		view.title = t._("Modify a product");
	}
	
	@tpl("form.mtt")
	public function doInsert(contract:db.Catalog ) {
		
		if (!app.user.isContractManager(contract)) throw Error("/", t._("Forbidden action")); 
		
		var product = new db.Product();
		var f = ProductService.getForm(null,contract);
	
		if (f.isValid()) {

			f.toSpod(product);
			product.catalog = contract;

			try{
				ProductService.check(product);
			}catch(e:tink.core.Error){
				throw Error(sugoi.Web.getURI(),e.message);
			}
			
			app.event(NewProduct(product));
			product.insert();
			throw Ok('/contractAdmin/products/'+product.catalog.id, t._("The product has been saved"));
		}
		else {

			app.event(PreNewProduct(contract));
		}
		
		view.form = f;
		view.title = t._("Key-in a new product");
	}
	
	public function doDelete(p:db.Product) {
		
		if (!app.user.canManageContract(p.catalog)) throw t._("Forbidden access");
		
		if (checkToken()) {
			
			app.event(DeleteProduct(p));
			
			var orders = db.UserOrder.manager.search($productId == p.id, false);
			if (orders.length > 0) {
				throw Error("/contractAdmin", t._("Not possible to delete this product because some orders are referencing it"));
			}
			var cid = p.catalog.id;
			p.lock();
			p.delete();
			
			throw Ok("/contractAdmin/products/"+cid, t._("Product deleted"));
		}
		throw Error("/contractAdmin", t._("Token error"));
	}
	
	
	@tpl('product/import.mtt')
	function doImport(c:db.Catalog, ?args: { confirm:Bool } ) {
		
		if (!app.user.canManageContract(c)) throw t._("Forbidden access");
			
		var csv = new sugoi.tools.Csv();
		csv.step = 1;
		var request = sugoi.tools.Utils.getMultipart(1024 * 1024 * 4);
		csv.setHeaders( ["productName","price","ref","desc","qt","unit","organic","bulk","variablePrice","vat","stock"] );
		view.contract = c;
		
		// get the uploaded file content
		if (request.get("file") != null) {
			var csvData = request.get("file");
			csvData = Formatting.utf8(csvData);
			var datas = csv.importDatasAsMap(csvData);
			
			app.session.data.csvImportedData = datas;
			
			csv.step = 2;
			view.csv = csv;
		}
		
		if (args != null && args.confirm) {
			var i : Iterable<Map<String,String>> = cast app.session.data.csvImportedData;
			var fv = new sugoi.form.filters.FloatFilter();
			
			for (p in i) {
				
				if (p["productName"] != null){

					var product = new db.Product();
					product.name = p["productName"];
					product.price = fv.filterString(p["price"]);
					product.ref = p["ref"];
					product.desc = p["desc"];
					product.vat = fv.filterString(p["vat"]);
					product.qt = fv.filterString(p["qt"]);
					if(p["unit"]!=null){
						product.unitType = switch(p["unit"].toLowerCase()){
							case "kg" : Kilogram;
							case "g" : Gram;
							case "l" : Litre;
							case "cl" : Centilitre;
							case "litre" : Litre;
							case "ml" : Millilitre;
							default : Piece;
						}
					}
					if (p["stock"] != null) product.stock = fv.filterString(p["stock"]);
					product.organic = p["organic"] == "1";
					product.bulk = p["bulk"] == "1";
					product.variablePrice = p["variablePrice"] == "1";
					
					product.catalog = c;
					product.insert();
				}
				
			}
			
			view.numImported = app.session.data.csvImportedData.length;
			app.session.data.csvImportedData = null;
			
			csv.step = 3;
		}
		
		if (csv.step == 1) {
			//reset import when back to import page
			app.session.data.csvImportedData =	null;
		}
		
		view.step = csv.step;
	}
	
	public function doExport(c:db.Catalog){

		var data = new Array<Dynamic>();
		for (p in c.getProducts(false)) {
			data.push({
				"id": p.id,
				"name": p.name,
				"ref": p.ref,
				"price": p.price,
				"vat": p.vat,
				"catalogId": c.id,
				"vendorId": c.vendor.id,
				"unit": p.unitType,
				"quantity": p.qt,
				"active": p.active,
				"image": "https://"+App.config.HOST+p.getImage(),
			});
		}

		sugoi.tools.Csv.printCsvDataFromObjects(data, [
			"id", "name", "ref", "price", "vat", "catalogId", "vendorId", "unit", "quantity", "active", "image"], "Export-produits-" + c.name + "-CAMAP");
		return;
		
	}
	
	
	
}