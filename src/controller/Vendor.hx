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

	@tpl('form.mtt')
	function doEdit(vendor:db.Vendor) {
		
		if(!app.user.canManageVendor(vendor))  throw Error("/contractAdmin","Vous n'avez pas les droits de modification de ce producteur");

		app.session.addMessage("Attention, les fiches producteurs sont partagées entre les AMAP, n'ajoutez pas d'informations propres à votre AMAP.");
		if (vendor.isDisabled()) {
			app.session.addMessage('<div class="alert-danger"><i class="icon icon-alert"> </i><b>Ce producteur est désactivé.</b>  ${vendor.getDisabledReason()}' );
		}

		var form = VendorService.getForm(vendor);
		
		if (form.isValid()){
			vendor.lock();
			try{
				vendor = VendorService.update(vendor,form.getDatasAsObject());
			}catch(e:tink.core.Error){
				throw Error(sugoi.Web.getURI(),e.message);
			}			
			vendor.update();		
			throw Ok('/contractAdmin', t._("This supplier has been updated"));
		}

		view.form = form;
	}

}