package controller;

import sugoi.form.elements.RadioGroup;
import payment.MoneyPot;
import db.Basket;
import Common;
import db.Distribution;
import db.MultiDistrib;
import db.UserOrder;
import haxe.Json;
import haxe.macro.Expr.Error;
import haxe.web.Dispatch;
import sugoi.Web;
import sugoi.form.elements.StringInput;
import sugoi.tools.ResultsBrowser;
import tools.ArrayTool;
import tools.DateTool;
import db.Message;
import sugoi.db.Variable;

class Main extends Controller {
	public function new() {
		super();

		// init group breadcrumb
		var group = App.current.getCurrentGroup();
		if (group != null)
			addBc("g" + group.id, "Groupe CAMAP : " + group.name, "/home");
	}

	function doDefault(?permalink:String) {
		if (permalink == null || permalink == "")
			throw Redirect("/home");
		var p = sugoi.db.Permalink.get(permalink);
		if (p == null)
			throw Error("/home", t._("The link \"::link::\" does not exists.", {link: permalink}));

		app.event(Permalink({link: p.link, entityType: p.entityType, entityId: p.entityId}));
	}

	function doTransaction(d:haxe.web.Dispatch) {
		d.dispatch(new controller.Transaction());
	}

	/**
	 * public pages 
	 */
	function doGroup(d:haxe.web.Dispatch) {
		d.dispatch(new controller.Group());
	}

	@tpl("home.mtt")
	function doHome() {
		addBc("home", "Commandes", "/home");

		// If the session has been closed, Neko has been logged out while Nest might still be logged in
		if (app.user == null){
			var cookies = Web.getCookies();
			var authSidCookie = cookies["Auth_sid"];
			if (authSidCookie != null && authSidCookie != view.sid){
				throw Redirect('/user/logout');
			}
		}

		var group = app.getCurrentGroup();
		if (app.user != null && group == null) {
			throw Redirect("/user/choose");
		} else if (app.user == null && (group == null || group.regOption != db.Group.RegOption.Open)) {
			throw Redirect("/user/login");
		}else if(group.disabled!=null){
			throw Redirect("/group/disabled");
		}

		view.amap = group;

		// has unconfirmed basket ?
		service.OrderService.checkTmpBasket(app.user, app.getCurrentGroup());

		// contract not ended with UserCanOrder flag
		view.openContracts = group.getActiveContracts().filter((c) -> c.hasOpenOrders());

		// freshly created group
		view.newGroup = app.session.data.newGroup == true;

		var n = Date.now();
		var now = new Date(n.getFullYear(), n.getMonth(), n.getDate(), 0, 0, 0);
		var in1Month = DateTools.delta(now, 1000.0 * 60 * 60 * 24 * 30);
		var timeframe = new tools.Timeframe(now, in1Month);

		var distribs = db.MultiDistrib.getFromTimeRange(group, timeframe.from, timeframe.to);

		// special case : only one distrib , far in future.
		if (distribs.length == 0) {
			timeframe = new tools.Timeframe(now, DateTools.delta(now, 1000.0 * 60 * 60 * 24 * 30 * 12));
			distribs = db.MultiDistrib.getFromTimeRange(group, timeframe.from, timeframe.to);
		}

		view.timeframe = timeframe;
		view.distribs = distribs;

		// view functions
		view.getWhosTurn = function(orderId:Int, distrib:Distribution) {
			return db.UserOrder.manager.get(orderId, false).getWhosTurn(distrib);
		}

		// register to group without ordering block
		var isMemberOfGroup = app.user == null ? false : app.user.isMemberOf(group);
		var registerWithoutOrdering = (!isMemberOfGroup && group.regOption == db.Group.RegOption.Open);
		view.registerWithoutOrdering = registerWithoutOrdering;
		if (registerWithoutOrdering)
			service.UserService.prepareLoginBoxOptions(view, group);

		// event for additionnal blocks on home page
		var e = Blocks([], "home");
		app.event(e);
		view.blocks = e.getParameters()[0];

		// message if phone is required
		if (app.user != null && group.flags.has(db.Group.GroupFlags.PhoneRequired) && app.user.phone == null) {
			app.session.addMessage("Les membres de ce groupe doivent fournir un numéro de téléphone. <a href='/account'>Cliquez ici pour mettre à jour votre compte</a>.",true);
		}

		// message if address is required
		if (app.user != null && group.flags.has(db.Group.GroupFlags.AddressRequired) && app.user.city == null) {
			app.session.addMessage("Les membres de ce groupe doivent fournir leur adresse. <a href='/account'>Cliquez ici pour mettre à jour votre compte</a>.",true);
		}

		// désactivation du questionnaire de migration
		/*
		if(app.user != null && app.user.isAmapManager() && Date.now().getTime() < new Date(2023,6,7,0,0,0).getTime() ){
			var g = app.getCurrentGroup();
			if(g.questAnswer!=null){
				var choice = switch(g.questAnswer){
					case "move" : "Je souhaite basculer sur le serveur de l'InterAMAP44";
					case "stay" : "Je souhaite rester sur ce serveur avec arrêt du service au 30 Août";
					case "cagette" : "Je souhaite revenir sur Cagette.net pour gérer des commandes en \"mode marché\"";
					case "bye" : "Je ne souhaite plus utiliser CAMAP, ni Cagette.net";
					default : "???";
				};

				App.current.session.addMessage("<h4>Reprise de CAMAP par l'interAMAP 44</h4>Votre réponse au questionnaire : <b>"+choice+"</b>, le "+view.hDate(g.questDate)+" par "+g.questUser.getName());
			}else{
				App.current.session.addMessage("<h4>Reprise de CAMAP par l'interAMAP 44</h4>En tant qu'administrateur de cette AMAP, <b>si vous désirez continuer à utiliser l'application sans pertes de données lors de la migration</b>,<br/>merci de bien vouloir remplir ce questionnaire avant le 3 Juillet 2023 : <a href='/questionnaire' class='btn btn-default'>Questionnaire</a>");
			}
		}
		*/
		
		
		var attMessage = Variable.get("attMessage");
		if (attMessage != "") {
			App.current.session.addMessage(attMessage);
		}
		

		view.visibleDocuments = group.getVisibleDocuments(isMemberOfGroup);
		view.user = app.user;
	}

	// login and stuff
	function doUser(d:Dispatch) {
		// addBc("user","Membres","/user");
		d.dispatch(new controller.User());
	}

	function doCron(d:Dispatch) {
		d.dispatch(new controller.Cron());
	}

	/**
	 *  JSON REST API Entry point
	 */
	function doApi(d:Dispatch) {
		sugoi.Web.setHeader("Content-Type", "application/json");
		sugoi.Web.setHeader("Access-Control-Allow-Credentials","true");
		try {
			d.dispatch(new controller.Api());
		} catch (e:tink.core.Error) {
			// manage tink Errors (service errors)
			sugoi.Web.setReturnCode(e.code);
			Sys.print(Json.stringify({error: {code: e.code, message: e.message, stack: e.exceptionStack}}));
			app.rollback();
		} catch (e:Dynamic) {
			// manage other errors
			sugoi.Web.setReturnCode(500);
			var stack = haxe.CallStack.toString(haxe.CallStack.exceptionStack());
			App.current.logError(e, stack);
			Sys.print(Json.stringify({error: {code: 500, message: Std.string(e), stack: stack}}));
			app.rollback();
		}
	}

	@tpl("cssDemo.mtt")
	function doCssdemo() {
		// debug stringmap haxe4
		var users = new Map<String, String>();
		users["bob"] = "is a nice fellow";
		view.users = users;
	}

	@tpl("form.mtt")
	function doInstall(d:Dispatch) {
		d.dispatch(new controller.Install());
	}

	@logged
	function doMember(d:Dispatch) {
		addBc("member", "Membres", "/member");
		d.dispatch(new controller.Member());
	}

	function doHistory(d:Dispatch) {
		addBc("history", "Historique", "/history");
		d.dispatch(new controller.History());
	}

	function doAccount(d:Dispatch) {
		addBc("account", "Mon compte", "/account");
		d.dispatch(new controller.Account());
	}

	@logged
	function doVendor(d:Dispatch) {
		addBc("contractAdmin", "Producteur", "/contractAdmin");
		d.dispatch(new controller.Vendor());
	}

	@logged
	function doPlace(d:Dispatch) {
		d.dispatch(new controller.Place());
	}

	@logged
	function doDistribution(d:Dispatch) {
		addBc("distribution", "Distributions", "/distribution");
		d.dispatch(new controller.Distribution());
	}

	function doShop(d:Dispatch) {
		d.dispatch(new controller.Shop());
	}

	@logged
	function doProduct(d:Dispatch) {
		d.dispatch(new controller.Product());
	}

	@logged
	function doAmap(d:Dispatch) {
		addBc("amap", "Producteurs", "/amap");
		d.dispatch(new controller.Amap());
	}

	function doContract(d:Dispatch) {
		addBc("contract", "Catalogues", "/contractAdmin");
		d.dispatch(new Contract());
	}

	@logged
	function doContractAdmin(d:Dispatch) {
		addBc("contract", "Catalogues", "/contractAdmin");
		d.dispatch(new ContractAdmin());
	}

	@logged
	function doDocuments(dispatch:Dispatch) {
		dispatch.dispatch(new Documents());
	}

	@logged
	function doSubscriptions(dispatch:Dispatch) {
		dispatch.dispatch(new Subscriptions());
	}

	@logged
	function doMessages(d:Dispatch) {
		addBc("messages", "Messagerie", "/messages");
		d.dispatch(new Messages());
	}

	@logged
	function doAmapadmin(d:Dispatch) {
		addBc("amapadmin", "Paramètres", "/amapadmin");
		d.dispatch(new AmapAdmin());
	}

	@admin
	function doDb(d:Dispatch) {
		d.parts = []; // disable haxe.web.Dispatch
		sys.db.admin.Admin.handler();
	}

	@tpl('invite.mtt')
	function doInvite(hash:String, userEmail:String, group:db.Group, ?user:db.User){

		if (haxe.crypto.Sha1.encode(App.config.KEY+userEmail) != hash){
			throw Error("/","Lien invalide");
		}

		app.session.data.amapId = group.id;

		if (user!=null) {
			db.UserGroup.getOrCreate(user,group);
			throw Ok("/", t._("You're now a member of \"::group::\" ! You'll receive an email as soon as next order will open", {group:group.name}));
		} else {
			service.UserService.prepareLoginBoxOptions(view, group);
			view.invitedUserEmail = userEmail;
			view.invitedGroupId = group.id;
		}
	}

	public function doPing() {
		Sys.print(haxe.Json.stringify({version: App.VERSION.toString()}));
	}

	
	/**
		backoffice for superadmins
	**/
	@admin
	public function doAdmin(d:Dispatch) {
		d.dispatch(new controller.admin.Admin());
	}


	/**
		Maintenance and migration scripts to run in CLI like "neko index.n scripts/scriptAction"
	**/
	function doScripts(d:Dispatch) {
		try {
			d.dispatch(new controller.Scripts());
		} catch (e:Dynamic) {
			//errors for CLI context
			sugoi.Web.setReturnCode(500);
			var stack = haxe.CallStack.toString(haxe.CallStack.exceptionStack());
			App.current.logError(e, stack);
			Sys.println("");
			Sys.println(Std.string(e));
			for(m in stack.split("\n")) Sys.println(m);
			Sys.println("");
			app.rollback();
		}
	}

	public function doTos() {
		throw Redirect(App.current.getTheme().terms.termsOfServiceLink);
	}

	public function doCgu() {
		throw Redirect('/tos');
	}

	/*
	@tpl('form.mtt')
	public function doQuestionnaire(){

		view.title = "Questionnaire pour connaître vos intentions quant à la reprise de CAMAP par l'InterAMAP 44";

		view.text = "<div class='alert alert-warning'>
		<p>Ce questionnaire est réservé aux administrateurs d'AMAP</p>
		<p><a href='https://amap44.org' target='_blank'>L'InterAMAP 44</a> a été choisie par Alilo pour reprendre l'hébergement et la maintenance du logiciel CAMAP.</p>
		<p>Nous proposons aux AMAP qui le souhaitent de basculer sur leur serveur CAMAP <b>la semaine du 3 juillet 2023</b></p>
		<p>
		Si celà vous intéresse, nous vous invitons vivement à étudier leur offre d'hébergement : <a href='https://www.amap44.org/camap/' class='btn btn-default' target='_blank'>Conditions hébergement InterAMAP 44</a>.
		</p>		
		</div>
		Afin de nous faire connaître vos intentions, merci de bien vouloir remplir ce formulaire avant le 3 juillet 2023 :";

		var f = new sugoi.form.Form("quest");
		f.addElement(new sugoi.form.elements.Html("user",app.user.getName(),"Votre nom"));
		f.addElement(new sugoi.form.elements.Html("amap",app.getCurrentGroup().name,"Votre AMAP"));

		var data = [
			{label:"Je souhaite basculer sur le serveur CAMAP de l'InterAMAP 44 la semaine du 3 juillet 2023. Je donne mon accord pour que les données de mon AMAP soient transférées à l'InterAMAP 44 afin de pouvoir continuer à utiliser le logiciel sans perte de données.",value:"move"},
			{label:"Je souhaite rester sur ce serveur. J'ai compris que le service s'arrêtera le 30 Août 2023 sans reprise de données possible.",value:"stay"},
			{label:"Je souhaite revenir sur Cagette.net pour gérer des commandes en \"mode marché\".",value:"cagette"},
			{label:"Je ne souhaite plus utiliser CAMAP, ni Cagette.net",value:"bye"},
		];

		f.addElement(new RadioGroup("choice","Choix pour mon AMAP :",data));

		if(f.isValid()){

			var g = App.current.getCurrentGroup();
			g.lock();

			g.questUser = app.user;
			g.questDate = Date.now();
			g.questAnswer = f.getValueOf("choice");
			g.update();

			throw Ok("/home","Merci pour votre réponse.");

		}


		view.form = f;

	}
	*/

}