package controller;
class Shop extends Controller
{
	/**
	 * Product infos popup used in many places
	*/
	@tpl('shop/productInfo.mtt')
	public function doProductInfo(p:db.Product,?args:{distribution:db.Distribution}) {
		var d = args!=null && args.distribution!=null ? args.distribution : null;
		view.p = p.infos(null,null,d);
		view.product = p;
		view.vendor = p.catalog.vendor;
	} 
}
