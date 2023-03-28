package controller.admin;

class User extends controller.Controller
{

	public function new() {
		super();	
	}

	@admin @tpl("admin/user/default.mtt")
	public function doDefault(){}
	
	/**
	 *  search fo a user in the whole database
	 */
	@admin @tpl("admin/user/search.mtt")
	public function doSearch(args:{search:String}){
		
		var search = "%"+StringTools.trim(args.search)+"%";
		var users = db.User.manager.search( 
					($lastName.like(search) ||
					$lastName2.like(search) || 
					$email.like(search) ||
					$email2.like(search) ||
					$firstName.like(search) ||
					$firstName2.like(search)					
					), { orderBy:-id }, false);
		view.users = users;

	}

    /**
	 *  Display infos about a user
	 */
	@admin @tpl("admin/user/view.mtt")
	public function doView(u:db.User){
		view.member = u;
		view.orders = db.UserOrder.manager.count($user==u || $user2==u);		
	}
	
  

	@admin
	function doDelete(user:db.User) {
		if (!app.user.isAdmin()){
			return;
		}
		try {
			service.BridgeService.call('/auth/delete-user/${user.id}');
		} catch (e: Dynamic) {
			Sys.println(e);
		}
	
		throw Redirect('/admin/user');
	}


	/**
	 * infos sur le membre d'un groupe
	 */
	 @admin
	 @tpl("admin/user/usergroup.mtt")
	 public function doUserGroup(u:db.User, g:db.Group){
		 var ua = db.UserGroup.get(u, g, false);
		 
		 view.member = ua.user;
		 view.ua = ua;
		 view.operations = db.Operation.getLastOperations(u, g);
 
		 var timeframe = new tools.Timeframe( DateTools.delta(Date.now() ,-1000.0*60*60*24*30.5*3) , DateTools.delta(Date.now() , 1000.0*60*60*24*30.5*3) );
		 var mds = db.MultiDistrib.getFromTimeRange(g,timeframe.from,timeframe.to);
		 view.mds = mds;
		 view.timeframe = timeframe;
	 }

}