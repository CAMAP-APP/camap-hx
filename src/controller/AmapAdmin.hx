package controller;
import sugoi.form.elements.Html;
import sugoi.form.elements.Checkbox;
import haxe.EnumFlags;
import Common;
import datetime.DateTime;
import db.Group.GroupFlags;
import db.UserGroup;
import neko.Web;
import sugoi.form.Form;
import sugoi.form.elements.FloatInput;
import sugoi.form.elements.Input.InputType;
import sugoi.form.elements.IntInput;
import sugoi.form.elements.IntSelect;
import sugoi.form.elements.StringInput;
using tools.DateTool;

class AmapAdmin extends Controller
{

	public function new() 
	{
		super();
		if (!app.user.isAmapManager()) throw Error("/", t._("Access forbidden"));
		
		//lance un event pour demander aux plugins si ils veulent ajouter un item dans la nav
		var nav = new Array<Link>();
		
		nav.push({id:"payments",link:"/amapadmin/payments",name: t._("Means of payment"),icon:"payment-type" });

		var e = Nav(nav,"groupAdmin");
		app.event(e);
		view.nav = e.getParameters()[0];
	}
	
	@tpl("amapadmin/form.mtt")
	function doMembership(){
		
		addBc('membership',"Adhésions","amapadmin/membership");
		var form = new sugoi.form.Form("membership");
		var group = app.user.getGroup();

		//membership
		form.addElement( new sugoi.form.elements.Checkbox("membership","Gestion des adhésions",group.hasMembership), 13);
		form.addElement( new sugoi.form.elements.IntInput("membershipFee","Montant de l'adhésion (laisser vide si variable)",group.membershipFee), 14);
		var dp = new form.CamapDatePicker("membershipRenewalDate","Date de renouvellement annuelle des adhésions",group.membershipRenewalDate);
		// dp.format = "D MMMM";
		form.addElement( dp ,15 );
		//avoid modifiying another group
		var groupId = new sugoi.form.elements.IntInput("groupId","groupId",group.id);
		groupId.inputType = InputType.ITHidden;
		form.addElement( groupId );

		if (form.checkToken()) {

			if( form.getValueOf("groupId") != group.id ) throw "Vous avez changé de groupe.";

			group.lock();
			group.hasMembership = form.getValueOf("membership")==true;			
			group.membershipFee = form.getValueOf("membershipFee");
			group.membershipRenewalDate = form.getValueOf("membershipRenewalDate");
			group.update();
			throw Ok("/amapadmin","Paramètres d'adhésion mis à jour");
			
		}

		view.form = form;
		view.title = "Adhésions";
	}

	@tpl("amapadmin/default.mtt")
	function doDefault() {

		var group = app.user.getGroup();
		view.membersNum = UserGroup.manager.count($group == group);
		view.contractsNum = group.getActiveContracts().length;
		view.visibleOnMap = true;
	}
	
	@tpl("amapadmin/rights.mtt")
	public function doRights() {
		view.users = app.user.getGroup().getGroupAdmins();
		addBc('rights','Droits d\'administration','/amapadmin/rights');
	}
	
	
	@tpl("amapadmin/form.mtt")
	public function doEditRight(?u:db.User) {
		addBc('rights','Droits d\'administration','/amapadmin/rights');
		var form = new sugoi.form.Form("editRight");
		
		if (u == null) {
			form.addElement( new IntSelect("user", t._("Member") , app.user.getGroup().getMembersFormElementData(), null, true) );	
		}
		
		var data = [];
		data.push({label:t._("Group administrator"), value:"GroupAdmin"});
		data.push({label:t._("Membership management"),value:"Membership"});
		data.push({label:t._("Messages"),value:"Messages"});
		
		var ua : db.UserGroup = null;
		var populate :Array<String> = null;
		if (u != null) {
			ua = db.UserGroup.get(u, app.user.getGroup(), true);
			if (ua == null) throw "no user";
			populate = ua.getRights().map(r -> r.right);
		}
		
		form.addElement( new sugoi.form.elements.CheckboxGroup("rights", t._("Rights"), data, populate, true, true) );
		form.addElement( new sugoi.form.elements.Html("html","<hr/>"));
		
		//Rights on contracts
		var data = [];
		var populate :Array<String> = [];
		data.push({value:"contractAll",label:t._("All catalogs")});
		for (r in app.user.getGroup().getActiveContracts(true)) {
			data.push( { label:r.name , value:"contract"+Std.string(r.id) } );
		}
		
		if(ua!=null && ua.getRights()!=null && ua.getRights().length>0){
			for ( r in ua.getRights()) {
				switch(r.right) {
					case "ContractAdmin":
						if (r.params == null) {
							populate.push("contractAll");
						}else {
							populate.push("contract"+r.params[0]);	
						}
						
					default://
				}
			}
		}
		

		form.addElement( new sugoi.form.elements.CheckboxGroup("rights", t._("Catalogs management") , data, populate, true, true) );
		
		if (form.checkToken()) {
			
			var wasManager = app.user.isGroupManager();
			
			if (u == null) {				
				ua = db.UserGroup.manager.select($userId == Std.parseInt(form.getValueOf("user")) && $groupId == app.user.getGroup().id, true);
			}			

			ua.rights = "[]";

			var arr : Array<String> = cast form.getElement("rights").value;
			for ( r in arr) {
				if (r.substr(0, 8) == "contract") {
					if (r == "contractAll") {
						ua.giveRight( Right.ContractAdmin() );
					}else {
						ua.giveRight( Right.ContractAdmin(Std.parseInt(r.substr(8)) ) );	
					}
					
				}else {
					ua.giveRight( Right.createByName(r) );	
				}
			}
			
			//avoid "cut my own hands" problem
			if (ua.user.id == app.user.id && wasManager ) {
				if (!ua.hasRight(GroupAdmin)) {
					throw Error("/amapadmin/rights", t._("You cannot strip yourself of admin rights."));
				}
			}			
			
			ua.update();
			
			if (ua.getRights().length == 0) {
				throw Ok("/amapadmin/rights", t._("Rights removed"));
			}else {
				throw Ok("/amapadmin/rights", t._("Rights created or modified"));
			}
			
		}
		
		if (u == null) {
			view.title = t._("Give rights to a user");
		}else {
			view.title = t._("Modify the rights of ::user::",{user:u.getName()});
		}
		
		view.form = form;
		
	}
	
	@tpl('amapadmin/form.mtt')
	public function doVatRates() {
		addBc('vatrates','Taux de TVA','/amapadmin/vatRates');
		
		var f = new sugoi.form.Form("vat");
		var a = app.user.getGroup();
		
		var i = 1;
		var rates = a.getVatRatesOld();
		//create field with a value
		for (k in rates.keys()) {
			f.addElement(new StringInput(i+"-k", t._("Name") +" "+ i, k));
			f.addElement(new FloatInput(i + "-v", t._("Rate") +" "+ i, rates.get(k) ));
			i++;
		}
		
		//...fill in to get 4 fields
		for (x in 0...5 - i) {
			f.addElement(new StringInput(i+"-k", t._("Name") +" "+ i, null));
			f.addElement(new FloatInput(i + "-v", t._("Rate") +" "+ i, null));
			i++;
		}
		
		if (f.isValid()) {
			var d = f.getData();
			var vats = [];
			for (i in 1...5) {
				if (d.get(i + "-k") == null) continue;
				vats.push({
					label : d.get(i + "-k"),
					value : d.get(i + "-v")
				});
			}
			a.lock();
			a.setVatRates(vats);
			a.update();
			throw Ok("/amapadmin", t._("Rate updated"));
			
		}
		view.title = t._("Edit VAT rates");
		view.form = f;
	}

	function doVolunteers(d:haxe.web.Dispatch) {
		addBc('volunteers',"Permanences","amapadmin/volunteers");
		d.dispatch(new controller.amapadmin.Volunteers());
	}

	function doDocuments( dispatch : haxe.web.Dispatch ) {
		addBc('documents',"Documents","amapadmin/documents");
		dispatch.dispatch( new controller.Documents() );
	}

	function doMedia( dispatch : haxe.web.Dispatch ) {
		addBc('media',"Media","amapadmin/media");
		dispatch.dispatch( new controller.Media() );
	}

	/**
	 * Set up group currency. Default is EURO
	 */
	@tpl("amapadmin/form.mtt")
	function doCurrency(){
		addBc("currency","Monnaie","/amapadmin/currency");
		view.title = t._("Currency used by your group.");
		
		var f = new sugoi.form.Form("curr");
		f.addElement(new sugoi.form.elements.StringInput("currency", t._("Currency symbol"), app.user.getGroup().getCurrency()));
		f.addElement(new sugoi.form.elements.StringInput("currencyCode", t._("3 digit ISO code"), app.user.getGroup().currencyCode));
		
		if ( f.isValid()){
			
			app.user.getGroup().lock();
			app.user.getGroup().currency = f.getValueOf("currency");
			app.user.getGroup().currencyCode = f.getValueOf("currencyCode");
			app.user.getGroup().update();
			
			throw Ok("/amapadmin/currency", t._("Currency updated"));
		}
		
		view.form = f;
	}
	
	/**
	 * payment types config
	 */
	@tpl("form.mtt")
	function doPayments(){
		
		var f = new sugoi.form.Form("paymentTypes");
		var types = service.PaymentService.getPaymentTypes(PCGroupAdmin);
		var formdata = [for (t in types){label:t.name, value:t.type, desc:t.adminDesc, docLink:t.docLink}];		
		var selected = app.user.getGroup().getAllowedPaymentTypes();
		f.addElement(new sugoi.form.elements.CheckboxGroup("paymentTypes", t._("Authorized payment types"),formdata, selected) );
		
		var group = app.user.getGroup();

		// if (group.checkOrder == ""){
		// 	group.lock();
		// 	group.checkOrder = app.user.getGroup().name;
		// 	group.update();
		// }
		// f.addElement( new sugoi.form.elements.StringInput("checkOrder", t._("Make the check payable to"), app.user.getGroup().checkOrder, false)); 
		f.addElement( new sugoi.form.elements.StringInput("IBAN", t._("IBAN of your bank account for transfers"), app.user.getGroup().IBAN, false)); 
		//f.addElement( new sugoi.form.elements.Checkbox("allowMoneyPotWithNegativeBalance", t._("Allow money pots with negative balance"), app.user.getGroup().allowMoneyPotWithNegativeBalance));
		//avoid modifiying another group
		var groupId = new sugoi.form.elements.IntInput("groupId","groupId",group.id);
		groupId.inputType = InputType.ITHidden;
		f.addElement( groupId );

		if (f.isValid()){
			
			if( f.getValueOf("groupId") != group.id ) throw "Vous avez changé de groupe.";



			group.lock();
			var paymentTypes:Array<String> = f.getValueOf("paymentTypes");

			if(paymentTypes.length==0){
				throw Error(sugoi.Web.getURI(),"Vous devez choisir au moins un moyen de paiement");
			}

			if(paymentTypes.has(payment.MoneyPot.TYPE) && paymentTypes.length>1) {
				throw Error(sugoi.Web.getURI(),"Le paiement Cagnotte ne peut pas être utilisé en même temps que d'autres moyens de paiements.");
			}
			
			group.setAllowedPaymentTypes(paymentTypes);
			// group.checkOrder = f.getValueOf("checkOrder");
			group.IBAN = f.getValueOf("IBAN");
			// group.allowMoneyPotWithNegativeBalance = f.getValueOf("allowMoneyPotWithNegativeBalance");
			group.update();
			
			throw Ok("/amapadmin/payments", t._("Payment options updated"));
			
		}
		
		view.title = t._("Means of payment");
		view.form = f;
	}

}
