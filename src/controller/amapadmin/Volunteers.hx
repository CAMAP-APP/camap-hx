package controller.amapadmin;
import form.CamapForm;
import service.VolunteerService;
import sugoi.form.elements.Checkbox;
import sugoi.form.elements.Html;
import sugoi.form.elements.IntInput;
import sugoi.form.elements.IntSelect;
import sugoi.form.elements.StringInput;
import sugoi.form.elements.TextArea;

class Volunteers extends controller.Controller
{
	@tpl("amapadmin/volunteers/default.mtt")
	function doDefault() {

		var userGroup = app.user.getGroup();

		var volunteerRolesGroup = VolunteerService.getRolesFromGroup(userGroup);
		view.volunteerRoles = volunteerRolesGroup.filter(function(role) return role.catalog == null);

		checkToken();
		
		var form = new sugoi.form.Form("msg"); // don't change this name, it's used in the template view.mtt

		form.addElement( new form.RawHtml("title1", '<h3>${t._("Duties configuration")}</h3>'));
		form.addElement( new IntInput("daysAfterClosingBeforeHidingDutyPeriods", t._("Masquer les catalogues expirés depuis plus de… (jours)"), userGroup.daysAfterClosingBeforeHidingDutyPeriods, true) );


		form.addElement( new form.RawHtml("title2", '<h3>${t._("Delays and messages")}</h3>'));

		form.addElement( new IntInput("dutyperiodsopen", t._("Number of days before duty periods open to volunteers (between 7 and 365)"), userGroup.daysBeforeDutyPeriodsOpen, true) );
		form.addElement( new Checkbox("allowInformationNotifs", t._("Authorize the sending of information emails to volunteers"), userGroup.flags.has(db.Group.GroupFlags.AllowInformationNotifs)));		
		form.addElement( new IntInput("maildays", t._("Number of days before duty period to send mail"), userGroup.volunteersMailDaysBeforeDutyPeriod, true) );
		form.addElement( new TextArea("volunteersMailContent", t._("Email body sent to volunteers"), userGroup.volunteersMailContent, true, null, "style='height:300px;'") );
		form.addElement( new sugoi.form.elements.Html("html1","<b>Variables utilisables dans l'email :</b><br/>
				[DATE_DISTRIBUTION] : Date de la distribution<br/>
				[LIEU_DISTRIBUTION] : Lieu de la distribution<br/> 
				[LISTE_BENEVOLES] : Liste des bénévoles inscrits à cette permanence"));
				
		form.addElement( new Checkbox("allowAlertNotifs", t._("Authorize the sending of alert emails to free volunteers"), userGroup.flags.has(db.Group.GroupFlags.AllowAlertNotifs)));
		form.addElement( new IntInput("alertmaildays", t._("Number of days before duty period to send mail for vacant volunteer roles"), userGroup.vacantVolunteerRolesMailDaysBeforeDutyPeriod, true) );
		form.addElement( new TextArea("alertMailContent", t._("Alert email body"), userGroup.alertMailContent, true, null, "style='height:300px;'") );
		form.addElement( new sugoi.form.elements.Html("html2","<b>Variables utilisables dans l'email :</b><br/>
				[DATE_DISTRIBUTION] : Date de la distribution<br/>
				[LIEU_DISTRIBUTION] : Lieu de la distribution<br/> 
				[ROLES_MANQUANTS] : Rôles restant à pourvoir"));

		if (form.isValid()) {

			try {
				VolunteerService.isNumberOfDaysValid( form.getValueOf("dutyperiodsopen"), "volunteersCanJoin" );
				VolunteerService.isNumberOfDaysValid( form.getValueOf("maildays"), "instructionsMail" );
				VolunteerService.isNumberOfDaysValid( form.getValueOf("alertmaildays"), "vacantRolesMail" );
				VolunteerService.isNumberOfDaysValid( form.getValueOf("daysAfterClosingBeforeHidingDutyPeriods"), "daysAfterClosingBeforeHidingDutyPeriods" );
			}
			catch(e: tink.core.Error) {
				throw Error("/amapadmin/volunteers", e.message);
			}			

			var group  = userGroup;
			group.lock();
			group.daysAfterClosingBeforeHidingDutyPeriods = form.getValueOf("daysAfterClosingBeforeHidingDutyPeriods");
			group.daysBeforeDutyPeriodsOpen = form.getValueOf("dutyperiodsopen");
			group.volunteersMailDaysBeforeDutyPeriod = form.getValueOf("maildays");
			group.volunteersMailContent = form.getValueOf("volunteersMailContent");
			group.vacantVolunteerRolesMailDaysBeforeDutyPeriod = form.getValueOf("alertmaildays");
			group.alertMailContent = form.getValueOf("alertMailContent");
			
			// notifs
			form.getValueOf("allowInformationNotifs") ? group.flags.set(db.Group.GroupFlags.AllowInformationNotifs) : group.flags.unset(db.Group.GroupFlags.AllowInformationNotifs);
			form.getValueOf("allowAlertNotifs") ? group.flags.set(db.Group.GroupFlags.AllowAlertNotifs) : group.flags.unset(db.Group.GroupFlags.AllowAlertNotifs);

			group.update();
			
			throw Ok("/amapadmin/volunteers", t._("Your changes have been successfully saved."));
			
		}

		CamapForm.addRichText(form, 'textarea');
		
		view.form = form;
		view.nav.push( 'volunteers' );

	}

	/**
		Insert a volunteer role
	**/
	@tpl("form.mtt")
	function doInsertRole() {
		var role = new db.VolunteerRole();
		var form = new sugoi.form.Form("volunteerrole");

		form.addElement( new StringInput("name", t._("Volunteer role name"), null, true) );
		form.addElement( new Checkbox("enabledByDefault", t._("Enabled by default on all distributions"), false, true) );

		if (form.isValid()) {
			role.name = form.getValueOf("name");
			role.group = app.user.getGroup();
			role.catalog = null;
			role.enabledByDefault = form.getValueOf("enabledByDefault") == true;
			role.insert();

			if (role.enabledByDefault) {
				// add new role to futures distribs
				addRoleToFuturesDistribs(role);
			}

			throw Ok("/amapadmin/volunteers", t._("Volunteer Role has been successfully added"));
		}
		
		view.title = t._("Create a volunteer role");
		view.form = form;

	}

	function addRoleToFuturesDistribs(role:db.VolunteerRole){
		// add new role to futures distribs
		for (contracts in app.user.getGroup().getActiveContracts()) {
			for (distribs in contracts.getDistribs()) {
				var md = distribs.multiDistrib;
				var rolesIds = md.volunteerRolesIds.split(",");

				if (md.getDate().getTime() < Date.now().getTime()) continue;

				// if role is not already in the multidistrib
				if (rolesIds.has(role.id.string())) {
					md.lock();
					rolesIds.push(role.id.string());
					md.volunteerRolesIds = rolesIds.join(",");
					md.update();
				}
			}
		}
	}
	/**
	 * Edit a volunteer role
	 */
	@tpl('form.mtt')
	function doEditRole(role:db.VolunteerRole) {
		var form = new sugoi.form.Form("volunteerrole");

		form.addElement( new StringInput("name", t._("Volunteer role name"), role.name, true) );
		form.addElement( new Checkbox("enabledByDefault", t._("Enabled by default on all distributions"), role.enabledByDefault, true) );

		if (form.isValid()) {
			
			role.lock();
			role.name = form.getValueOf("name");
			role.group = app.user.getGroup();
			role.catalog = null;
			role.enabledByDefault = form.getValueOf("enabledByDefault") == true;
			role.update();

			if (role.enabledByDefault) {
				// add new role to futures distribs
				addRoleToFuturesDistribs(role);
			}
			throw Ok("/amapadmin/volunteers", t._("Volunteer Role has been successfully updated"));
			
		}
		view.title = t._("Edit a volunteer role");
		view.form = form;
	}

	/**
	 * Delete a volunteer role
	 */
	function doDeleteRole(role: db.VolunteerRole, args: { token:String , ?force:Bool}) {

		if ( checkToken() ) {

			try {
				VolunteerService.deleteVolunteerRole(role,args.force);
			}
			catch(e: tink.core.Error){
				throw Error("/amapadmin/volunteers", e.message);
			}

			throw Ok("/amapadmin/volunteers", t._("Volunteer Role has been successfully deleted"));
		} else {
			throw Redirect("/amapadmin/volunteers");
		}
	}
	
}
