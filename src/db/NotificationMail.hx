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
	public var groupId:SInt;
	public var recipients:SText;
	public var attachments:SText;

	public static function createNotification(htmlBody:String, textBody:String, digest:Int, subject:String, groupId:Int, recipients:Array<String>,
			attachments:Array<String>) {
		var notification = new NotificationMail();
		notification.htmlBody = htmlBody;
		notification.textBody = textBody;
		notification.digest = digest;
		notification.subject = subject;
		notification.groupId = groupId;
		notification.recipients = haxe.Json.stringify(recipients);
		notification.attachments = haxe.Json.stringify(attachments);
		notification.insert();
		return notification;
	}

	public static function makeSubject(subscription:Subscription):String {
		return "SUBSCRIPTION(" + subscription.id + ")";
	}
}
