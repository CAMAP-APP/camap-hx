package controller;

import db.Group.GroupFlags;
import form.CamapForm;
import service.PaymentService;
import service.SubscriptionService;
import sugoi.form.elements.Html;
import sugoi.form.elements.StringInput;
import sugoi.form.elements.Checkbox;
import db.UserOrder;
import sugoi.form.Form;

class Amap extends Controller {
	public function new() {
		super();
	}

	@tpl("amap/default.mtt")
	function doDefault() {
		var group = app.user.getGroup();
		var contracts = db.Catalog.getActiveContracts(group, true, false).array();
		for (c in contracts.copy()) {
			if (c.endDate.getTime() < Date.now().getTime())
				contracts.remove(c);
		}
		view.contracts = contracts;
		// view.subscriptions = SubscriptionService.getActiveSubscriptions(app.user, group, false).map(s -> s.catalog.id);
		view.group = app.user.getGroup();
	}

	@tpl("form.mtt")
	function doEdit() {
		if (!app.user.isAmapManager())
			throw t._("You don't have access to this section");

		var group = app.user.getGroup();

		var form = form.CamapForm.fromSpod(group);

		form.removeElementByName("betaFlags");

		// keep only HidePhone, PhoneRequired and AddressRequired
		var flags = form.getElement("flags");
		untyped flags.excluded = [0, 1, 2, 3, 4, 5, 9, 10, 11, 12];
		untyped flags.excluded.push(2);

		// keep values of flags 11 and 12
		var prevAllowInformationNotifs = group.flags.has(GroupFlags.AllowInformationNotifs);
		var prevAllowAlertNotifs = group.flags.has(GroupFlags.AllowAlertNotifs);

		if (form.checkToken()) {
			if (form.getValueOf("id") != app.user.getGroup().id) {
				var editedGroup = db.Group.manager.get(form.getValueOf("id"), false);
				throw Error("/amap/edit",
					'Erreur, vous êtes en train de modifier "${editedGroup.name}" alors que vous êtes connecté à "${app.user.getGroup().name}"');
			}

			form.toSpod(group);

			if (group.extUrl != null) {
				if (group.extUrl.indexOf("http://") == -1 && group.extUrl.indexOf("https://") == -1) {
					group.extUrl = "http://" + group.extUrl;
				}
			}

			if (prevAllowInformationNotifs)
				group.flags.set(GroupFlags.AllowInformationNotifs);
			if (prevAllowAlertNotifs)
				group.flags.set(GroupFlags.AllowAlertNotifs);
			group.update();
			throw Ok("/amapadmin", t._("The group has been updated."));
		}
		CamapForm.addRichText(form, 'textarea:not([name$=\\"_txtDistrib\\"])');
		view.form = form;
	}
}
