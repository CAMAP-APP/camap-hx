package service;
import db.Group.RegOption;
import tink.core.Error;
import Common;

/**
 * User Service
 * @author fbarbut
 */
class UserService
{
	
	var user : db.User;
	
	public function new(u:db.User) 
	{
		this.user = u;		
	}

	public static function get(email:String,?lock=false):db.User{

		/*var t  = sugoi.i18n.Locale.texts;
		
		if (!sugoi.form.validators.EmailValidator.check(email)){
			throw new Error(500,t._("Invalid email address")+" : "+email);
		}

		var u = db.User.manager.select($email == email || $email2 == email, true);
		if (u == null){
			u = new db.User();
			u.firstName = firstName;
			u.lastName = lastName;
			u.email = email;			
			u.insert();
		}
		return u;*/

		return db.User.manager.select($email == email || $email2 == email, lock);
	}

	/**
	 *  get users belonging to a group
	 *  @param group - 
	 *  @return Array<db.User>
	 */
	public static function getFromGroup(group:db.Group):Array<db.User>{
		return Lambda.array( group.getMembers() );
	}

	/**
	 *  Checks that the user is at least 18 years old
	 *  @param birthday - 
	 *  @return Bool
	 */
	public static function isBirthdayValid(birthday:Date): Bool {
		if(birthday==null) return true;
		//Check that the user is at least 18 years old
		return birthday.getTime() < DateTools.delta(Date.now(), -1000*60*60*24*365.25*18).getTime()	? true : false;	
	}

	public static function prepareLoginBoxOptions(view:Dynamic,?group:db.Group){
		if(group==null) group = App.current.getCurrentGroup();
		var loginBoxOptions : Dynamic = {};
		if(group==null || group.flags==null){
			view.loginBoxOptions = {};
			return;
		} 
		if(group.flags.has(PhoneRequired)) loginBoxOptions.phoneRequired = true;
		if(group.flags.has(AddressRequired)) loginBoxOptions.addressRequired = true;

		loginBoxOptions.sid = App.current.session.sid;

		view.loginBoxOptions = loginBoxOptions;
	}
	
}