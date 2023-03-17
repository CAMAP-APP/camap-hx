package controller;
import db.Catalog;
import haxe.crypto.Md5;
import service.VendorService;
import sugoi.form.Form;
import sugoi.tools.Utils;


class Vendor extends Controller
{

	public function new()
	{
		super();
		
		if (!app.user.isContractManager()) throw t._("Forbidden access");
		
	}
	
	@tpl('vendor/addimage.mtt')
	function doAddImage(vendor:db.Vendor) {
		if(!app.user.canManageVendor(vendor))  throw Error("/contractAdmin","Vous n'avez pas les droits de modification de ce producteur");
		view.vendor = vendor;
	}

}