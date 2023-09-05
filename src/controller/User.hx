package controller;
import sugoi.form.elements.Html;
import haxe.crypto.Md5;
import sugoi.Web;
import sugoi.form.Form;
import sugoi.form.elements.Checkbox;
import sugoi.form.elements.Input;
import sugoi.form.elements.IntInput;
import sugoi.form.elements.StringInput;
import sugoi.form.validators.EmailValidator;
import ufront.mail.*;
import db.Catalog;
import service.OrderService;

class User extends Controller
{
	public function new() 
	{
		super();
	}
	
	@tpl("user/default.mtt")
	function doDefault() {
		
	}
	
	
	@tpl("user/login.mtt")
	function doLogin() {
		
		if (App.current.user != null) {
			throw Redirect('/');
		}


		view.sid = App.current.session.sid;

		// If the session has been closed, Neko has been logged out while Nest might still be logged in
		var cookies = Web.getCookies();
		var authSidCookie = cookies["Auth_sid"];
		if (authSidCookie != null && authSidCookie != view.sid){
			throw Redirect('/user/logout');
		}

		service.UserService.prepareLoginBoxOptions(view);

		//if its needed to redirect after login
		if (app.params.exists("redirect")){
			view.redirect = app.params.exists("redirect");
		}else if (getParam("__redirect")!=null) {
			view.redirect = getParam("__redirect");
		} else {
			view.redirect = '/';
		}
}

	/**
	 * Choose which group to connect to.
	 */
	@logged
	@tpl("user/choose.mtt")
	function doChoose(?args: { group:db.Group } ) {

		//home page
		app.breadcrumb = [];
		
		var groups = app.user.getGroups();
		
		view.noGroup = true; //force template to not display current group
				
		if (args!=null && args.group!=null) {
			//select a group
			var which = app.session.data==null ? 0 : app.session.data.whichUser ;
			if(app.session.data==null) app.session.data = {};
			app.session.data.order = null;
			app.session.data.newGroup = null;
			app.session.data.amapId = args.group.id;
			app.session.data.whichUser = which;
			throw Redirect('/home');
		}
		
		view.groups = groups;
		view.wl = db.WaitingList.manager.search($user == app.user, false);

		view.isGroupAdmin = app.user.getUserGroups().find(ug -> return ug.isGroupManager()) != null;
	}
	
	function doLogout() {
		service.BridgeService.logout(App.current.user);
		var domain = App.config.HOST;
		if (domain.lastIndexOf('app.',0) == 0) {
			domain = domain.split('app.').join("");
		}
		Web.setHeader("Set-Cookie", 'Refresh=; HttpOnly; Path=/; Max-Age=0; Domain=$domain');

		App.current.session.delete();

		// Haxe allows neither to set multiple "set-cookie" headers (https://github.com/HaxeFoundation/haxe/issues/3550)
		// nor to set multiple cookies in one set-cookie header (https://www.rfc-editor.org/rfc/rfc2109#section-4.2.2)
		// Hence we can workaround this by redirecting 3 times : one redirect for each cookie we want to delete
		throw Redirect('/user/logoutDeleteAuthenticationCookie');
	}

	function doLogoutDeleteAuthenticationCookie() {
		var domain = App.config.HOST;
		if (domain.lastIndexOf('app.',0) == 0) {
			domain = domain.split('app.').join("");
		}
		Web.setHeader("Set-Cookie", 'Authentication=; HttpOnly; Path=/; Max-Age=0; Domain=$domain');
		throw Redirect('/user/logoutDeleteAuthSidCookie');
	}

	function doLogoutDeleteAuthSidCookie() {
		var domain = App.config.HOST;
		if (domain.lastIndexOf('app.',0) == 0) {
			domain = domain.split('app.').join("");
		}
		Web.setHeader("Set-Cookie", 'Auth_sid=; HttpOnly; Path=/; Max-Age=0; Domain=$domain');
		throw Redirect('/user/login');
	}
	
	/**
	 * Ask for password renewal by mail
	 * when password is forgotten
	 */
	@tpl("user/forgottenPassword.mtt")
	function doForgottenPassword(?key:String, ?u:db.User, ?definePassword:Bool){
		
		//STEP 1
		var step = 1;
		var error : String = null;
		var url = "/user/forgottenPassword";
		
		//ask for mail
		var askmailform = new Form("askemail");
		askmailform.addElement(new StringInput("email", t._("Please key-in your E-Mail address"),null,true));
	
		//change pass form
		var chpassform = new Form("chpass");
		
		var pass1 = new StringInput("pass1", t._("Your new password"),null,true);
		pass1.password = true;
		chpassform.addElement(pass1);
		
		var pass2 = new StringInput("pass2", t._("Again your new password"),null,true);
		pass2.password = true;
		chpassform.addElement(pass2);
		
		var uid = new IntInput("uid","uid", u == null?null:u.id);
		uid.inputType = ITHidden;
		chpassform.addElement(uid);
		
		if (askmailform.isValid()) {
			//STEP 2
			//send password renewal email
			step = 2;
			
			var email :String = askmailform.getValueOf("email");
			var user = db.User.manager.select(email == $email, false);
			//could be user 2
			if(user==null) user = db.User.manager.select(email == $email2, false);
			
			//user not found
			if (user == null) throw Error(url, t._("This E-mail is not linked to a known account"));
			
			//create token
			var token = haxe.crypto.Md5.encode("chp"+Std.random(1000000000));
			sugoi.db.Cache.set(token, user.id, 60 * 60 * 24 * 30);
			
			var m = new sugoi.mail.Mail();
			m.setSender(App.current.getTheme().email.senderEmail, App.current.getTheme().name);					
			m.setRecipient(email, user.getName());					
			m.setSubject( App.current.getTheme().name+" : "+t._("Password change"));
			m.setHtmlBody( app.processTemplate('mail/forgottenPassword.mtt', { user:user, link:'http://' + App.config.HOST + '/user/forgottenPassword/'+token+"/"+user.id }) );
			App.sendMail(m);	
		}
		
		if (key != null && u!=null) {
			//check key and propose to change pass
			step = 3;
			
			if ( u.id == sugoi.db.Cache.get(key) ) {
				view.form = chpassform;
			}else {
				error = t._("Invalid request");
			}
		}
		
		if (chpassform.isValid()) {
			//change pass
			step = 4;
						
			if ( chpassform.getValueOf("pass1") == chpassform.getValueOf("pass2")) {
				
				var uid = Std.parseInt( chpassform.getValueOf("uid") );
				var user = db.User.manager.get(uid, true);
				var pass = chpassform.getValueOf("pass1");
				user.setPass(pass);
				user.update();

				sugoi.db.Cache.destroy(key);

				var m = new sugoi.mail.Mail();
				m.setSender(App.current.getTheme().email.senderEmail, App.current.getTheme().name);					
				m.setRecipient(user.email, user.getName());					
				if(user.email2!=null) m.setRecipient(user.email2, user.getName());					
				m.setSubject( "["+App.current.getTheme().name+"] : "+t._("New password confirmed"));
				var emails = [user.email];
				if(user.email2!=null) emails.push(user.email2);
				var params = {
					user:user,
					emails:emails.join(", "),
					password:pass
				}
				m.setHtmlBody( app.processTemplate('mail/newPasswordConfirmed.mtt', params) );
				App.sendMail(m);	
				
			}else {
				error = t._("You must key-in two times the same password");
			}
		}
			
		if (step == 1) {
			view.form = askmailform;
		}
		
		view.step = step;
		view.error = error;
		view.title = definePassword == null ? "Changement de mot de passe" : t._("Create a password for your account");

	}
	
	/**
		The user just registred or logged in, and want to be a member of this group
	**/
	function doJoingroup(){

		if(app.user==null) throw "no user";

		var group = App.current.getCurrentGroup();
		if(group==null) throw "no group selected";
		if(group.regOption!=db.Group.RegOption.Open) throw "this group is not open";

		/*var user = app.user;
		user.lock();
		user.flags.set(HasEmailNotif24h);
		user.flags.set(HasEmailNotifOuverture);
		user.update();*/
		db.UserGroup.getOrCreate(app.user,group);

		if (app.user.isMemberOf(group)){
			throw Ok("/", t._("You are already member of this group."));
		}

		//warn manager by mail
		if(group.contact!=null && !app.user.isMemberOf(group)){
			var url = "http://" + App.config.HOST + "/member/view/" + app.user.id;
			var text = t._("A new member joined the group without ordering : <br/><strong>::newMember::</strong><br/> <a href='::url::'>See contact details</a>",{newMember:app.user.getCoupleName(),url:url});
			App.quickMail(
				group.contact.email,
				t._("New member") + " : " + app.user.getCoupleName(),
				text,
				group
			);	
		}

		throw Ok("/", t._("You're now a member of \"::group::\" ! You'll receive an email as soon as next order will open", {group:group.name}));
	}

	/**
		Quit a group.  Should work even if user is not logged in. ( link in emails footer )
	**/
	@tpl('account/quit.mtt')
	function doQuitGroup(group:db.Group,user:db.User,key:String){

		if (haxe.crypto.Sha1.encode(App.config.KEY+group.id+user.id) != key){
			// For legacy, key might still be using MD5
			if (haxe.crypto.Md5.encode(App.config.KEY+group.id+user.id) == key){
				key=haxe.crypto.Sha1.encode(App.config.KEY+group.id+user.id);
			} else {
				throw Error("/","Lien invalide");
			}
		}
		// chercher les catalogs actifs du groupe (y compris terminés depuis moins d'un mois)
		// chercher les distributions de ces catalogues 
		// puis vérifier si l'utilisateur a des commandes dans ces distribs
		var catalogs = db.Catalog.getActiveContracts (group, true);
		if (catalogs != null) {
			for (catalog in catalogs){
				var distribs = catalog.getDistribs(true);
				for (d in distribs) {
					var userOrders = catalog.getUserOrders(user,d,true);
					if (userOrders.length > 0){
						throw Error("/","Vous ne pouvez pas quitter ce groupe car vous avez des commandes en cours.\nVeuillez contacter un responsable du groupe pour plus d'information.");
					}
				}
			}
		} else {
			throw Error("/","catalogs is null");
		}
		var userGroup = db.UserGroup.get(user, group);
		if (userGroup.balance < 0) throw Error ("/","Vous ne pouvez pas quitter ce groupe car votre solde est négatif.\nVeuillez contacter un responsable du groupe pour plus d'information.");

		view.groupId = group.id;
		view.userId = user.id;
		view.controlKey = key;
	}

	/**
		Quit a group without a userId.  Should work ONLY if the user is logged in. ( link in emails footer from Messaging Service )
	**/
	@tpl('account/quit.mtt')
	function doQuitGroupFromMessage(group:db.Group,key:String){

		if ( app.user == null && getParam('__redirect')==null ) {
			throw sugoi.ControllerAction.RedirectAction(Web.getURI()+"?__redirect="+Web.getURI());
		}

		if (haxe.crypto.Sha1.encode(App.config.KEY+group.id) != key){
			throw Error("/","Lien invalide");
		}
		// chercher les catalogs actifs du groupe (y compris terminés depuis moins d'un mois)
		// chercher les distributions de ces catalogues 
		// puis vérifier si l'utilisateur a des commandes dans ces distribs
		var catalogs = db.Catalog.getActiveContracts (group, true);
		if (catalogs != null) {
			for (catalog in catalogs){
				var distribs = catalog.getDistribs(true);
				for (d in distribs) {
					var userOrders = catalog.getUserOrders(app.user,d,true);
					if (userOrders.length > 0){
						throw Error("/","Vous ne pouvez pas quitter ce groupe car vous avez des commandes en cours.\nVeuillez contacter un responsable du groupe pour plus d'information.");
					}
				}
			}
		}
		var userGroup = db.UserGroup.get(app.user, group);
		if (userGroup.balance < 0) throw Error ("/","Vous ne pouvez pas quitter ce groupe car votre solde est négatif.\nVeuillez contacter un responsable du groupe pour plus d'information.");
		view.groupId = group.id;
		if (app.user!=null) {
			view.userId = app.user.id;
			view.controlKey = haxe.crypto.Sha1.encode(App.config.KEY+group.id+app.user.id);
		}
	}

}