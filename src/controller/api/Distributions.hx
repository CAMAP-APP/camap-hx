package controller.api;

import haxe.DynamicAccess;
import tink.core.Error;
import db.UserGroup;
import haxe.Json;
import Common;
import db.MultiDistrib;
import service.VolunteerService;
import service.DistributionService;

class Distributions extends Controller {

	public function new() {
		super();
	}

	/**
		Remove current user from a volunteer role (REST endpoint, no reason required)
	**/
	function doUnsubscribeFromRole(distrib:db.MultiDistrib, role:db.VolunteerRole) {
		checkIsLogged();
		var volunteer = distrib.getVolunteerForRole(role);
		if (volunteer == null) {
			throw new Error(422, t._("There is no volunteer to remove for this role!"));
		} else if (volunteer.user.id != app.user.id) {
			throw new Error(403, t._("You can only remove yourself from a role."));
		}
		VolunteerService.removeUserFromRole(app.user, distrib, role);
		json({success: true});
	}

	/**
		multidistribs data for volunteer roles assignements calendar
	**/
	function doVolunteerRolesCalendar(from:Date,to:Date){

		var group = app.getCurrentGroup();
		var user = app.user;
		var multidistribs = db.MultiDistrib.getFromTimeRange(group, from, to);
		var uniqueRoles = VolunteerService.getUsedRolesInMultidistribs(multidistribs);
		var out = {
			 multiDistribs: new Array(),
			 roles: uniqueRoles.map(function(r) 
				return {
					id: r.id,
					name: r.name
				}
			)
		};

		for( md in multidistribs){
			var o = {
				id 					: md.id,
				distribStartDate	: md.distribStartDate,
				hasVacantVolunteerRoles: md.hasVacantVolunteerRoles(),
				canVolunteersJoin	: md.canVolunteersJoin(),
				volunteersRequired	: md.getVolunteerRoles().length,
				volunteersRegistered: md.getVolunteers().length,
				hasVolunteerRole	: null,
				volunteerForRole 	: null,
			};

			//populate hasVolunteerRole
			var hasVolunteerRole:Dynamic = {};
			for( role in uniqueRoles ){
				Reflect.setField(hasVolunteerRole,Std.string(role.id),md.hasVolunteerRole(role));
			}
			o.hasVolunteerRole = hasVolunteerRole;

			//populate volunteerForRole
			var volunteerForRole = {};
			for(role in uniqueRoles ) {
				var vol = md.getVolunteerForRole(role);
				if(vol!=null){
					Reflect.setField(volunteerForRole,Std.string(role.id),{id:vol.user.id,coupleName:vol.user.getCoupleName()});
				}else{
					Reflect.setField(volunteerForRole,Std.string(role.id),null);
				}
			}
			o.volunteerForRole = volunteerForRole;
			out.multiDistribs.push(o);
		}

		json(out);
	}

}
