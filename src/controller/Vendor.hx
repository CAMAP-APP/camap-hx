package controller;
import haxe.Json;
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
	}

	function doDefault() {
		throw Redirect("/home");
	}

	// asking for dispatch in first argument allows us to use BrowserRouter in front
	@tpl('neoPublic.mtt')
	function doView(d: haxe.web.Dispatch, vendor:db.Vendor) {
		if(vendor.disabled != null)
			throw t._("Vendor is no Longer available");

		view.container = 'container-fluid';
		view.og = {
			path: 'vendor/view/${vendor.id}',
			description: vendor.desc,
			title: vendor.name
		}
		view.containerId = "vendorProfile";
		view.module = "vendorProfile";
		view.args = {
			vendor: vendor.getInfos(true),
			basePath: '/vendor/view/${vendor.id}'
		};
	}

	@tpl('neo.mtt')
	function doDashboard() {
		if(!app.user.isVendor())
			throw Redirect("/home");
		view.noGroup = true;
		view.containerId = "vendorDashboard";
		view.module = "vendorDashboard";
		view.args = {};
	}
	
	@tpl('vendor/addimage.mtt')
	function doAddImage(vendor:db.Vendor) {
		if(!app.user.canManageVendor(vendor))  throw Error("/contractAdmin","Vous n'avez pas les droits de modification de ce producteur");
		view.vendor = vendor;
	}

	@tpl('form.mtt')
	function doEdit(vendor:db.Vendor) {
		
		if(!app.user.canManageVendor(vendor))
			throw Error("/contractAdmin","Vous n'avez pas les droits de modification de ce producteur");

		app.session.addMessage("Attention, les fiches producteurs sont partagées entre les AMAP, n'ajoutez pas d'informations propres à votre AMAP.");

		app.session.addMessage("Les producteurs peuvent a présent prendre le contrôle de leur fiche producteur, pour celà assurez-vous que l'email soit le même celui utilisé par le producteur sur son compte CAMAP.");

		if (vendor.isDisabled()) {
			app.session.addMessage('<b> Ce producteur est désactivé.</b>  ${vendor.getDisabledReason()}',true );
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