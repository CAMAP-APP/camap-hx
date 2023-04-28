package db;
import sys.db.Object;
import sys.db.Types;
import tink.core.Noise;
import tink.core.Outcome;
import sugoi.mail.IMailer;


/**
 * Message sent from the message Section
 */
class Message extends Object
{

	public var id : SId;
	
	public var recipientListId : SNull<SString<12>>;

    public var title : SString<128>;
    public var body : SText;	
	public var date : SDateTime;

	public var recipients : SNull<SText>;
    public var slateContent : SText;
	
    @:relation(amapId) public var amap : SNull<db.Group>;
	@:relation(senderId) public var sender : SNull<User>;
	
	public var attachments : SNull<SText>;
	
}