package db;
import sys.db.Object;
import sys.db.Types;

class VolunteerRole extends Object
{
	public var id : SId;
	public var name : SString<64>;
	public var enabledByDefault : SBool;
	@:relation(groupId) public  var group : db.Group;
	@:relation(catalogId) 	public var catalog : SNull<db.Catalog>;

	public function isGenericRole():Bool{
		return catalog==null;
	}
}