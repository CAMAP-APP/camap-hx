package db;

import sys.db.Object;
import sys.db.Types;

class NotificationMail extends Object {
	public var id:SId;
	public var cdate:SDateTime;
	public var htmlBody:SText;
	public var textBody:SText;
	public var digest:SInt; // 1 = hourly, 2 = daily
	public var subject:SString<256>;
	@:relation(groupId) public var group:db.Group;
	@:relation(recipientId) public var recipient:db.User;
	public var attachments:SText;

	public static function createNotification(htmlBody:String, textBody:String, digest:Int, subject:String, group:db.Group, recipient:db.User,
			attachments:Array<String>) {
		var notification = new NotificationMail();
		notification.htmlBody = htmlBody;
		notification.textBody = textBody;
		notification.digest = digest;
		notification.subject = subject;
		notification.group = group;
		notification.recipient = recipient;
		notification.attachments = haxe.Json.stringify(attachments);
		notification.insert();
		return notification;
	}

	public static function makeSubject(subscription:Subscription):String {
		return "SUBSCRIPTION(" + subscription.catalog.id + ")";
	}
}
