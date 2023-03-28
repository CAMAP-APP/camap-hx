package controller.admin;

class Group extends controller.Controller
{

	public function new() {
		super();	
	}

	@tpl("admin/group/default.mtt")
	function doDefault() {
		var groups = [];
		var total = 0;

		// form
		var f = new sugoi.form.Form("groups");
		f.method = GET;
		f.addElement(new sugoi.form.elements.StringInput("groupName", "Nom du groupe"));
		f.addElement(new sugoi.form.elements.StringInput("zipCodes", "Saisir des numéros de département séparés par des virgules ou laisser vide."));
		
		var sql_select = "SELECT g.*,p.name as pname, p.address1,p.address2,p.zipCode,p.country,p.city";
		var sql_where_or = [];
		var sql_where_and = [];
		var sql_end = "ORDER BY g.id ASC";
		var sql_from = [
			"`Group` g LEFT JOIN Place p ON g.placeId=p.id"
		];

		if (f.isValid()) {
			// filter by zip codes
			var zipCodes:Array<Int> = f.getValueOf("zipCodes") != null ? f.getValueOf("zipCodes").split(",").map(Std.parseInt) : [];
			if (zipCodes.length > 0) {
				for (zipCode in zipCodes) {
					var min = zipCode * 1000;
					var max = zipCode * 1000 + 999;
					sql_where_or.push('(p.zipCode>=$min and p.zipCode<=$max)');
				}
			}

			

			// group name
			if (f.getValueOf("groupName") != null) {
				sql_where_and.push('g.name like "%${f.getValueOf("groupName")}%"');
			}
		} else {
			
		}

		// QUERY
		if (sql_where_and.length == 0)
			sql_where_and.push("true");
		if (sql_where_or.length == 0)
			sql_where_or.push("true");
		var sql = '$sql_select FROM ${sql_from.join(", ")} WHERE (${sql_where_or.join(" OR ")}) AND ${sql_where_and.join(" AND ")} $sql_end';
		for (g in db.Group.manager.unsafeObjects(sql, false)) {
			groups.push(g);
		}

		view.form = f;

		for (g in groups) {
			total++;
		}

		// TOTALS
		total = groups.length;
		view.total = total;
		view.groups = groups;
	}


	@admin
	@tpl("admin/group/view.mtt")
	function doView(group:db.Group) {
			
		view.group = group;
		
		if( app.params.get("roleIds")=="1" ){
			for( md in db.MultiDistrib.manager.search($distribStartDate > Date.now() && $group==group,true) ){
				var rids = [];
				for( d in md.getDistributions() ){
					for( role in service.VolunteerService.getRolesFromContract(d.catalog) ){
						rids.push(role.id);
					}
				}
				md.lock();
				md.volunteerRolesIds = rids.join(",");
				md.update();
			}
		}
	
		view.vendors = group.getActiveVendors();
		checkToken();		
	}


	@admin
	public function doAddMe(g:db.Group){		
		var ua = app.user.makeMemberOf(g);
		throw Ok("/user/choose?group="+g.id, "Vous faites maintenant partie de " + ua.group.name);
	}

	@admin
	public function doDeleteGroup(a:db.Group) {
	
		if (checkToken()) {
			a.lock();
			a.delete();
			throw Ok("/admin/group/","Groupe effacé");
		}
	}

}