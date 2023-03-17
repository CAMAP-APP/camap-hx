package service;
import Common;

using Lambda;
using tools.ObjectListTool;

/**
 * Service for managing groups
 * @author fbarbut
 */
class GroupService
{

	public function new() 
	{
		
	}
	
	/**
	 * copy groups.
	 * @param	g
	 */
	public static function duplicateGroup(g:db.Group){
		
		var d = new db.Group();
		d.name = g.name+" (copy)";
		d.contact = g.contact;
		d.txtIntro = g.txtIntro;
		d.txtHome = g.txtHome;
		d.txtDistrib = g.txtDistrib;
		d.extUrl = g.extUrl;
		d.membershipRenewalDate = g.membershipRenewalDate;
		d.membershipFee = g.membershipFee;
		d.setVatRates(g.getVatRates());
		d.flags = g.flags;
		d.image = g.image;
		d.regOption = g.regOption;
		d.currency = g.currency;
		d.currencyCode = g.currencyCode;
		d.setAllowedPaymentTypes(g.getAllowedPaymentTypes());
		d.checkOrder = g.checkOrder;
		d.IBAN = g.IBAN;		
		d.insert();
		
		//put me in the group
		
		return d;
	}
	
	/**
		Get users with rights in this group
	**/
	public static function getGroupMembersWithRights(group:db.Group,?rights:Array<Right>):Array<db.User>{

		var membersWithAnyRights = db.UserGroup.manager.search($rights!=null && $rights!="[]" && $group==group,false).array();
		if(rights==null){
			return membersWithAnyRights.map(ua -> ua.user);
		}else{
			var members = [];
			for( m in membersWithAnyRights){
				for(r in rights){
					if(m.hasRight(r)){
						members.push(m.user);
						break;
					}
				}
			}			
			return members.deduplicate();
		}

		
	}
	
}