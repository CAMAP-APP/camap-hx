package controller.api;
import sys.io.File;
import haxe.crypto.Base64;
import Common;

/**
 * Product API
 * @author fbarbut
 */
class Product extends Controller
{
	
	public function  doDefault(product:db.Product) {
		Sys.print(haxe.Json.stringify(product.infos()));
	}
	
	
	
	/**
		List all products of a conctract
	**/
	public function doGet( args : { ?catalogId : db.Catalog } ) {
	
		if( args == null || args.catalogId == null ) throw "invalid params";

		var out = { products:new Array<ProductInfo>() };
		for( p in args.catalogId.getProducts(false) ) out.products.push( p.infos(false,false) ); 
		Sys.print( tink.Json.stringify(out) );
	}

}