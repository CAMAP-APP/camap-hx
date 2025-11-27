package db;
import Common;
import sys.db.Object;
import sys.db.Types;


enum Right{
	GroupAdmin;					//can manage whole group
	ContractAdmin(?cid:Int);	//can manage one or all contracts
	Membership;					//can manage group members
	Messages;					//can send messages
}

typedef JsonRights = Array<{right:String,params:Array<String>}>;

/**
 * A user which is member of a group
 */
@:id(userId,groupId)
class UserGroup extends Object
{
	@:relation(groupId) public var group : db.Group;
	@:relation(userId) public var user : db.User;
	public var rights : SNull<SSmallText>; 			//rights in JSON
	public var balance : SFloat; 						//account balance in group currency
	public static var CACHE = new Map<String,db.UserGroup>();
	
	
	public function new(){
		super();
		balance = 0;
	}
	
	public static function get(user:User, group:db.Group, ?lock = false) {
		if (user == null || group == null) return null;
		//SPOD doesnt cache elements with double primary key, so lets do it manually
		var c = CACHE.get(user.id + "-" + group.id);
		if (c == null) {
			c = manager.select($user == user && $group == group, true/*lock*/);		
			CACHE.set(user.id + "-" + group.id,c);
		}
		return c;	
	}
	
	public static function getOrCreate(user:db.User, group:db.Group){
		var ua = get(user, group);
		if ( ua == null){
			ua = new UserGroup();
			ua.user = user;
			ua.group = group;
			ua.insert();
		}
		return ua;
	}

	// only DB rights
	private function parseRights():JsonRights{
		try{
			if(this.rights==null) return [];
			return haxe.Json.parse(this.rights);
		}catch(e:Dynamic){
			return [];
		}
	}

	// DB rights + automatic rights
	public function getEditableRights():JsonRights{
		return parseRights();
	}

	// DB rights + automatic rights
	public function getAutoRights():JsonRights{
		var rights = [];
		var contracts = db.Catalog.claimedVendorContracts(userId, groupId);
		for(c in contracts) {
			rights.push({ right: "ContractAdmin", params: ['${c.id}'] });
		}
		return rights;
	}

	// DB rights + automatic rights
	public function getRights():JsonRights{
		return getEditableRights().concat(getAutoRights());
	}
	
	/**
	 * give right and update DB
	 */
	public function giveRight(r:Right) {
	
		if (hasRight(r)) return;
		lock();
		var rights = getEditableRights();

		switch(r){
			case ContractAdmin(cid):					
				rights.push({
					right : "ContractAdmin",
					params : cid==null? null : [Std.string(cid)]
				});
			default:
				rights.push({
					right:Type.enumConstructor(r).toString(),
					params:null
				});			
		}

		this.rights = haxe.Json.stringify(rights);
		update();		
	}
		
	/**
	 * remove right and update DB
	 */
	public function removeRight(r:Right) {	
		
		var rights = getEditableRights();
		
		switch(r){
			case ContractAdmin(cid):					
				rights.push({
					right : "ContractAdmin",
					params : cid==null? null : [Std.string(cid)]
				});

				for ( right in rights.copy()){
					if(right.right==Type.enumConstructor(r).toString()){
						
						if(cid==null && right.params==null){
							rights.remove(right);													
						}

						if(cid!=null && right.params!=null && right.params.has(Std.string(cid))){
							right.params.remove( Std.string(cid) );
						}						
					}
				}	

			default:
				for ( right in rights.copy()){
					if(right.right==Type.enumConstructor(r).toString()){
						rights.remove(right);						
					}
				}					
		}

		this.rights = haxe.Json.stringify(rights);
		update();
	}
	
	public function hasRight(r:Right):Bool {
		if (this.user.isAdmin()) return true;
		var rights = getRights();
		switch(r){
			case ContractAdmin(cid):					
				for ( right in rights){
					if(right.right==Type.enumConstructor(r).toString()){
						
						if(right.params==null){
							//can manage all contracts
							return true;
						}

						if(cid!=null && right.params!=null && right.params.has(Std.string(cid))){
							return true;
						}						
					}
				}	

			default:
				for ( right in rights.copy()){
					if(right.right==Type.enumConstructor(r).toString()){
						return true;					
					}
				}					
		}

		return false;
	}
	
	public function getRightName(r:Right):String {
		var t = sugoi.i18n.Locale.texts;
		return switch(r) {
		case GroupAdmin 	: t._("Administrator");
		case Messages 		: t._("Messaging");
		case Membership 	: t._("Members management");
		case ContractAdmin(cid) : 
			if (cid == null) {
				t._("Management of all catalogs");
			}else {
				var c = db.Catalog.manager.get(cid);
				if(c==null) {
					t._("Deleted contract");	
				}else{
					t._("::name:: catalog management",{name:c.name});
				}
			}
		}
	}

	public function getJsonRightName(r:{right:String,params:Array<String>}){
		var t = sugoi.i18n.Locale.texts;
		return switch(r.right) {
			case "GroupAdmin" 	: t._("Administrator");
			case "Messages" 	: t._("Messaging");
			case "Membership" 	: t._("Members management");
			case "ContractAdmin" : 
				if (r.params == null) {
					t._("Management of all catalogs");
				}else {
					var c = db.Catalog.manager.get(Std.parseInt(r.params[0]));
					if(c==null) {
						t._("Deleted contract");	
					}else{
						t._("::name:: catalog management",{name:c.name});
					}
				}
			default : Std.string(r);
		}
		
	}
	
	public function hasValidMembership():Bool {
		
		if (group.membershipRenewalDate == null) return false;
		var cotis = db.Membership.get(this.user, this.group, this.group.getMembershipYear());
		return cotis != null;
	}
	
	override public function insert(){		
		App.current.event(NewMember(this.user,this.group));
		super.insert();
	}
	
	public function getLastOperations(limit){
		return db.Operation.getLastOperations(user, group, limit);
	}

	public function isGroupManager() {
		return hasRight(Right.GroupAdmin);
	}

	public function canManageAllContracts(){
		return hasRight(Right.ContractAdmin(null));
		/*if (rights == null) return false;
		for (r in rights) {
			switch(r) {
				case Right.ContractAdmin(cid):
					if(cid==null) return true;
				default:
			}
		}
		return false;			*/
	}

}