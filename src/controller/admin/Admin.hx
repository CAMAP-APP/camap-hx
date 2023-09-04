package controller.admin;

import haxe.Json;
import sugoi.form.elements.TextArea;
import Common;
import db.BufferedJsonMail;
import db.Catalog;
import db.MultiDistrib;
import haxe.web.Dispatch;
import sugoi.Web;
import sugoi.db.Variable;
import sys.FileSystem;
import tools.ObjectListTool;
import tools.Timeframe;

class Admin extends Controller {
	public function new() {
		super();
		view.category = 'admin';

		// trigger a "Nav" event
		var nav = new Array<Link>();
		var e = Nav(nav, "admin");
		app.event(e);
		view.nav = e.getParameters()[0];
	}

	@tpl("admin/default.mtt")
	function doDefault() {
		view.now = Date.now();
		view.ip = Web.getClientIP();

		if (app.params.get("reloadSettings") == "1") {
			app.setTheme();
			view.theme = app.getTheme();
			throw Ok('/admin', "Theme reloaded");
		}
	}

	@tpl("form.mtt")
	function doTheme() {
		var f = new sugoi.form.Form("theme");

		f.addElement(new sugoi.form.elements.TextArea("theme", "theme", Json.stringify(app.getTheme()), true, null, "style='height:800px;'"));
		f.addElement(new sugoi.form.elements.Html("html", "<a href='https://www.jsonlint.com/' target='_blank'>jsonlint.com</a>"));

		if (f.isValid()) {
			var json:Theme = null;
			try {
				json = Json.parse(f.getValueOf("theme"));
				Variable.set("whiteLabel", Json.stringify(json));
			} catch (e:Dynamic) {
				throw Error('/admin/theme', "Erreur : " + Std.string(e));
			}

			throw Ok("/admin/", "Thème mis à jour");
		}

		view.form = f;
		view.title = "Modifier le thème";
	}

	@tpl("admin/emails.mtt")
	function doEmails(?args:{?reset:BufferedJsonMail}) {
		if (args != null && args.reset != null) {
			args.reset.lock();
			args.reset.tries = 0;
			args.reset.update();
		}

		var emails:Array<Dynamic> = service.BridgeService.call("/mail/getUnsentMails");

		var browse = function(index:Int, limit:Int) {
			var filtered = [];
			for (i in 0...limit) {
				if (i + index < emails.length) {
					filtered.push(emails[i + index]);
				}
			}
			return filtered;
		}

		var count = emails.length;
		view.browser = new sugoi.tools.ResultsBrowser(count, 10, browse);
		view.num = count;
	}


	function doUser(d:haxe.web.Dispatch) {
		d.dispatch(new controller.admin.User());
	}

	function doGroup(d:haxe.web.Dispatch) {
		d.dispatch(new controller.admin.Group());
	}

	/**
	 *  Display errors logged in DB
	 */
	@tpl("admin/errors.mtt")
	function doErrors(args:{?user:Int, ?like:String, ?empty:Bool}) {
		view.now = Date.now();

		view.u = args.user != null ? db.User.manager.get(args.user, false) : null;
		view.like = args.like != null ? args.like : "";

		var sql = "";
		if (args.user != null)
			sql += " AND uid=" + args.user;
		// if( args.like!=null && args.like != "" ) sql += " AND error like "+sys.db.Manager.cnx.quote("%"+args.like+"%");
		if (args.empty) {
			sys.db.Manager.cnx.request("truncate table Error");
		}

		var errorsStats = sys.db.Manager.cnx.request("select count(id) as c, DATE_FORMAT(date,'%y-%m-%d') as day from Error where date > NOW()- INTERVAL 1 MONTH "
			+ sql
			+ " group by day order by day")
			.results();
		view.errorsStats = errorsStats;

		view.browser = new sugoi.tools.ResultsBrowser(sugoi.db.Error.manager.unsafeCount("SELECT count(*) FROM Error WHERE 1 " + sql), 20,
			function(start, limit) {
				return sugoi.db.Error.manager.unsafeObjects("SELECT * FROM Error WHERE 1 " + sql + " ORDER BY date DESC LIMIT " + start + "," + limit, false);
			});
	}



	public static function addUserToGroup(email:String, group:db.Group) {
		var user = db.User.manager.search($email == email).first();
		if (user != null) {
			var usergroup = new db.UserGroup();
			usergroup.user = user;
			usergroup.group = group;
			usergroup.insert();
		}
	}


	

	/**
		edit general messages on homepage
	**/
	@tpl('form.mtt')
	function doMessages() {
		var homeMessage = Variable.get("homeMessage");

		var f = new sugoi.form.Form("msg");
		f.addElement(new sugoi.form.elements.TextArea("homeMessage", "Message sur la homepage", homeMessage));

		if (f.isValid()) {
			Variable.set("homeMessage", f.getValueOf("homeMessage"));			
			throw Ok("/admin/", "Message mis à jour");
		}

		view.title = "Message";
		view.form = f;
	}

	/**
		edit alert message on group's page
	**/
	@tpl('form.mtt')
	function doAttention() {
		var attMessage = Variable.get("attMessage");

		var f = new sugoi.form.Form("msg");
		f.addElement(new sugoi.form.elements.TextArea("attMessage", "Message d'alerte à afficher sur tous les groupes", attMessage));

		if (f.isValid()) {
			Variable.set("attMessage", f.getValueOf("attMessage"));			
			throw Ok("/admin/", "Alerte mise à jour");
		}

		view.title = "Alerte";
		view.form = f;
	}

	
	@tpl('admin/superadmins.mtt')
	function doSuperadmins() {
		view.superadmins = db.User.manager.search($rights.has(Admin), false);
	}


}
